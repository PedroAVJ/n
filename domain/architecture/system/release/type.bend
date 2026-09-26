import Base
import ./plugin/type.bend as Pl

# A package on the Bend hub: its name, version (four numbers), entry file and the components it ships.
type Package is Data:
  Package{name: String, version: String, entry: String, components: List<&2, String>}

# The system's repository on GitHub (owner/name), and whether it is public.
type Repository is Data:
  Repository{name: String, public: Bool}

# A plugin for Claude Code and Codex: built by its entry's `plugin <dir>` command at its version (semver),
# shipping its components, and released into a marketplace: a GitHub repository holding each plugin under
# plugins/<name>, listed for Claude Code in .claude-plugin/marketplace.json and for Codex in
# .agents/plugins/marketplace.json, and tagged <name>-v<version>. The marketplace is named after its
# repository.
type Plugin is Data:
  Plugin{name: String, version: Pl.Version, entry: String, components: List<&2, String>, marketplace: Repository}

# What the system publishes.
type Release is Data:
  Release{repository: Repository, packages: List<&2, Package>, plugins: List<&2, Plugin>}
