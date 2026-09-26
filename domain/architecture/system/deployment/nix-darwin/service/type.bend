import Base

# The program a service runs, pinned by Nix.
type Program is Data:
  RunNode{}
  RunPython{}
  RunBash{}

# An environment variable: a plain value, or a Nix expression (a path in a derivation the flake defines).
type Env is Data:
  Plain{key: String, value: String}
  Expr{key: String, expr: String}

# When it starts: at login, in the user's session (Keychain, apps); or at boot, with no session.
type Start is Data:
  AtLogin{}
  AtBoot{}

# A launchd job running one of the system's containers, listening on a local port (0 for none).
type Service is Data:
  Service{container: String, label: String, program: Program, args: List<&2, String>, dir: String, env: List<&2, Env>, log: String, start: Start, port: U32}
