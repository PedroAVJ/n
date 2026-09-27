import Base
import bend-kit-files@0.1.0.0/files.bend as Fs
import bend-net-json@0.3.0.0/json.bend as Json
import ./effs/io.bend as X
import ../type.bend as A
import ../ops.bend as O
import ./container/effects.bend as CtE
import ./deployment/type.bend as D
import ./deployment/ops.bend as DO
import ./deployment/azure/effects.bend as AzE
import ./deployment/launchd/effects.bend as LdE
import ./deployment/nix_darwin/type.bend as ND
import ./deployment/nix_darwin/ops.bend as NDO
import ./deployment/nix_darwin/effects.bend as NDE
import ./deployment/nix_darwin/setting/type.bend as St
import ./deployment/nix_darwin/setting/ops.bend as StO
import ./deployment/nix_darwin/brew/type.bend as Br
import ./deployment/nix_darwin/setting/effects.bend as StE
import ./deployment/nix_darwin/brew/effects.bend as BrE
import ./deployment/nix_darwin/service/ops.bend as SvO
import ./release/type.bend as Rl
import ./release/ops.bend as RlO
import ./release/plugin/ops.bend as PlO
import ./plan/type.bend as P
import ./plan/ops.bend as PO
import ./ops.bend as SO

# The system's effects: reading the repository, the Bend hub and GitHub (a snapshot of the world), and
# changing them (a deploy). Programs run with their arguments, never through a shell; files are read with
# Base's File API.

# ---- the repository's files ----
def files(+root: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    out : String <- X.run("git", ["-C", root, "ls-files", "-co", "--exclude-standard"])
    return X.nonempty(String.lines(out))

# ---- what an entry reaches: it and every file it imports, followed in Bend ----
def second_word(+t: String) -> String:
  Maybe.default(&2, String, List.get(&2, String, X.nonempty(String.split(t, ' ')), 1n), "")

def unquote(+w: String) -> String:
  Bool.pick(String, String.starts_with(w, "\""), Maybe.default(&2, String, List.get(&2, String, String.split(w, '"'), 1n), ""), w)

# The file a line imports, relative to the repository, or "" when it imports none of the repository's.
def import_of(+line: String, +dir: String) -> String:
  +w = unquote(second_word(String.trim(line)))
  Bool.pick(String, String.starts_with(String.trim(line), "import ") && (String.starts_with(w, "./") || String.starts_with(w, "../")),
    Fs.path.normalize(Fs.path.join(dir, w)), "")

def imports(ls: List<&2, String>, +dir: String) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      X.nonempty(import_of(l, dir) <> imports(rest, dir))

# Each step reads one file; the number of files squared bounds the walk.
def reach(fuel: Nat, +todo: List<&2, String>, +seen: List<&2, String>, +root: String) -> IO(List<&2, String>):
  match fuel:
    case 0n:
      IO.pure(List<&2, String>, seen)
    case 1n+k:
      match todo:
        case []:
          IO.pure(List<&2, String>, seen)
        case +f <> rest:
          do IO<List<&2, String>>:
            text : String <- X.read_head(root ++ "/" ++ f, 4096)
            +known : Bool = List.contains(~String, ~String.eq, seen, f)
            reach(k, List.append(&2, String, rest, Bool.pick(List<&2, String>, known, [], imports(String.lines(text), Fs.path.parent(f)))), Bool.pick(List<&2, String>, known, seen, f <> seen), root)

# ---- the Bend hub: has it published this package, with these exact files? ----
def differing(fs: List<&2, String>, +local: String, +hub: String) -> IO(String):
  match fs:
    case []:
      IO.pure(String, "")
    case +f <> rest:
      do IO<String>:
        same : Bool <- X.succeeds("cmp", ["-s", local ++ "/" ++ f, hub ++ "/" ++ f])
        more : String <- differing(rest, local, hub)
        return Bool.pick(String, same, more, f)

def hub_of(+published: String, +f: String) -> P.Hub:
  Bool.pick(P.Hub, String.is_empty(published), P.Unpublished{}, Bool.pick(P.Hub, String.is_empty(f), P.Same{}, P.Differs{f}))

# The package's hash, as Bend's local cache names it. A package not cached yet is fetched first by
# checking a file that imports it: the hub has it exactly when that succeeds.
def fetch_if(missing: Bool, +home: String, +n: String, +v: String, +e: String, +cached: String) -> IO(String):
  match missing:
    case False{}:
      IO.pure(String, cached)
    case True{}:
      do IO<String>:
        X.write("/tmp/v-probe.bend", "import Base\nimport " ++ n ++ "@" ++ v ++ "/" ++ Fs.path.file_name(e) ++ " as P\n")
        _ : Bool <- X.succeeds(home ++ "/.bend/bin/bend", ["/tmp/v-probe.bend", "--check-only"])
        X.read(home ++ "/.bend/lib/names/" ++ n ++ "@" ++ v)

def fetched(+home: String, +n: String, +v: String, +e: String, +cached: String) -> IO(String):
  fetch_if(String.is_empty(String.trim(cached)), home, n, v, e, cached)

def hub_state(+home: String, +root: String, p: Rl.Package) -> IO(P.Hub):
  match p:
    case Rl.Package{+n, +v, +e, _}:
      do IO<P.Hub>:
        cached : String <- X.read(home ++ "/.bend/lib/names/" ++ n ++ "@" ++ v)
        +hash : String <- fetched(home, n, v, e, cached)
        +files : List<&2, String> <- reach(1000n, [e], [], root)
        f : String <- differing(files, root, home ++ "/.bend/lib/" ++ String.trim(hash))
        return hub_of(String.trim(hash), f)

def hub_states(+home: String, +root: String, ps: List<&2, Rl.Package>) -> IO(List<&2, P.Hub>):
  match ps:
    case []:
      IO.pure(List<&2, P.Hub>, [])
    case p <> rest:
      do IO<List<&2, P.Hub>>:
        h : P.Hub <- hub_state(home, root, p)
        hs : List<&2, P.Hub> <- hub_states(home, root, rest)
        return h <> hs

# ---- GitHub ----
def first_word(+t: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, X.nonempty(String.split(t, '\t'))), "")

