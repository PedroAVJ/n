import Base

# A package on the Bend hub: its name, version (four numbers), entry file and the components it ships.
type Package is Data:
  Package{name: String, version: String, entry: String, components: List<&2, String>}

# The system's repository on GitHub (owner/name), and whether it is public.
type Repository is Data:
  Repository{name: String, public: Bool}

# A Claude Code plugin: built by its entry's `plugin <dir>` command at its version (semver), shipping its
# components, and released to its own GitHub repository, which is also the marketplace it installs from,
# tagged v<version>.
type Plugin is Data:
  Plugin{name: String, version: String, entry: String, components: List<&2, String>, repository: Repository}

# What the system publishes.
type Release is Data:
  Release{repository: Repository, packages: List<&2, Package>, plugins: List<&2, Plugin>}
