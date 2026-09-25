import Base
import ../lib/effs/io.bend as X
import ../lib/vstr.bend as S
import ../lib/mac_types.bend as T
import ./project.bend as P
import ./vazure.bend as Azure
import ./vsources.bend as Src
import bend-net-json@0.3.0.0/json.bend as Json

# V's command line, run in a project's folder. All logic is Bend; other programs run through
# X.Proc.run (a C effect). The project's own programs (facts, plan, flake, laws...) run fresh, as `bend <file>`.

def tailscale() -> String:
  "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# ---- snapshot: the Mac as it is, into bend/machine.bend ----
def pid_if(hit: Bool, l: String) -> String:
  match hit:
    case True{}:
      String.drop(l, 6n)
    case False{}:
      ""

def pid_in(ls: List<&2, String>) -> String:
  match ls:
    case []:
      ""
    case +l <> rest:
      pid_if(String.starts_with(String.trim(l), "pid = "), String.trim(l)) ++ pid_in(rest)

def pids(labels: List<&2, String>, +uid: String) -> IO(List<&2, String>):
  match labels:
    case []:
      IO.pure(List<&2, String>, [])
    case l <> rest:
      do IO<List<&2, String>>:
        out : String <- X.sh("launchctl print gui/" ++ uid ++ "/" ++ l ++ " 2>/dev/null")
        more : List<&2, String> <- pids(rest, uid)
        return pid_in(String.lines(out)) <> more

def port_if(keep: Bool, p: String) -> List<&2, String>:
  match keep:
    case True{}:
      [p]
    case False{}:
      []

# ---- listening sockets, from `lsof -F pcn` (one field per line: p<pid>, c<command>, n<address:port>) ----
type Listen is Data:
  Listen{pid: String, cmd: String, addr: String}

def field(+l: String) -> String:
  String.drop(l, 1n)

def emit_if(name: Bool, +l: String, +pid: String, +cmd: String) -> List<&2, Listen>:
  match name:
    case True{}:
      [Listen{pid, cmd, field(l)}]
    case False{}:
      []

def emit(+l: String, +pid: String, +cmd: String) -> List<&2, Listen>:
  emit_if(String.starts_with(l, "n"), l, pid, cmd)

def listens(ls: List<&2, String>, +pid: String, +cmd: String) -> List<&2, Listen>:
  match ls:
    case []:
      []
    case +l <> rest:
      List.append(&2, Listen, emit(l, pid, cmd), listens(rest, S.pick(String.starts_with(l, "p"), field(l), pid), S.pick(String.starts_with(l, "c"), field(l), cmd)))

def port_of_addr(+addr: String) -> String:
  S.last(String.split(addr, ':'))

def host_of(+addr: String) -> String:
  String.join(List.take(&2, String, String.split(addr, ':'), Nat.sub(S.count(String.split(addr, ':')), 1n)), ":")

def loopback(+addr: String) -> Bool:
  String.eq(host_of(addr), "127.0.0.1") || String.eq(host_of(addr), "[::1]")