def pushed(+root: String, +sha: String) -> IO(Bool):
  Bool.pick(IO(Bool), String.is_empty(sha), IO.pure(Bool, False{}), X.succeeds("git", ["-C", root, "merge-base", "--is-ancestor", "HEAD", sha]))

def remote(+root: String, r: Rl.Repository) -> IO(P.Remote):
  match r:
    case Rl.Repository{+name, _}:
      do IO<P.Remote>:
        origin : String <- X.run("git", ["-C", root, "remote", "get-url", "origin"])
        vis : String <- X.run("gh", ["repo", "view", name, "--json", "visibility", "--jq", ".visibility"])
        status : String <- X.run("git", ["-C", root, "status", "--porcelain"])
        head : String <- X.run("git", ["-C", root, "ls-remote", "origin", "refs/heads/main"])
        up : Bool <- pushed(root, first_word(head))
        return P.Remote{String.trim(origin), String.to_lower(String.trim(vis)), String.is_empty(String.trim(status)), up}

# ---- a plugin: a fresh build of it, next to what its marketplace has tagged for its version ----
# Built under .git/v-plugin/<name>, never committed: build/ is what a release would hold at
# plugins/<name>, tag/ is the marketplace at the tag, repo/ the marketplace a release writes.
def plugin_dir(+root: String, +n: String) -> String:
  root ++ "/.git/v-plugin/" ++ n

def tag_of(+n: String, +v: String) -> String:
  n ++ "-v" ++ v

def last_segment(xs: List<&2, String>) -> String:
  Maybe.default(&2, String, List.last(&2, String, xs), "")

def owner_of(+r: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, String.split(r, '/')), "")

def str_of(m: Maybe<&2, Json.Val>) -> String:
  match m:
    case Some{Json.Str{s}}:
      s
    case _:
      ""

def version_in(m: Maybe<&2, Json.Val>) -> String:
  match m:
    case Some{v}:
      str_of(Json.get(v, "version"))
    case None{}:
      ""

def obj.go(kvs: List<&2, Sigma<&2, &2, String, _ => Json.Val>>, m: Map<&2, Json.Val>) -> Map<&2, Json.Val>:
  match kvs:
    case []:
      m
    case (k, v) <> rest:
      obj.go(rest, Map.set(&2, Json.Val, m, k, v))

