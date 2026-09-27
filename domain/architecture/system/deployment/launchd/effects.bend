import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ../../effs/io.bend as X
import ../../plan/type.bend as P
import ../nix_darwin/type.bend as ND
import ../nix_darwin/effects.bend as NDE
import ./type.bend as L
import ./ops.bend as LO

# What a launchd node needs, from the Mac as it is: each agent's program installed, its plist as declared and
# loaded, its port held by nothing else; and each Tailscale serve as declared.

def tailscale() -> String:
  "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

def program_of(a: L.Agent) -> String:
  match a:
    case L.Agent{_, _, program, _, _, _, _, _}:
      program

# The program: current, to install from its build, or blocked when it neither builds nor is installed.
def program_step(+entry: String, built: Bool, same: Bool, present: Bool, +from: String, +program: String, +what: String) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, String.is_empty(entry),
    Bool.pick(List<&2, P.Step>, present, [], [P.Blocked{what, program ++ " is not installed"}]),
    Bool.pick(List<&2, P.Step>, Bool.not(built), [P.Blocked{what, entry ++ " does not build"}],
      Bool.pick(List<&2, P.Step>, same, [P.Current{"program " ++ program}], [P.Install{from, program}])))

# The agent is current only while its program is as built, its plist as declared, and it is loaded; otherwise it
# is (re)launched, after its program installs.
def agent_step(present: Bool, +current: String, loaded: Bool, +home: String, +domain: String, +what: String, a: L.Agent) -> P.Step:
  match a:
    case L.Agent{_, +label, +program, _, _, _, _, _}:
      +want = LO.plist(home, a)
      Bool.pick(P.Step, present && String.eq(current, want) && loaded, P.Current{"launch agent " ++ label},
        P.Launch{label, LO.path(home, label), want, domain})

def agent_steps(xs: List<&2, L.Agent>, +root: String, +home: String, +domain: String, +socks: List<&2, String>, +what: String) -> IO(List<&2, P.Step>):
  match xs:
    case []:
      IO.pure(List<&2, P.Step>, [])
    case +a <> rest:
      do IO<List<&2, P.Step>>:
        +label : String = LO.label_of(a)
        +entry : String = LO.entry_of(a)
        +from : String = root ++ "/.git/v-launchd/" ++ label
        _ : Bool <- X.succeeds("/bin/mkdir", ["-p", root ++ "/.git/v-launchd"])
        built : Bool <- Bool.pick(IO(Bool), String.is_empty(entry), IO.pure(Bool, False{}), X.succeeds(home ++ "/.bend/bin/bend", [root ++ "/" ++ entry, "-o", from]))
        +same : Bool <- X.succeeds("/usr/bin/cmp", ["-s", from, program_of(a)])
        +installed : Bool <- X.succeeds("/bin/test", ["-x", program_of(a)])
        +present : Bool = installed && (String.is_empty(entry) || same)
        current : String <- X.read(LO.path(home, label))
        loaded : Bool <- X.succeeds("/bin/launchctl", ["print", domain ++ "/" ++ label])
        owned : List<&2, String> <- NDE.pids([domain ++ "/" ++ label])
        +port : String = U32.show(LO.port_of(a))
        +held : List<&2, String> = NDE.dedupe(NDE.holders(socks, port, owned, "IPNExtension"))
        more : List<&2, P.Step> <- agent_steps(rest, root, home, domain, socks, what)
        return List.append(&2, P.Step, program_step(entry, built, same, installed, from, program_of(a), what),
          agent_step(present, current, loaded, home, domain, what, a) <>
          List.append(&2, P.Step, Bool.pick(List<&2, P.Step>, U32.is_eq(LO.port_of(a), 0), [], NDE.blocked_by(held, what, "local port " ++ port ++ " is held by ")), more))

def observe(+root: String, +what: String, +ld: L.Launchd, +uid: String, lsof: String) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    +home : String <- X.home()
    status : String <- X.run(tailscale(), ["serve", "status", "--json"])
    agents : List<&2, P.Step> <- agent_steps(LO.agents(ld), root, home, "gui/" ++ uid, NDE.sockets(NDE.lines(lsof), "", ""), what)
    return List.append(&2, P.Step, agents,
      NDE.serve_steps(LO.serves(ld), NDE.at(NDE.or_null(Json.parse(status)), "Web"), NDE.ports(LO.ports(LO.agents(ld))), tailscale(), what))

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
