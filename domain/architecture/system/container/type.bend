import Base
import ../../relationship/type.bend as Rel
import ./component/type.bend as Co

# Who can reach it: its own machine, the local network, the tailnet, the device it is on, anyone.
type Exposure is Data:
  Local{}
  Lan{}
  Tailnet{}
  Device{}
  Public{}

# What it provides to the rest of the system.
type Capability is Data:
  Hosting{}
  Realtime{}
  BlobStore{}
  Observability{}

# Whether the system builds it, or uses it as it is.
type Ownership is Data:
  Ours{}
  Theirs{}

# Something that runs on its own: an app, an API, a database, a command.
type Container is Data:
  Container{key: String, name: String, description: String, technology: String, ownership: Ownership, exposure: Exposure, capabilities: List<&2, Capability>, components: List<&2, Co.Component>, uses: List<&2, Rel.Relationship>}