def obj(kvs: List<&2, Sigma<&2, &2, String, _ => Json.Val>>) -> Json.Val:
  Json.Obj{obj.go(kvs, Map.new(&2, Json.Val))}

# The marketplace's other plugins, as listed now.
def others(vs: List<&2, Json.Val>, +n: String) -> List<&2, Json.Val>:
  match vs:
    case []:
      []
    case +v <> rest:
      +kept = others(rest, n)
      Bool.pick(List<&2, Json.Val>, String.eq(str_of(Json.get(v, "name")), n), kept, v <> kept)

def listed(m: Maybe<&2, Json.Val>) -> List<&2, Json.Val>:
  match m:
    case Some{Json.Arr{vs}}:
      vs
    case _:
      []

# The marketplace's listing with this plugin at this version, every other plugin as it was.
def marketplace(+now: String, +n: String, +v: String, +r: String) -> String:
  +m = Json.parse(now)
  Json.encode(obj([
    ("name", Json.Str{last_segment(String.split(r, '/'))}),
    ("owner", obj([("name", Json.Str{owner_of(r)})])),
    ("plugins", Json.Arr{List.append(&2, Json.Val, others(listed(Bool.pick(Maybe<&2, Json.Val>, Maybe.is_some(&2, Json.Val, m), Json.get(Maybe.default(&2, Json.Val, m, Json.Null{}), "plugins"), None{})), n),
      [obj([("name", Json.Str{n}), ("source", Json.Str{"./plugins/" ++ n}), ("version", Json.Str{v})])])})])) ++ "\n"

def build_plugin(+root: String, +bend: String, +n: String, +e: String) -> IO(String):
  do IO<String>:
    +build : String = plugin_dir(root, n) ++ "/build"
    _ : Bool <- X.succeeds("rm", ["-rf", plugin_dir(root, n)])
    _ : Bool <- X.succeeds("mkdir", ["-p", build])
    ok : Bool <- X.succeeds(bend, [root ++ "/" ++ e, "plugin", build])
    manifest : String <- X.read(build ++ "/.claude-plugin/plugin.json")
    return Bool.pick(String, ok, version_in(Json.parse(manifest)), "")

def tag_differs(tagged: Bool, +root: String, +n: String, +v: String, +r: String) -> IO(Bool):
  match tagged:
    case False{}:
      IO.pure(Bool, False{})
    case True{}:
      do IO<Bool>:
        _ : Bool <- X.succeeds("git", ["clone", "-q", "--depth", "1", "--branch", tag_of(n, v), "https://github.com/" ++ r, plugin_dir(root, n) ++ "/tag"])
        same : Bool <- X.succeeds("diff", ["-rq", plugin_dir(root, n) ++ "/build", plugin_dir(root, n) ++ "/tag/plugins/" ++ n])
        return Bool.not(same)

def tag_state(+home: String, +root: String, g: Rl.Plugin) -> IO(P.Tag):
  match g:
    case Rl.Plugin{+n, ver, +e, _, Rl.Repository{+r, _}}:
      do IO<P.Tag>:
        +v : String = PlO.version_show(ver)
        built : String <- build_plugin(root, home ++ "/.bend/bin/bend", n, e)
        valid : Bool <- X.succeeds("claude", ["plugin", "validate", "--strict", plugin_dir(root, n) ++ "/build"])
        +repo : Bool <- X.succeeds("gh", ["repo", "view", r, "--json", "name"])
        tags : String <- X.run("git", ["ls-remote", "--tags", "https://github.com/" ++ r, "refs/tags/" ++ tag_of(n, v)])
        +tagged : Bool = repo && Bool.not(String.is_empty(String.trim(tags)))
        differs : Bool <- tag_differs(tagged, root, n, v, r)
        return P.Tag{repo, tagged, built, valid, differs}

def tag_states(+home: String, +root: String, gs: List<&2, Rl.Plugin>) -> IO(List<&2, P.Tag>):
  match gs:
    case []:
      IO.pure(List<&2, P.Tag>, [])
    case g <> rest:
      do IO<List<&2, P.Tag>>:
        t : P.Tag <- tag_state(home, root, g)
        ts : List<&2, P.Tag> <- tag_states(home, root, rest)
        return t <> ts

