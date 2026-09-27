import Base
import ../nix_darwin/type.bend as ND

# A Mac where V installs only its own launch agents and Tailscale serves, beside whatever else configures
# the machine (nix-darwin, another system's deploy): nothing it does not declare is touched.

type Variable is Data:
  Variable{key: String, value: String}

# A per-user launchd job running one of the system's containers, kept alive, logging to
# ~/Library/Logs/<log>.log, and listening on a local port (0 for none). Its program is built from `entry`, a
# Bend file in the repository, and installed at `program`; with no entry, it is installed by something else.
type Agent is Data:
  Agent{container: String, label: String, program: String, entry: String, args: List<&2, String>, env: List<&2, Variable>, log: String, port: U32}

type Launchd is Data:
  Launchd{agents: List<&2, Agent>, serves: List<&2, ND.Serve>}
