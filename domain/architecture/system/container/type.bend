import Base
import ../../relationship/type.bend as Rel
import ../../category/type.bend as K
import ./component/type.bend as Co

# Who can reach it: its own machine, the local network, the tailnet, the device it is on, anyone.
type Exposure is Data:
  Local{}
  Lan{}
  Tailnet{}
  Device{}
  Public{}

# Whether the system builds it, or uses it as it is.
type Ownership is Data:
  Ours{}
  Theirs{}

# Something that runs on its own: an app, an API, a database, a command. Its technology: the vendors
# behind it, the frameworks and libraries it is built with, and its languages; `source` is its folder
# in the repository ("" when it has none), and `migrating` the declared technology it does not use yet.
type Container is Data:
  Container{key: String, name: String, description: String, category: K.Category, ownership: Ownership, exposure: Exposure, capabilities: List<&2, K.Capability>, source: String, vendors: List<&2, String>, frameworks: List<&2, String>, libraries: List<&2, String>, languages: List<&2, String>, migrating: List<&2, String>, components: List<&2, Co.Component>, uses: List<&2, Rel.Relationship>}