# Codex's listing of the same marketplace (.agents/plugins/marketplace.json), with this plugin available and
# every other plugin as it was.
def codex_marketplace(+now: String, +n: String, +r: String) -> String:
  +m = Json.parse(now)
  Json.encode(obj([
    ("name", Json.Str{last_segment(String.split(r, '/'))}),
    ("interface", obj([("displayName", Json.Str{last_segment(String.split(r, '/'))})])),
    ("plugins", Json.Arr{List.append(&2, Json.Val, others(listed(Bool.pick(Maybe<&2, Json.Val>, Maybe.is_some(&2, Json.Val, m), Json.get(Maybe.default(&2, Json.Val, m, Json.Null{}), "plugins"), None{})), n),
      [obj([("name", Json.Str{n}), ("source", obj([("source", Json.Str{"local"}), ("path", Json.Str{"./plugins/" ++ n})])),
        ("policy", obj([("installation", Json.Str{"AVAILABLE"}), ("authentication", Json.Str{"ON_USE"})])),
        ("category", Json.Str{"Productivity"})])])})])) ++ "\n"

# A release: the build into plugins/<name>, both listings updated, committed, tagged and pushed.
def release_plugin(+root: String, +n: String, +v: String, +r: String, create: Bool) -> IO(Bool):
  do IO<Bool>:
    +repo : String = plugin_dir(root, n) ++ "/repo"
    _ : Bool <- Bool.pick(IO(Bool), create, X.succeeds("gh", ["repo", "create", r, "--public", "--description", "Claude Code plugins, built and released by V."]), IO.pure(Bool, True{}))
    _ : Bool <- X.succeeds("rm", ["-rf", repo])
    _ : Bool <- X.succeeds("git", ["clone", "-q", "https://github.com/" ++ r, repo])
    _ : Bool <- X.succeeds("mkdir", ["-p", repo ++ "/plugins/" ++ n, repo ++ "/.claude-plugin", repo ++ "/.agents/plugins"])
    _ : Bool <- X.succeeds("rsync", ["-a", "--delete", plugin_dir(root, n) ++ "/build/", repo ++ "/plugins/" ++ n ++ "/"])
    now : String <- X.read(repo ++ "/.claude-plugin/marketplace.json")
    X.write(repo ++ "/.claude-plugin/marketplace.json", marketplace(now, n, v, r))
    codex_now : String <- X.read(repo ++ "/.agents/plugins/marketplace.json")
    X.write(repo ++ "/.agents/plugins/marketplace.json", codex_marketplace(codex_now, n, r))
    _ : Bool <- X.succeeds("git", ["-C", repo, "add", "-A"])
    _ : Bool <- X.succeeds("git", ["-C", repo, "commit", "-q", "-m", n ++ " " ++ v])
    _ : Bool <- X.succeeds("git", ["-C", repo, "tag", tag_of(n, v)])
    X.succeeds("git", ["-C", repo, "push", "-q", "origin", "HEAD:main", tag_of(n, v)])

# ---- a snapshot: everything a plan needs ----
def root() -> IO(String):
  do IO<String>:
    t : String <- X.run("git", ["rev-parse", "--show-toplevel"])
    return String.trim(t)

# The files, what the packages' entries and the system's own entry reach, the hub, and GitHub.
def observe(+root: String, +entry: String, r: Rl.Release) -> IO(P.Observed):
  match r:
    case Rl.Release{repo, +ps, +gs}:
      do IO<P.Observed>:
        +h : String <- X.home()
        +fs : List<&2, String> <- files(root)
        reached : List<&2, String> <- reach(Nat.mul(1n+List.length(&2, String, fs), 1n+List.length(&2, String, fs)), entry <> List.append(&2, String, RlO.entries(ps), RlO.plugin_entries(gs)), [], root)
        hs : List<&2, P.Hub> <- hub_states(h, root, ps)
        rm : P.Remote <- remote(root, repo)
        ts : List<&2, P.Tag> <- tag_states(h, root, gs)
        return P.Observed{fs, reached, hs, rm, ts}

