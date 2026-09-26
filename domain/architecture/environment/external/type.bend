import Base
import ../../relationship/type.bend as Rel
import ../../category/type.bend as K

# Another organization's system: what it is and provides, who is behind it, the libraries its callers
# use (its SDK), and what it does with the system; never its insides.
type External is Data:
  External{key: String, name: String, description: String, category: K.Category, capabilities: List<&2, K.Capability>, vendors: List<&2, String>, libraries: List<&2, String>, uses: List<&2, Rel.Relationship>}
