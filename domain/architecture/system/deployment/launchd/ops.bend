import Base
import ../../../../../general/markup/type.bend as M
import ../../../../../general/markup/ops.bend as MO
import ../nix_darwin/type.bend as ND
import ./type.bend as L

# A launch agent's property list, written as XML through markup.

def key(+k: String) -> M.Node:
  M.Element{"key", [], [M.Text{k}]}

def str(+s: String) -> M.Node:
  M.Element{"string", [], [M.Text{s}]}

def strs(xs: List<&2, String>) -> List<&2, M.Node>:
  match xs:
    case []:
      []
    case x <> rest:
      str(x) <> strs(rest)

def vars(vs: List<&2, L.Variable>) -> List<&2, M.Node>:
  match vs:
    case []:
      []
    case L.Variable{k, v} <> rest:
      key(k) <> str(v) <> vars(rest)

def path(+home: String, +label: String) -> String:
  home ++ "/Library/LaunchAgents/" ++ label ++ ".plist"

def plist(+home: String, a: L.Agent) -> String:
  match a:
    case L.Agent{_, label, command, args, env, +log, _}:
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++
      "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" ++
      MO.print([M.Element{"plist", [M.Attribute{"version", "1.0"}], [M.Element{"dict", [], [
        key("Label"), str(label),
        key("ProgramArguments"), M.Element{"array", [], str(command) <> strs(args)},
        key("EnvironmentVariables"), M.Element{"dict", [], vars(env)},
        key("RunAtLoad"), M.Raw{"<true/>"},
        key("KeepAlive"), M.Raw{"<true/>"},
        key("StandardOutPath"), str(home ++ "/Library/Logs/" ++ log ++ ".log"),
        key("StandardErrorPath"), str(home ++ "/Library/Logs/" ++ log ++ ".log")]}]}]) ++ "\n"

def label_of(a: L.Agent) -> String:
  match a:
    case L.Agent{_, label, _, _, _, _, _}:
      label

def programs(ld: L.Launchd) -> List<&2, L.Program>:
  match ld:
    case L.Launchd{xs, _, _}:
      xs

def agents(ld: L.Launchd) -> List<&2, L.Agent>:
  match ld:
    case L.Launchd{_, xs, _}:
      xs

def serves(ld: L.Launchd) -> List<&2, ND.Serve>:
  match ld:
    case L.Launchd{_, _, xs}:
      xs

def port_of(a: L.Agent) -> U32:
  match a:
    case L.Agent{_, _, _, _, _, _, p}:
      p

def ports(xs: List<&2, L.Agent>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case a <> rest:
      port_of(a) <> ports(rest)
