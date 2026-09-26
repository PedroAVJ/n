import Base
import bend-kit-files@0.1.0.0/files.bend as Fs
import ./effs/io.bend as X
import ../type.bend as A
import ../ops.bend as O
import ./container/effects.bend as CtE
import ./deployment/type.bend as D
import ./deployment/ops.bend as DO
import ./deployment/azure/effects.bend as AzE
import ./deployment/nix-darwin/type.bend as ND
import ./deployment/nix-darwin/ops.bend as NDO
import ./deployment/nix-darwin/effects.bend as NDE
import ./deployment/nix-darwin/setting/type.bend as St
import ./deployment/nix-darwin/setting/ops.bend as StO
import ./deployment/nix-darwin/brew/type.bend as Br
import ./deployment/nix-darwin/setting/effects.bend as StE
import ./deployment/nix-darwin/brew/effects.bend as BrE
import ./deployment/nix-darwin/service/ops.bend as SvO
import ./release/type.bend as Rl
import ./release/ops.bend as RlO
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

def hub_state(+home: String, +root: String, p: Rl.Package) -> IO(P.Hub):
  match p:
    case Rl.Package{n, v, +e, _}:
      do IO<P.Hub>:
        +hash : String <- X.read(home ++ "/.bend/lib/names/" ++ n ++ "@" ++ v)
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

# ---- a snapshot: everything a plan needs ----
def root() -> IO(String):
  do IO<String>:
    t : String <- X.run("git", ["rev-parse", "--show-toplevel"])
    return String.trim(t)

# The files, what the packages' entries and the system's own entry reach, the hub, and GitHub.
def observe(+root: String, +entry: String, r: Rl.Release) -> IO(P.Observed):
  match r:
    case Rl.Release{repo, +ps}:
      do IO<P.Observed>:
        +h : String <- X.home()
        +fs : List<&2, String> <- files(root)
        reached : List<&2, String> <- reach(Nat.mul(1n+List.length(&2, String, fs), 1n+List.length(&2, String, fs)), entry <> RlO.entries(ps), [], root)
        hs : List<&2, P.Hub> <- hub_states(h, root, ps)
        rm : P.Remote <- remote(root, repo)
        return P.Observed{fs, reached, hs, rm}

# ---- a deploy: carry out a plan with nothing blocked ----
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