# ---- a deploy: carry out a plan with nothing blocked ----
# Loading a launch agent: `launchctl bootout` returns before the old job is gone, and loading it again fails
# until it is, so this tries every quarter second, up to `fuel` times.
def bootstrap_after(fuel: Nat, ok: Bool, +domain: String, +path: String) -> IO(Bool):
  match fuel:
    case 0n:
      IO.pure(Bool, ok)
    case 1n+k:
      match ok:
        case True{}:
          IO.pure(Bool, True{})
        case False{}:
          do IO<Bool>:
            IO.sleep(250)
            again : Bool <- X.succeeds("/bin/launchctl", ["bootstrap", domain, path])
            bootstrap_after(k, again, domain, path)

def bootstrap(fuel: Nat, +domain: String, +path: String) -> IO(Bool):
  do IO<Bool>:
    first : Bool <- X.succeeds("/bin/launchctl", ["bootstrap", domain, path])
    bootstrap_after(fuel, first, domain, path)

def apply(+root: String, +bend: String, s: P.Step) -> IO(Unit):
  match s:
    case P.Current{_}:
      IO.print(PO.show(s))
    case P.Publish{+n, +v, +e}:
      do IO<Unit>:
        out : String <- X.run(bend, [root ++ "/" ++ e, "--publish", n ++ "@" ++ v])
        IO.print(Bool.pick(String, String.contains(out, "published"), "published " ++ n ++ "@" ++ v, "failed   publish " ++ n ++ "@" ++ v))
    case P.Push{+r}:
      do IO<Unit>:
        ok : Bool <- X.succeeds("git", ["-C", root, "push", "-q", "origin", "HEAD:main"])
        IO.print(Bool.pick(String, ok, "pushed   github " ++ r, "failed   push github " ++ r))
    case P.ReleasePlugin{+n, +v, +r, create}:
      do IO<Unit>:
        ok : Bool <- release_plugin(root, n, v, r, create)
        IO.print(Bool.pick(String, ok, "released plugin " ++ n ++ "@" ++ v, "failed   release plugin " ++ n ++ "@" ++ v))
    case P.BuildNext{+f, +tree, +dir}:
      do IO<Unit>:
        +src : String = root ++ "/.git/v-launchd/next-src"
        _ : Bool <- X.succeeds("/bin/rm", ["-rf", src])
        _ : Bool <- X.succeeds("/bin/mkdir", ["-p", src])
        cloned : Bool <- X.succeeds("/usr/bin/rsync", ["-a", "--exclude", "node_modules", "--exclude", ".next", root ++ "/" ++ f ++ "/", src ++ "/"])
        deps : Bool <- X.succeeds("/run/current-system/sw/bin/npm", ["--prefix", src, "ci", "--no-audit", "--no-fund"])
        built : Bool <- X.succeeds("/run/current-system/sw/bin/npm", ["--prefix", src, "run", "build"])
        _ : Bool <- X.succeeds("/bin/mkdir", ["-p", dir ++ "/.next"])
        copied : Bool <- X.succeeds("/usr/bin/rsync", ["-a", "--delete", "--exclude", ".next/static", src ++ "/.next/standalone/", dir ++ "/"])
        _ : Bool <- X.succeeds("/usr/bin/rsync", ["-a", "--delete", src ++ "/.next/static/", dir ++ "/.next/static/"])
        +ok : Bool = cloned && deps && built && copied
        Bool.pick(IO(Unit), ok, X.write(dir ++ "/.v-commit", tree), IO.pure(Unit, Unit{}))
        IO.print(Bool.pick(String, ok, "built    " ++ f ++ " into " ++ dir, "failed   build " ++ f))
    case P.Install{+from, +to}:
      do IO<Unit>:
        _ : Bool <- X.succeeds("/bin/mkdir", ["-p", Fs.path.parent(to)])
        ok : Bool <- X.succeeds("/bin/cp", [from, to])
        IO.print(Bool.pick(String, ok, "installed " ++ to, "failed   install " ++ to))
    case P.Launch{+l, +path, +plist, +domain}:
      do IO<Unit>:
        _ : Bool <- X.succeeds("/bin/mkdir", ["-p", Fs.path.parent(path)])
        X.write(path, plist)
        _ : Bool <- X.succeeds("/bin/launchctl", ["bootout", domain ++ "/" ++ l])
        ok : Bool <- bootstrap(20n, domain, path)
        IO.print(Bool.pick(String, ok, "launched " ++ l, "failed   launch " ++ l))
    case P.Rebuild{+h, +fl, +mac}:
      do IO<Unit>:
        _ : Result<&1, &1, U32 & String, Unit> <- Fs.mkdir(root ++ "/nix")
        X.write(root ++ "/nix/flake.nix", fl)
        X.write(root ++ "/nix/mac.nix", mac)
        ok : Bool <- X.succeeds("sudo", ["-n", "/run/current-system/sw/bin/darwin-rebuild", "switch", "--flake", root ++ "/nix#" ++ h])
        IO.print(Bool.pick(String, ok, "rebuilt  nix-darwin " ++ h, "failed   darwin-rebuild switch " ++ h))
    case P.ServePort{+p, +t, ts}:
      do IO<Unit>:
        ok : Bool <- X.succeeds(ts, ["serve", "--bg", "--yes", "--https=" ++ U32.show(p), t])
        IO.print(Bool.pick(String, ok, "served   :" ++ U32.show(p) ++ " -> " ++ t, "failed   serve :" ++ U32.show(p)))
    case P.Change{_, _, _}:
      IO.pure(Unit, Unit{})
    case P.Blocked{_, _}:
      IO.print(PO.show(s))

