import Base
import ../nix_darwin/type.bend as ND

# A Mac where V installs only its own programs, launch agents and Tailscale serves, beside whatever else
# configures the machine (nix-darwin, another system's deploy): nothing it does not declare is touched.

# How a program comes to be at its path: installed by something else; built from a Bend file in the
# repository; a Next.js app built from a folder of the repository (standalone), its build at the path; or
# a Node program: a folder of the repository copied to the path with its dependencies installed.
type Build is Data:
  Installed{}
  Bend{entry: String}
  Next{folder: String}
  Node{folder: String}

type Program is Data:
  Program{path: String, build: Build}

type Variable is Data:
  Variable{key: String, value: String}

# A per-user launchd job running one of the system's containers with its command and arguments, kept alive,
# logging to ~/Library/Logs/<log>.log, and listening on a local port (0 for none). It is relaunched whenever
# one of the node's programs is installed.
type Agent is Data:
  Agent{container: String, label: String, command: String, args: List<&2, String>, env: List<&2, Variable>, log: String, port: U32}

type Launchd is Data:
  Launchd{programs: List<&2, Program>, agents: List<&2, Agent>, serves: List<&2, ND.Serve>}
