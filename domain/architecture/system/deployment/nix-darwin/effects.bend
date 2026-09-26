import Base
import bend-kit-files@0.1.0.0/files.bend as Fs
import bend-net-json@0.3.0.0/json.bend as Json
import ../../effs/io.bend as X
import ../../plan/type.bend as P
import ./type.bend as ND
import ./ops.bend as NO
import ./service/type.bend as Sv
import ./service/ops.bend as SvO

# A nix-darwin Mac as it is, read-only: its launch agents and their processes, its listening sockets, what
# Tailscale serves, and whether it logs its user in by itself. What breaks a law becomes a Blocked step.

def dedupe(xs: List<&2, String>) -> List<&2, String>:
  Set.to_list(Set.from_list(xs))

# Lines of a program's output. Base's String.lines recurses once per character, which overflows the
# stack on `launchctl list` (about 20 KB); this walks the text in a loop, keeping each line reversed.
def unreverse(xs: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      acc
    case x <> rest:
      unreverse(rest, String.reverse(x) <> acc)

def lines_go(s: String, +line: String, +acc: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      unreverse(line <> acc, [])
    case SCon{+c, t}:
      +nl = Char.is_eq(c, '\n')
      lines_go(t, Bool.pick(String, nl, "", SCon{c, line}), Bool.pick(List<&2, String>, nl, line <> acc, acc))

def lines(s: String) -> List<&2, String>:
  lines_go(s, "", [])

def last_of(+s: String, c: Char) -> String:
  Maybe.default(&2, String, List.last(&2, String, String.split(s, c)), "")

# ---- the processes V runs: launchctl's pid for each job ----
def pid_of(ls: List<&2, String>) -> String:
  match ls:
    case []:
      ""
    case l <> rest:
      +t = String.trim(l)
      Bool.pick(String, String.starts_with(t, "pid = "), String.drop(t, 6n), pid_of(rest))

def pids(ts: List<&2, String>) -> IO(List<&2, String>):
  match ts:
    case []:
      IO.pure(List<&2, String>, [])
    case t <> rest:
      do IO<List<&2, String>>:
        out : String <- X.run("/bin/launchctl", ["print", t])
        more : List<&2, String> <- pids(rest)
        +p : String = pid_of(lines(out))
        return X.keep_filled(Bool.not(String.is_empty(p)), p, more)

# A service's launchd target: the user's session at login, the system at boot.
def service_targets(xs: List<&2, Sv.Service>, +uid: String) -> List<&2, String>:
  match xs:
    case []:
      []
    case +s <> rest:
      (Bool.pick(String, SvO.at_login(SvO.start(s)), "gui/" ++ uid, "system") ++ "/" ++ SvO.label(s)) <> service_targets(rest, uid)

def agent_targets(xs: List<&2, String>, +uid: String) -> List<&2, String>:
  match xs:
    case []:
      []
    case l <> rest:
      ("gui/" ++ uid ++ "/" ++ l) <> agent_targets(rest, uid)

def plist_label(+f: String) -> String:
  Bool.pick(String, String.ends_with(f, ".plist"), String.take(f, Nat.sub(String.length(f), 6n)), f)

# The launch agents nix-darwin's current generation installed.
def installed(fs: List<&2, String>) -> List<&2, String>:
  match fs:
    case []:
      []
    case +f <> rest:
      plist_label(f) <> installed(rest)

# ---- listening sockets, from `lsof -F pcn` (one field per line: p<pid>, c<command>, n<address:port>) ----
# A socket is "pid<tab>command<tab>address".
def field(+l: String) -> String:
  String.drop(l, 1n)

def sockets(ls: List<&2, String>, +pid: String, +cmd: String) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      X.keep_filled(String.starts_with(l, "n"), pid ++ "\t" ++ cmd ++ "\t" ++ field(l),
        sockets(rest, Bool.pick(String, String.starts_with(l, "p"), field(l), pid), Bool.pick(String, String.starts_with(l, "c"), field(l), cmd)))

def part(+x: String, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, String.split(x, '\t'), n), "")

def loopback(+addr: String) -> Bool:
  String.starts_with(addr, "127.") || String.starts_with(addr, "[::1]:")

# Who holds `port` besides V's processes and Tailscale's own.
def holders(xs: List<&2, String>, +port: String, +owned: List<&2, String>, +tailscale: String) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      +pid = part(x, 0n)
      +cmd = part(x, 1n)
      X.keep_filled(String.eq(last_of(part(x, 2n), ':'), port) && Bool.not(String.eq(cmd, tailscale)) && Bool.not(List.contains(~String, ~String.eq, owned, pid)),
        cmd ++ " (pid " ++ pid ++ ")", holders(rest, port, owned, tailscale))

# Ports that V's processes listen on.
def owned_ports(xs: List<&2, String>, +owned: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      X.keep_filled(List.contains(~String, ~String.eq, owned, part(x, 0n)), last_of(part(x, 2n), ':'), owned_ports(rest, owned))

# "process port" for each socket reachable from other machines whose process is not allowed.
def undeclared_listeners(xs: List<&2, String>, +allowed: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      +cmd = part(x, 1n)
      +addr = part(x, 2n)
      X.keep_filled(Bool.not(loopback(addr)) && Bool.not(List.contains(~String, ~String.eq, allowed, cmd)),
        cmd ++ " " ++ last_of(addr, ':'), undeclared_listeners(rest, allowed))

# ---- launch agents: `launchctl list`'s third column; macOS's own are left out ----
def foreign_agent(+a: String) -> Bool:
  Bool.not(String.is_empty(a)) && Bool.not(String.starts_with(a, "com.apple.")) && Bool.not(String.starts_with(a, "application.")) && Bool.not(String.eq(a, "com.openssh.ssh-agent"))

def undeclared_agents(ls: List<&2, String>, +declared: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      +a = Maybe.default(&2, String, List.get(&2, String, String.split(l, '\t'), 2n), "")
      X.keep_filled(foreign_agent(a) && Bool.not(List.contains(~String, ~String.eq, declared, a)), a, undeclared_agents(rest, declared))

# ---- Tailscale Serve, from `tailscale serve status --json`:
#   {"Web": {"<host>:<port>": {"Handlers": {"/": {"Proxy": "http://127.0.0.1:<local>[/path]"}}}}} ----
def or_null(m: Maybe<&2, Json.Val>) -> Json.Val:
  match m:
    case None{}:
      Json.Null{}
    case Some{v}:
      v

def at(v: Json.Val, k: String) -> Json.Val:
  or_null(Json.get(v, k))

def text(v: Json.Val) -> String:
  match v:
    case Json.Str{s}:
      s
    case _:
      ""

def keys(v: Json.Val) -> List<&2, String>:
  match v:
    case Json.Obj{m}:
      Map.keys(&2, Json.Val, m)
    case _:
      []

# The port of a "host:port" key or a proxy URL.
def url_port(+w: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, String.split(last_of(w, ':'), '/')), "")

def proxy(+web: Json.Val, k: String) -> String:
  text(at(at(at(at(web, k), "Handlers"), "/"), "Proxy"))

# What Tailscale serves on an HTTPS port now, "" when nothing.
def proxy_on(+web: Json.Val, ks: List<&2, String>, +port: String) -> String:
  match ks:
    case []:
      ""
    case +k <> rest:
      Bool.pick(String, String.eq(url_port(k), port), proxy(web, k), proxy_on(web, rest, port))

# A serve is current, to be served, or blocked by Tailscale serving its port to something not V's.
def serve_step(s: ND.Serve, +web: Json.Val, +ours: List<&2, String>, +tailscale: String, +what: String) -> P.Step:
  match s:
    case ND.Serve{_, +h, p, path}:
      +target = "http://127.0.0.1:" ++ U32.show(p) ++ path
      +now = proxy_on(web, keys(web), U32.show(h))
      Bool.pick(P.Step, String.is_empty(now) || List.contains(~String, ~String.eq, ours, url_port(now)),
        Bool.pick(P.Step, String.eq(now, target), P.Current{"serve :" ++ U32.show(h)}, P.ServePort{h, target, tailscale}),
        P.Blocked{what, "tailnet port " ++ U32.show(h) ++ " is served to " ++ now ++ ", which is not V's"})

def serve_steps(xs: List<&2, ND.Serve>, +web: Json.Val, +ours: List<&2, String>, +tailscale: String, +what: String) -> List<&2, P.Step>:
  match xs:
    case []:
      []
    case s <> rest:
      serve_step(s, web, ours, tailscale, what) <> serve_steps(rest, web, ours, tailscale, what)

# ---- the steps ----
def ports(xs: List<&2, U32>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +p <> rest:
      X.keep_filled(Bool.not(U32.is_eq(p, 0)), U32.show(p), ports(rest))

def service_ports(xs: List<&2, Sv.Service>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case s <> rest:
      SvO.port(s) <> service_ports(rest)

def serve_ports(xs: List<&2, ND.Serve>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case s <> rest:
      NO.serve_port(s) <> serve_ports(rest)

def blocked_by(+xs: List<&2, String>, +what: String, +why: String) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, List.is_empty(&2, String, xs), [], [P.Blocked{what, why ++ String.join(xs, ", ")}])

# Each service's local port is free of processes that are not V's.
def local_steps(ps: List<&2, String>, +socks: List<&2, String>, +owned: List<&2, String>, +tailscale: String, +what: String) -> List<&2, P.Step>:
  match ps:
    case []:
      []
    case +p <> rest:
      List.append(&2, P.Step, blocked_by(dedupe(holders(socks, p, owned, tailscale)), what, "local port " ++ p ++ " is held by "),
        local_steps(rest, socks, owned, tailscale, what))

def tailscale_process(on: Bool) -> String:
  Bool.pick(String, on, "tailscaled", "IPNExtension")

def steps(+what: String, +nd: ND.NixDarwin, +installed: List<&2, String>, +owned: List<&2, String>, +socks: List<&2, String>, status: String, list: String, auto: String) -> List<&2, P.Step>:
  +ts = tailscale_process(NO.tailscale(nd))
  +ours = List.append(&2, String, ports(List.append(&2, U32, service_ports(NO.services(nd)), serve_ports(NO.serves(nd)))), owned_ports(socks, owned))
  +declared = List.append(&2, String, SvO.labels(NO.services(nd)), List.append(&2, String, NO.kept(nd), installed))
  List.concat(&2, P.Step, [
    local_steps(ports(service_ports(NO.services(nd))), socks, owned, ts, what),
    blocked_by(dedupe(undeclared_agents(List.drop(&2, String, lines(list), 1n), declared)), what, "undeclared launch agents: "),
    blocked_by(dedupe(undeclared_listeners(socks, NO.listening_processes(NO.listeners(nd)))), what, "undeclared listeners: "),
    Bool.pick(List<&2, P.Step>, NO.survives_reboot(nd, String.trim(auto)), [],
      [P.Blocked{what, "services start at login, but the Mac does not log " ++ NO.user(nd) ++ " in by itself"}]),
    serve_steps(NO.serves(nd), at(or_null(Json.parse(status)), "Web"), ours, NO.tailscale_command(nd), what)])

def observe(+what: String, +nd: ND.NixDarwin, +uid: String, lsof: String) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    r : Result<&1, &1, U32 & String, List<&2, String>> <- Fs.list_dir("/run/current-system/user/Library/LaunchAgents")
    +inst : List<&2, String> = installed(Result.default(&1, &1, U32 & String, List<&2, String>, r, []))
    owned : List<&2, String> <- pids(List.append(&2, String, service_targets(NO.services(nd), uid), agent_targets(inst, uid)))
    status : String <- X.run(NO.tailscale_command(nd), ["serve", "status", "--json"])
    list : String <- X.run("/bin/launchctl", ["list"])
    auto : String <- X.run("/usr/bin/defaults", ["read", "/Library/Preferences/com.apple.loginwindow", "autoLoginUser"])
    return steps(what, nd, inst, owned, sockets(lines(lsof), "", ""), status, list, auto)

def read_or(unread: Bool, +what: String, nd: ND.NixDarwin, uid: String, lsof: String) -> IO(List<&2, P.Step>):
  match unread:
    case True{}:
      IO.pure(List<&2, P.Step>, [P.Blocked{what, "cannot read the Mac: `id -u` or `lsof` failed"}])
    case False{}:
      observe(what, nd, uid, lsof)

# The laws that need the Mac as it is, and what Tailscale must serve: a node's checks before a deploy.
def checks(+node: String, nd: ND.NixDarwin) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    +uid : String <- X.run("/usr/bin/id", ["-u"])
    +lsof : String <- X.run("/usr/sbin/lsof", ["+c", "0", "-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"])
    read_or(String.is_empty(String.trim(uid)) || String.is_empty(lsof), "nix-darwin " ++ node, nd, String.trim(uid), lsof)
