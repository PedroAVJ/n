import Base
import ./type.bend as Sv

def container(s: Sv.Service) -> String:
  match s:
    case Sv.Service{c, _, _, _, _, _, _, _, _}:
      c

def label(s: Sv.Service) -> String:
  match s:
    case Sv.Service{_, l, _, _, _, _, _, _, _}:
      l

def port(s: Sv.Service) -> U32:
  match s:
    case Sv.Service{_, _, _, _, _, _, _, _, p}:
      p

def start(s: Sv.Service) -> Sv.Start:
  match s:
    case Sv.Service{_, _, _, _, _, _, _, st, _}:
      st

def labels(xs: List<&2, Sv.Service>) -> List<&2, String>:
  match xs:
    case []:
      []
    case s <> rest:
      label(s) <> labels(rest)

def at_login(s: Sv.Start) -> Bool:
  match s:
    case Sv.AtLogin{}:
      True{}
    case Sv.AtBoot{}:
      False{}

# Whether any service needs a user session to start.
def needs_login(xs: List<&2, Sv.Service>) -> Bool:
  match xs:
    case []:
      False{}
    case s <> rest:
      at_login(start(s)) || needs_login(rest)

# ---- a service as a nix-darwin launchd job ----
# The program's path in the Nix store.
def program(p: Sv.Program) -> String:
  match p:
    case Sv.RunNode{}:
      "\"${pkgs.nodejs_24}/bin/node\""
    case Sv.RunPython{}:
      "\"${pkgs.python3.withPackages (ps: [ ps.watchdog ])}/bin/python3\""
    case Sv.RunBash{}:
      "\"${pkgs.bash}/bin/bash\""

def quoted(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      " \"" ++ x ++ "\"" ++ quoted(rest)

def env(e: Sv.Env) -> String:
  match e:
    case Sv.Plain{k, v}:
      " " ++ k ++ " = \"" ++ v ++ "\";"
    case Sv.Expr{k, x}:
      " " ++ k ++ " = " ++ x ++ ";"

def envs(xs: List<&2, Sv.Env>) -> String:
  match xs:
    case []:
      ""
    case e <> rest:
      env(e) ++ envs(rest)

# At login: a launch agent in the user's session. At boot: a launch daemon that runs as the user.
def job_kind(s: Sv.Start) -> String:
  match s:
    case Sv.AtLogin{}:
      "launchd.user.agents"
    case Sv.AtBoot{}:
      "launchd.daemons"

def user_name(s: Sv.Start, +user: String) -> String:
  match s:
    case Sv.AtLogin{}:
      ""
    case Sv.AtBoot{}:
      " UserName = \"" ++ user ++ "\";"

def job(s: Sv.Service, +user: String, +logs: String) -> String:
  match s:
    case Sv.Service{_, +l, p, args, dir, e, +log, +st, _}:
      "      " ++ job_kind(st) ++ ".\"" ++ l ++ "\".serviceConfig = {\n" ++
      "        Label = \"" ++ l ++ "\";" ++ user_name(st, user) ++ "\n" ++
      "        ProgramArguments = [ " ++ program(p) ++ quoted(args) ++ " ];\n" ++
      "        WorkingDirectory = \"" ++ dir ++ "\";\n" ++
      "        EnvironmentVariables = {" ++ envs(e) ++ " };\n" ++
      "        RunAtLoad = true; KeepAlive = true; ThrottleInterval = 10;\n" ++
      "        StandardOutPath = \"" ++ logs ++ "/" ++ log ++ ".log\";\n" ++
      "        StandardErrorPath = \"" ++ logs ++ "/" ++ log ++ ".log\";\n" ++
      "      };\n"

def jobs(xs: List<&2, Sv.Service>, +user: String, +logs: String) -> String:
  match xs:
    case []:
      ""
    case s <> rest:
      job(s, user, logs) ++ jobs(rest, user, logs)
