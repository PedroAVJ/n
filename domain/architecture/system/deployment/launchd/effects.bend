import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ../../effs/io.bend as X
import ../../plan/type.bend as P
import ../nix_darwin/type.bend as ND
import ../nix_darwin/effects.bend as NDE
import ./type.bend as L
import ./ops.bend as LO

# What a launchd node needs, from the Mac as it is: each program as its build says, each agent's plist as
# declared and loaded (and relaunched when a program is installed), its port held by nothing else; and each
# Tailscale serve as declared.

def tailscale() -> String:
  "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

def last_segment(+p: String) -> String:
  Maybe.default(&2, String, List.last(&2, String, String.split(p, '/')), p)

# ---- programs ----
def bend_step(built: Bool, same: Bool, +entry: String, +from: String, +path: String, +what: String) -> P.Step:
  Bool.pick(P.Step, Bool.not(built), P.Blocked{what, entry ++ " does not build"},
    Bool.pick(P.Step, same, P.Current{"program " ++ path}, P.Install{from, path}))

def next_step(+sha: String, +installed: String, +repository: String, +path: String, +what: String) -> P.Step:
  Bool.pick(P.Step, String.is_empty(sha), P.Blocked{what, "cannot read " ++ repository ++ "'s main branch"},
    Bool.pick(P.Step, String.eq(sha, installed), P.Current{"program " ++ path ++ " (" ++ repository ++ " @ " ++ String.take(sha, 7n) ++ ")"},
      P.BuildNext{repository, sha, path}))

def program_step(+root: String, +home: String, +what: String, g: L.Program) -> IO(P.Step):
  match g:
    case L.Program{+path, b}:
      match b:
        case L.Installed{}:
          do IO<P.Step>:
            there : Bool <- X.succeeds("/bin/test", ["-e", path])
            return Bool.pick(P.Step, there, P.Current{"program " ++ path}, P.Blocked{what, path ++ " is not installed"})
        case L.Bend{+entry}:
          do IO<P.Step>:
            +from : String = root ++ "/.git/v-launchd/" ++ last_segment(path)
            _ : Bool <- X.succeeds("/bin/mkdir", ["-p", root ++ "/.git/v-launchd"])
            built : Bool <- X.succeeds(home ++ "/.bend/bin/bend", [root ++ "/" ++ entry, "-o", from])
            same : Bool <- X.succeeds("/usr/bin/cmp", ["-s", from, path])
            return bend_step(built, same, entry, from, path, what)
        case L.Next{+repository}:
          do IO<P.Step>:
            sha : String <- X.run("gh", ["api", "repos/" ++ repository ++ "/commits/main", "--jq", ".sha"])
            installed : String <- X.read(path ++ "/.v-commit")
            return next_step(String.trim(sha), String.trim(installed), repository, path, what)

def program_steps(gs: List<&2, L.Program>, +root: String, +home: String, +what: String) -> IO(List<&2, P.Step>):
  match gs:
    case []:
      IO.pure(List<&2, P.Step>, [])
    case g <> rest:
      do IO<List<&2, P.Step>>:
        s : P.Step <- program_step(root, home, what, g)
        more : List<&2, P.Step> <- program_steps(rest, root, home, what)
        return s <> more

def installs(s: P.Step) -> Bool:
  match s:
    case P.Install{_, _}:
      True{}
    case P.BuildNext{_, _, _}:
      True{}
    case _:
      False{}

def any_installs(ss: List<&2, P.Step>) -> Bool:
  match ss:
    case []:
      False{}
    case s <> rest:
      installs(s) || any_installs(rest)

# ---- agents ----
def agent_step(changed: Bool, +current: String, loaded: Bool, +home: String, +domain: String, +a: L.Agent) -> P.Step:
  +label = LO.label_of(a)
  +want = LO.plist(home, a)
  Bool.pick(P.Step, Bool.not(changed) && String.eq(current, want) && loaded, P.Current{"launch agent " ++ label},
    P.Launch{label, LO.path(home, label), want, domain})

def agent_steps(xs: List<&2, L.Agent>, +changed: Bool, +home: String, +domain: String, +socks: List<&2, String>, +what: String) -> IO(List<&2, P.Step>):
  match xs:
    case []:
      IO.pure(List<&2, P.Step>, [])
    case +a <> rest:
      do IO<List<&2, P.Step>>:
        +label : String = LO.label_of(a)
        current : String <- X.read(LO.path(home, label))
        loaded : Bool <- X.succeeds("/bin/launchctl", ["print", domain ++ "/" ++ label])
        owned : List<&2, String> <- NDE.pids([domain ++ "/" ++ label])
        +port : String = U32.show(LO.port_of(a))
        +held : List<&2, String> = NDE.dedupe(NDE.holders(socks, port, owned, "IPNExtension"))
        more : List<&2, P.Step> <- agent_steps(rest, changed, home, domain, socks, what)
        return agent_step(changed, current, loaded, home, domain, a) <>
          List.append(&2, P.Step, Bool.pick(List<&2, P.Step>, U32.is_eq(LO.port_of(a), 0), [], NDE.blocked_by(held, what, "local port " ++ port ++ " is held by ")), more)

def observe(+root: String, +what: String, +ld: L.Launchd, +uid: String, lsof: String) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    +home : String <- X.home()
    status : String <- X.run(tailscale(), ["serve", "status", "--json"])
    +programs : List<&2, P.Step> <- program_steps(LO.programs(ld), root, home, what)
    agents : List<&2, P.Step> <- agent_steps(LO.agents(ld), any_installs(programs), home, "gui/" ++ uid, NDE.sockets(NDE.lines(lsof), "", ""), what)
    return List.append(&2, P.Step, programs, List.append(&2, P.Step, agents,
      NDE.serve_steps(LO.serves(ld), NDE.at(NDE.or_null(Json.parse(status)), "Web"), NDE.ports(LO.ports(LO.agents(ld))), tailscale(), what)))

def read_or(unread: Bool, +root: String, +what: String, ld: L.Launchd, uid: String, lsof: String) -> IO(List<&2, P.Step>):
  match unread:
    case True{}:
      IO.pure(List<&2, P.Step>, [P.Blocked{what, "cannot read the Mac: `id -u` or `lsof` failed"}])
    case False{}:
      observe(root, what, ld, uid, lsof)

def checks(+root: String, +node: String, ld: L.Launchd) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    +uid : String <- X.run("/usr/bin/id", ["-u"])
    +lsof : String <- X.run("/usr/sbin/lsof", ["+c", "0", "-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"])
    read_or(String.is_empty(String.trim(uid)) || String.is_empty(lsof), root, "launchd " ++ node, ld, String.trim(uid), lsof)
