import Base

# A package on the Bend hub: its name, version (four numbers), entry file and the components it ships.
type Package is Data:
  Package{name: String, version: String, entry: String, components: List<&2, String>}

# The system's repository on GitHub (owner/name), and whether it is public.
type Repository is Data:
  Repository{name: String, public: Bool}

# What the system publishes.
type Release is Data:
  Release{repository: Repository, packages: List<&2, Package>}
