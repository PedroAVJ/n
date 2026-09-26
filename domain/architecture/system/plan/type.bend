import Base

# What the Bend hub has for one declared package.
type Hub is Data:
  Unpublished{}
  Same{}
  Differs{file: String}

# What GitHub and the working tree say about the repository.
type Remote is Data:
  Remote{origin: String, visibility: String, clean: Bool, pushed: Bool}

# What the world looks like now, as far as a release is concerned.
type Observed is Data:
  Observed{files: List<&2, String>, reached: List<&2, String>, hubs: List<&2, Hub>, remote: Remote}

# One step of a plan. Publish and Push change the world; Current does not; Blocked stops the deploy.
type Step is Data:
  Current{what: String}
  Publish{name: String, version: String, entry: String}
  Push{repository: String}
  Blocked{what: String, why: String}