# Ports held by anything but Tailscale's own listener and V's processes (declared or V-installed).
def foreign_ports(xs: List<&2, Listen>, +owned: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case Listen{+pid, +cmd, +addr}:
          S.append(port_if(Bool.not(String.eq(cmd, "IPNExtension")) && Bool.not(T.has(pid, owned)), port_of_addr(addr)), foreign_ports(rest, owned))

# Ports that V's own processes listen on.
def owned_ports(xs: List<&2, Listen>, +owned: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case Listen{+pid, _, +addr}:
          S.append(port_if(T.has(pid, owned), port_of_addr(addr)), owned_ports(rest, owned))

# "process port" for listeners beyond 127.0.0.1 / [::1]: reachable from other machines.
def exposed(xs: List<&2, Listen>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case Listen{_, +cmd, +addr}:
          S.append(port_if(Bool.not(loopback(addr)), cmd ++ " " ++ port_of_addr(addr)), exposed(rest))

# Tailscale Serve status as JSON (bend-net-json):
#   {"Web": {"<host>:<port>": {"Handlers": {"/": {"Proxy": "http://127.0.0.1:<local>[/path]"}}}}}
def url_port(w: String) -> String:
  S.digits(S.last(String.split(w, ':')))

def json_or_null(m: Maybe<&2, Json.Val>) -> Json.Val:
  match m:
    case None{}:
      Json.Null{}
    case Some{v}:
      v

def at(v: Json.Val, k: String) -> Json.Val:
  json_or_null(Json.get(v, k))

def str_of(v: Json.Val) -> String:
  match v:
    case Json.Str{s}:
      s
    case _:
      ""

def obj_keys(v: Json.Val) -> List<&2, String>:
  match v:
    case Json.Obj{m}:
      Map.keys(&2, Json.Val, m)
    case _:
      []

# The Serve "Web" object of `tailscale serve status --json`.
def web_of(s: String) -> Json.Val:
  at(json_or_null(Json.parse(s)), "Web")

def proxy(+web: Json.Val, k: String) -> String:
  str_of(at(at(at(at(web, k), "Handlers"), "/"), "Proxy"))

# Served ports whose proxy target is not one of `declared` local ports.
def web_serves(+web: Json.Val, ks: List<&2, String>, +declared: List<&2, String>) -> List<&2, String>:
  match ks:
    case []:
      []
    case +k <> rest:
      S.append(port_if(Bool.not(T.has(url_port(proxy(web, k)), declared)), url_port(k)), web_serves(web, rest, declared))

# Whether `port` is already served by exactly `target`.
def serving(+web: Json.Val, ks: List<&2, String>, +port: String, +target: String) -> Bool:
  match ks:
    case []:
      False{}
    case +k <> rest:
      (String.eq(url_port(k), port) && String.eq(proxy(web, k), target)) || serving(web, rest, port, target)


# launchctl list: third column is the label; macOS's own are left out.
def agent_if(+label: String) -> List<&2, String>:
  port_if(Bool.not(String.is_empty(label)) && Bool.not(String.starts_with(label, "com.apple.")) && Bool.not(String.starts_with(label, "application.")) && Bool.not(String.eq(label, "com.openssh.ssh-agent")), label)

def agent_labels(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      S.append(agent_if(S.nth(String.split(l, '\t'), 2n)), agent_labels(rest))

# Repository evidence is captured beside the machine facts. A source line is "key folder".
type Stack is Data:
  Stack{deps: List<&2, String>, extensions: List<&2, String>}

def prefix(+key: String, xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      (key ++ ":" ++ x) <> prefix(key, rest)

def package_deps(+v: Json.Val) -> List<&2, String>:
  List.append(&2, String, obj_keys(at(v, "dependencies")), obj_keys(at(v, "devDependencies")))

def choose_package(empty: Bool, local: String, root: Json.Val) -> Json.Val:
  match empty:
    case True{}:
      root
    case False{}:
      json_or_null(Json.parse(local))

def package_or_root(+local: String, root: Json.Val) -> Json.Val:
  choose_package(String.is_empty(local), local, root)

def module_name(line: String) -> String:
  +words : List<&2, String> = S.words(String.trim(line))
  +first : String = S.nth(words, 0n)
  +second : String = S.nth(words, 1n)
  S.pick(String.eq(first, "require") && String.starts_with(S.nth(words, 2n), "v"), second,
    S.pick(String.starts_with(second, "v") && Bool.not(String.eq(first, "module")), first, ""))

def go_deps(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      S.append(port_if(Bool.not(String.is_empty(module_name(l))), module_name(l)), go_deps(rest))

def source_ext(path: String) -> String:
  +name : String = S.last(String.split(path, '/'))
  +ext : String = "." ++ S.last(String.split(name, '.'))
  S.pick(Bool.not(String.contains(name, ".generated.")) &&
    (String.eq(ext, ".ts") || String.eq(ext, ".tsx") || String.eq(ext, ".js") ||
     String.eq(ext, ".jsx") || String.eq(ext, ".mjs") || String.eq(ext, ".go") || String.eq(ext, ".py")), ext, "")

def source_extensions(paths: List<&2, String>) -> List<&2, String>:
  match paths:
    case []:
      []
    case +p <> rest:
      S.append(port_if(Bool.not(String.is_empty(source_ext(p))), source_ext(p)), source_extensions(rest))

def stack_source(+line: String, root_json: Json.Val, +go: List<&2, String>) -> IO(Stack):
  do IO<Stack>:
    +key : String = S.nth(S.words(line), 0n)
    +source : String = S.nth(S.words(line), 1n)
    local_json : String <- X.sh("cat '../" ++ source ++ "/../package.json' 2>/dev/null")
    components : String <- X.sh("test -f '../" ++ source ++ "/../components.json' && echo shadcn/ui")
    files : String <- X.sh("find '../" ++ source ++ "' -type d \\( -name node_modules -o -name _generated -o -name .next \\) -prune -o -type f -print 2>/dev/null")
    +json : Json.Val = package_or_root(local_json, root_json)
    +deps : List<&2, String> = S.dedupe(List.append(&2, String, package_deps(json), List.append(&2, String, go, S.nonempty(String.lines(components)))))
    return Stack{prefix(key, deps), prefix(key, S.dedupe(source_extensions(String.lines(files))))}

def join_stack(a: Stack, b: Stack) -> Stack:
  match a:
    case Stack{ds, es}:
      match b:
        case Stack{mds, mes}:
          Stack{List.append(&2, String, ds, mds), List.append(&2, String, es, mes)}

def stack_sources(lines: List<&2, String>, +root_json: Json.Val, +go: List<&2, String>) -> IO(Stack):
  match lines:
    case []:
      IO.pure(Stack, Stack{[], []})
    case line <> rest:
      do IO<Stack>:
        +one : Stack <- stack_source(line, root_json, go)
        +more : Stack <- stack_sources(rest, root_json, go)
        return join_stack(one, more)

def repository_stack(sources: List<&2, String>) -> IO(Stack):
  do IO<Stack>:
    package : String <- X.sh("cat ../package.json 2>/dev/null")
    go : String <- X.sh("cat ../go.mod 2>/dev/null")
    stack_sources(sources, json_or_null(Json.parse(package)), go_deps(String.lines(go)))

def stack_text(stack: Stack) -> String:
  match stack:
    case Stack{deps, extensions}:
      "# Package dependencies and source extensions by container key.\n" ++
      "def deps() -> List<&2, String>:\n  [" ++ S.quote_all(deps) ++ "]\n\n" ++
      "def extensions() -> List<&2, String>:\n  [" ++ S.quote_all(extensions) ++ "]\n"

def machine_text(ports: List<&2, String>, serves: List<&2, String>, agents: List<&2, String>, installed: List<&2, String>, exposed: List<&2, String>, stack: Stack) -> String:
  "import Base\n\n# The machine as it was when `v system snapshot` ran. Generated; do not edit.\n\n" ++
  "def foreign_ports() -> List<&2, U32>:\n  [" ++ String.join(ports, ", ") ++ "]\n\n" ++
  "def foreign_serves() -> List<&2, U32>:\n  [" ++ String.join(serves, ", ") ++ "]\n\n" ++
  "def agents() -> List<&2, String>:\n  [" ++ S.quote_all(agents) ++ "]\n\n" ++
  "# Launch agents V itself installed at the last deploy (nix-darwin's current generation); the next deploy reconciles them.\n" ++
  "def installed() -> List<&2, String>:\n  [" ++ S.quote_all(installed) ++ "]\n\n" ++
  "# Programs listening beyond 127.0.0.1 (\"process port\"): reachable from other machines.\n" ++
  "def exposed() -> List<&2, String>:\n  [" ++ S.quote_all(exposed) ++ "]\n\n" ++ stack_text(stack)

def snapshot(+f: P.Facts) -> IO(Unit):
  do IO<Unit>:
    uid : String <- X.sh("id -u")
    +inst : String <- X.sh("ls /run/current-system/user/Library/LaunchAgents 2>/dev/null | sed 's/[.]plist$//'")
    +owned : List<&2, String> <- pids(S.append(P.labels_of(f), S.nonempty(String.lines(inst))), String.trim(uid))
    lsof : String <- X.sh("lsof +c 0 -nP -iTCP -sTCP:LISTEN -F pcn")
    +sockets : List<&2, Listen> = listens(String.lines(lsof), "", "")
    serve : String <- X.sh(tailscale() ++ " serve status --json")
    list : String <- X.sh("launchctl list")
    +ports : List<&2, String> = S.dedupe(foreign_ports(sockets, owned))
    +web : Json.Val = web_of(serve)
    +serves : List<&2, String> = web_serves(web, obj_keys(web), S.append(P.ports_of(f), owned_ports(sockets, owned)))
    +agents : List<&2, String> = agent_labels(List.drop(&2, String, String.lines(list), 1n))
    +stack : Stack <- repository_stack(P.sources_of(f))
    X.write_file("machine.bend", machine_text(ports, serves, agents, S.nonempty(String.lines(inst)), S.dedupe(exposed(sockets)), stack))
    IO.print("snapshot: " ++ Nat.show(S.count(ports)) ++ " foreign ports, " ++ Nat.show(S.count(serves)) ++ " foreign serves, " ++ Nat.show(S.count(agents)) ++ " launch agents")

# ---- check, plan, diagram ----
def fail_or(ok: Bool, out: String, then: IO(Unit)) -> IO(Unit):
  match ok:
    case True{}:
      then
    case False{}:
      IO.die(Unit, 1, out)

# Prove the laws against the current snapshot. Anything unproven stops V.
def prove() -> IO(Unit):
  do IO<Unit>:
    +out : String <- P.check_bend("PROOF.bend")
    fail_or(String.contains(out, "All terms check."), out, IO.print("laws: all proven"))

# Every architecture is one graph with one start (lib/text.bend). V writes that claim as graph.bend and
# checks it for every project, before its own laws.
def graph_text(+vlib: String) -> String:
  "import Base\nimport " ++ vlib ++ "/text.bend as T\nimport ./canvas.bend as V\n\n# Written by `v system check`: this architecture is one graph with one start. Do not edit.\ndef one_start() -> {T.one_start(V.system()) == True{} : Bool}:\n  {==}\n"

def one_graph(+f: P.Facts) -> IO(Unit):
  do IO<Unit>:
    X.write_file("graph.bend", graph_text(P.vlib_of(f)))
    +out : String <- P.check_bend("graph.bend")
    fail_or(String.contains(out, "All terms check."), "not one graph with one start:\n" ++ out, IO.print("graph: one start"))

# The machine is snapshotted only for a project that configures it (a nix-darwin target).
def check_with(+f: P.Facts) -> IO(Unit):
  do IO<Unit>:
    P.when(P.has_target(f, "nix-darwin"), snapshot(f))
    P.when(P.has_target(f, "azure"), Azure.snapshot(f))
    P.when(P.has_target(f, "bend-hub"), Src.write_sources(f))
    one_graph(f)
    prove()

def check() -> IO(Unit):
  do IO<Unit>:
    f : P.Facts <- P.read_facts()
    check_with(f)

def snapshot_only() -> IO(Unit):
  do IO<Unit>:
    +f : P.Facts <- P.read_facts()
    P.when(P.has_target(f, "nix-darwin"), snapshot(f))
    P.when(P.has_target(f, "azure"), Azure.snapshot(f))
    P.when(P.has_target(f, "bend-hub"), Src.write_sources(f))

def diagram(+out: String) -> IO(Unit):
  do IO<Unit>:
    d2 : String <- P.run_bend("diagram.bend")
    X.write_file("/tmp/v-diagram.d2", d2)
    +ok : Bool <- X.ok("d2 --layout elk /tmp/v-diagram.d2 " ++ out ++ " >/dev/null 2>&1")
    fail_or(ok, "d2 failed", IO.print(out))

# ---- deploy ----
# One "serve <port> <local>" plan line: make sure Tailscale serves it.
def serve_apply(current: Bool, +port: String, +local: String) -> IO(Unit):
  match current:
    case True{}:
      IO.print("current  serve :" ++ port ++ " -> " ++ local)
    case False{}:
      do IO<Unit>:
        IO.print("deploy   serve :" ++ port ++ " -> " ++ local)
        +ok : Bool <- X.ok(tailscale() ++ " serve --bg --yes --https=" ++ port ++ " http://127.0.0.1:" ++ local)
        fail_or(ok, "failed: serve " ++ port, IO.pure(Unit, Unit{}))

def serve_do(is_serve: Bool, current: Bool, +port: String, +local: String) -> IO(Unit):
  match is_serve:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      serve_apply(current, port, local)

def serve_step(+w: List<&2, String>, +web: Json.Val) -> IO(Unit):
  serve_do(String.eq(S.nth(w, 0n), "serve"), serving(web, obj_keys(web), S.nth(w, 1n), "http://127.0.0.1:" ++ S.nth(w, 2n)), S.nth(w, 1n), S.nth(w, 2n))

def serve_steps(ls: List<&2, String>, +web: Json.Val) -> IO(Unit):
  match ls:
    case []:
      IO.pure(Unit, Unit{})
    case l <> rest:
      do IO<Unit>:
        serve_step(S.words(l), web)
        serve_steps(rest, web)

def applied_text(vlib: String, url: String, stores: String) -> String:
  "import Base\nimport " ++ vlib ++ "/deploy.bend as D\n\n# What is running now (written by `v system deploy`). Generated; do not edit.\ndef applied() -> D.Deployment:\n  D.Deployment{\"" ++ url ++ "\", [" ++ stores ++ "]}\n"

def current_parts(vlib: String, +c: String) -> String:
  applied_text(vlib, String.trim(S.nth(String.lines(c), 0n)), String.trim(S.nth(String.lines(c), 1n)))

# ---- pushing the project's repository to GitHub ----
# The probe answers "current" (GitHub already has HEAD), "pushed <commit>", or "failed <reason>".
# It refuses a repository whose real visibility differs from the declared one.
def push_script(+r: String, +vis: String) -> String:
  "r='" ++ r ++ "'; w='" ++ vis ++ "'; t=$(git rev-parse --show-toplevel 2>/dev/null) || { echo 'failed not a git repository'; exit 0; }; " ++
  "u=$(git -C \"$t\" remote get-url origin 2>/dev/null); case \"$u\" in *github.com/$r|*github.com/$r.git|*github.com:$r.git) ;; *) echo \"failed origin is $u, not $r\"; exit 0;; esac; " ++
  "a=$(gh repo view \"$r\" --json visibility --jq .visibility 2>/dev/null | tr A-Z a-z); [ \"$a\" = \"$w\" ] || { echo \"failed $r is ${a:-unreachable}, declared $w\"; exit 0; }; " ++
  "[ -z \"$(git -C \"$t\" status --porcelain)\" ] || { echo 'failed uncommitted changes'; exit 0; }; " ++
  "git -C \"$t\" fetch -q origin 2>/dev/null || { echo 'failed fetch'; exit 0; }; " ++
  "if git -C \"$t\" rev-parse -q --verify origin/main >/dev/null && git -C \"$t\" merge-base --is-ancestor HEAD origin/main; then echo current; " ++
  "elif git -C \"$t\" push -q origin HEAD:main 2>/dev/null; then echo \"pushed $(git -C \"$t\" rev-parse --short HEAD)\"; else echo 'failed push rejected'; fi"

def push_current(current: Bool, +r: String, +repo: String) -> IO(Unit):
  match current:
    case True{}:
      IO.print("current  github " ++ repo)
    case False{}:
      fail_or(String.starts_with(r, "pushed"), "github " ++ repo ++ ": " ++ r, IO.print("deploy   github " ++ repo ++ " " ++ String.drop(r, 7n)))

def github_push(+repo: String, +vis: String) -> IO(Unit):
  do IO<Unit>:
    +r : String <- X.sh(push_script(repo, vis))
    push_current(String.starts_with(String.trim(r), "current"), String.trim(r), repo)

# ---- publishing a package to the Bend hub ----
# The probe answers "current" (published, same files), "changed <file>", "published", or "failed <reason>".
def publish_script(+n: String, +v: String, +e: String) -> String:
  "n='" ++ n ++ "'; v='" ++ v ++ "'; e='" ++ e ++ "'; b=$(basename \"$e\"); d=$(dirname \"$e\"); " ++
  "printf 'import Base\\nimport %s@%s/%s as P\\n\\ndef main() -> IO(Unit):\\n  IO.print(\"ok\")\\n' \"$n\" \"$v\" \"$b\" > /tmp/v-probe.bend; " ++
  "if $HOME/.bend/bin/bend /tmp/v-probe.bend --check-only >/dev/null 2>&1; then " ++
  "c=\"$HOME/.bend/lib/$(tr -d '\\n' < \"$HOME/.bend/lib/names/$n@$v\")\"; " ++
  "for f in \"$c\"/*; do cmp -s \"$f\" \"$d/$(basename \"$f\")\" || { echo \"changed $(basename \"$f\")\"; exit 0; }; done; echo current; " ++
  "else [ -f \"$d/LICENSE\" ] || { echo 'failed no LICENSE beside the entry'; exit 0; }; " ++
  "out=$($HOME/.bend/bin/bend \"$e\" --publish \"$n@$v\" 2>&1); case \"$out\" in *\"published $n@$v\"*) echo published;; *) echo \"failed $(echo \"$out\" | tail -1)\";; esac; fi"

def publish_other(published: Bool, +r: String, +id: String) -> IO(Unit):
  match published:
    case True{}:
      IO.print("deploy   package " ++ id)
    case False{}:
      fail_or(False{}, "package " ++ id ++ ": " ++ S.pick(String.starts_with(r, "changed"), String.drop(r, 8n) ++ " changed since it was published; bump the version", r), IO.pure(Unit, Unit{}))

def publish_current(current: Bool, +r: String, +id: String) -> IO(Unit):
  match current:
    case True{}:
      IO.print("current  package " ++ id)
    case False{}:
      publish_other(String.starts_with(r, "published"), r, id)

def publish_result(+r: String, +id: String) -> IO(Unit):
  publish_current(String.starts_with(r, "current"), r, id)

def publish(+p: String) -> IO(Unit):
  do IO<Unit>:
    +r : String <- X.sh(publish_script(S.nth(S.words(p), 0n), S.nth(S.words(p), 1n), S.nth(S.words(p), 2n)))
    publish_result(String.trim(r), S.nth(S.words(p), 0n) ++ "@" ++ S.nth(S.words(p), 1n))

def publish_all(ps: List<&2, String>) -> IO(Unit):
  match ps:
    case []:
      IO.pure(Unit, Unit{})
    case p <> rest:
      do IO<Unit>:
        publish(p)
        publish_all(rest)

# ---- deploy: prove, then run each target the project declares ----
def nix_darwin(+f: P.Facts) -> IO(Unit):
  do IO<Unit>:
    flake : String <- P.run_bend("flake.bend")
    X.write_file("nix/flake.nix", flake)
    mac : String <- P.run_bend("mac.gen.bend")
    X.write_file("nix/mac.nix", mac)
    staged : Bool <- X.ok("git add nix")
    IO.print("deploy   nix-darwin (" ++ P.flake_host(f) ++ ")")
    +ok : Bool <- X.ok("sudo -n /run/current-system/sw/bin/darwin-rebuild switch --flake \"$(pwd)/nix#" ++ P.flake_host(f) ++ "\" >/tmp/v-rebuild.log 2>&1")
    fail_or(ok, "failed: darwin-rebuild switch (see /tmp/v-rebuild.log)", IO.pure(Unit, Unit{}))

def tailscale_serve() -> IO(Unit):
  do IO<Unit>:
    status : String <- X.sh(tailscale() ++ " serve status --json")
    plan : String <- P.run_bend("plan.bend")
    serve_steps(String.lines(plan), web_of(status))

# A project with a deployment (current.bend) records what is now running, for the breaks law.
def record(has: Bool, +vlib: String) -> IO(Unit):
  match has:
    case True{}:
      do IO<Unit>:
        +cur : String <- P.run_bend("current.bend")
        X.write_file("applied.bend", current_parts(vlib, cur))
        IO.print("deployed: " ++ String.trim(S.nth(String.lines(cur), 0n)))
    case False{}:
      IO.print("deployed")

def deploy() -> IO(Unit):
  do IO<Unit>:
    +f : P.Facts <- P.read_facts()
    check_with(f)
    P.when(P.has_target(f, "nix-darwin"), nix_darwin(f))
    P.when(P.has_target(f, "tailscale-serve"), tailscale_serve())
    P.when(P.has_target(f, "github"), github_push(P.github_repo(f), P.github_visibility(f)))
    P.when(P.has_target(f, "bend-hub"), publish_all(P.packages_of(f)))
    has : Bool <- X.ok("test -f current.bend")
    record(has, P.vlib_of(f))