def apply_all(+root: String, +bend: String, ss: List<&2, P.Step>) -> IO(Unit):
  match ss:
    case []:
      IO.pure(Unit, Unit{})
    case s <> rest:
      do IO<Unit>:
        apply(root, bend, s)
        apply_all(root, bend, rest)

def deploy_if(blocked: Bool, +root: String, +ss: List<&2, P.Step>) -> IO(Unit):
  match blocked:
    case True{}:
      IO.die(Unit, 1, PO.show_all(ss) ++ "nothing deployed: the plan is blocked")
    case False{}:
      do IO<Unit>:
        +h : String <- X.home()
        apply_all(root, h ++ "/.bend/bin/bend", ss)

def deploy(+root: String, +ss: List<&2, P.Step>) -> IO(Unit):
  deploy_if(PO.any_blocked(ss), root, ss)

# ---- the whole plan: the release, the stack, each deployment node, and what the deploy would break ----
# ---- a nix-darwin node: its checks, what a rebuild would change, and the rebuild when anything would ----
def has_change(ss: List<&2, P.Step>) -> Bool:
  match ss:
    case []:
      False{}
    case s <> rest:
      match s:
        case P.Change{_, _, _}:
          True{}
        case _:
          has_change(rest)

def mac_of(nd: ND.NixDarwin) -> String:
  match nd:
    case ND.NixDarwin{_, _, _, _, _, st, fw, br, _, _, _, _, _, _}:
      StO.mac_nix(st, fw, br)

