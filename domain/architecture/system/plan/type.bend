import Base

# What the Bend hub has for one declared package.
type Hub is Data:
  Unpublished{}
  Same{}
  Differs{file: String}

# What GitHub and the working tree say about the repository.
type Remote is Data:
  Remote{origin: String, visibility: String, clean: Bool, pushed: Bool}

# What GitHub has for one declared plugin, next to a fresh build of it: whether its marketplace exists,
# whether it is tagged <name>-v<version>, the version the build declares ("" when it did not build),
# whether `claude plugin validate` accepts the build, and whether the build differs from what the tag
# holds.
type Tag is Data:
  Tag{repository: Bool, tagged: Bool, built: String, valid: Bool, differs: Bool}

# What the world looks like now, as far as a release is concerned.
type Observed is Data:
  Observed{files: List<&2, String>, reached: List<&2, String>, hubs: List<&2, Hub>, remote: Remote, tags: List<&2, Tag>}

# One step of a plan. Publish, Push, ReleasePlugin, Rebuild, ServePort and Launch change the world; Current and Change do not
# (a Change is what a Rebuild would change, shown by a dry run); Blocked stops the deploy.
# Rebuild: write a nix-darwin node's flake and darwin-rebuild switch it. ServePort: serve a tailnet
# HTTPS port from a local target, with the given Tailscale command. Launch: write a launch agent's plist and
# (re)load it in the user's launchd domain.
type Step is Data:
  Current{what: String}
  Publish{name: String, version: String, entry: String}
  Push{repository: String}
  ReleasePlugin{name: String, version: String, marketplace: String, create: Bool}
  Rebuild{host: String, flake: String, mac: String}
  ServePort{https: U32, target: String, tailscale: String}
  Launch{label: String, path: String, plist: String, domain: String}
  Install{from: String, to: String}
  BuildNext{folder: String, tree: String, dir: String}
  BuildNode{folder: String, tree: String, dir: String}
  Change{what: String, now: String, want: String}
  Blocked{what: String, why: String}