def host_of(nd: ND.NixDarwin) -> String:
  match nd:
    case ND.NixDarwin{h, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      h

def rebuild_if(c: Bool, +h: String, +fl: String, +mac: String) -> List<&2, P.Step>:
  match c:
    case True{}:
      [P.Rebuild{h, fl, mac}]
    case False{}:
      [P.Current{"nix-darwin " ++ h}]

# Whether a generated file differs from the one in the repository (compared by cmp, not in memory).
def differs(+path: String, +text: String) -> IO(Bool):
  do IO<Bool>:
    X.write("/tmp/v-generated", text)
    same : Bool <- X.succeeds("cmp", ["-s", "/tmp/v-generated", path])
    return Bool.not(same)

def darwin_steps(+root: String, +k: String, +nd: ND.NixDarwin) -> IO(List<&2, P.Step>):
  match nd:
    case ND.NixDarwin{_, _, _, _, _, +st, +fw, +br, _, _, _, _, _, _}:
      do IO<List<&2, P.Step>>:
        checks : List<&2, P.Step> <- NDE.checks(k, nd)
        +settings : List<&2, P.Step> <- StE.changes(st, fw)
        +brews : List<&2, P.Step> <- BrE.changes(br)
        flake_new : Bool <- differs(root ++ "/nix/flake.nix", NDO.flake(nd))
        mac_new : Bool <- differs(root ++ "/nix/mac.nix", mac_of(nd))
        return List.append(&2, P.Step, checks, List.append(&2, P.Step, settings, List.append(&2, P.Step, brews,
          rebuild_if(flake_new || mac_new || has_change(settings) || has_change(brews), host_of(nd), NDO.flake(nd), mac_of(nd)))))

def platform_steps(p: D.Platform, +root: String, +k: String, +a: A.Architecture) -> IO(List<&2, P.Step>):
  match p:
    case D.Unmanaged{}:
      IO.pure(List<&2, P.Step>, [])
    case D.Darwin{+nd}:
      darwin_steps(root, k, nd)
    case D.AzureCloud{az}:
      AzE.checks(az, O.agreement(a))
    case D.Launchd{ld}:
      LdE.checks(root, k, ld)

def node_steps(ns: List<&2, D.Node>, +root: String, +a: A.Architecture) -> IO(List<&2, P.Step>):
  match ns:
    case []:
      IO.pure(List<&2, P.Step>, [])
    case n <> rest:
      match n:
        case D.Node{+k, _, _, _, _, pf, kids, _}:
          do IO<List<&2, P.Step>>:
            here : List<&2, P.Step> <- platform_steps(pf, root, k, a)
            below : List<&2, P.Step> <- node_steps(kids, root, a)
            after : List<&2, P.Step> <- node_steps(rest, root, a)
            return List.append(&2, P.Step, here, List.append(&2, P.Step, below, after))

def deployed_path(+root: String) -> String:
  root ++ "/.git/v-deployed"

def breaks_step(+bs: List<&2, D.Break>, +d: D.Deployment) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, DO.breaks_eq(bs, DO.accepted(d)), [],
    [P.Blocked{"deployment", DO.show_breaks(bs) ++ " (declare it as accepted to deploy)"}])

# What the deploy would break, against what this repository last deployed (recorded in .git, never committed).
def deployed_steps(+root: String, +d: D.Deployment) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    +text : String <- X.read(deployed_path(root))
    return breaks_step(DO.breaks(DO.recorded_address(text), DO.recorded_stores(text), d), d)

def plan_all(+root: String, +entry: String, +a: A.Architecture) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    o : P.Observed <- observe(root, entry, SO.release(O.system(a)))
    stack : List<&2, P.Step> <- CtE.checks(root, O.containers(a), O.externals(a))
    nodes : List<&2, P.Step> <- node_steps(O.nodes(a), root, a)
    breaks : List<&2, P.Step> <- deployed_steps(root, O.deployment(a))
    return List.append(&2, P.Step, stack, List.append(&2, P.Step, nodes, List.append(&2, P.Step, breaks, PO.plan(SO.release(O.system(a)), o))))

# A deploy of the whole plan; afterwards it records the deployment, so the next plan compares against it.
def deploy_all(+root: String, +entry: String, +a: A.Architecture) -> IO(Unit):
  do IO<Unit>:
    +steps : List<&2, P.Step> <- plan_all(root, entry, a)
    deploy(root, steps)
    X.write(deployed_path(root), DO.record(O.deployment(a)))

# ---- import: each nix-darwin node's Mac as it is now, as Bend to declare it with ----
def import_node(p: D.Platform, +root: String) -> IO(Unit):
  match p:
    case D.Darwin{nd}:
      match nd:
        case ND.NixDarwin{h, _, _, _, _, _, _, _, svs, _, _, _, _, _}:
          do IO<Unit>:
            st : List<&2, St.Setting> <- StE.observed(root ++ "/nix/options.tsv", SvO.labels(svs))
            fw : St.Firewall <- StE.firewall_now()
            br : List<&2, Br.Brew> <- BrE.observed()
            IO.print("# " ++ h ++ "\n" ++ StO.import_text(st, fw, br))
    case _:
      IO.pure(Unit, Unit{})

def import_nodes(ns: List<&2, D.Node>, +root: String) -> IO(Unit):
  match ns:
    case []:
      IO.pure(Unit, Unit{})
    case n <> rest:
      match n:
        case D.Node{_, _, _, _, _, pf, kids, _}:
          do IO<Unit>:
            import_node(pf, root)
            import_nodes(kids, root)
            import_nodes(rest, root)

def import_all(+root: String, a: A.Architecture) -> IO(Unit):
  import_nodes(O.nodes(a), root)
