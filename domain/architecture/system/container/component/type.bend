import Base
import ../../../relationship/type.bend as Rel

# A piece of a container: a module, a set of functions, a C effect.
type Component is Data:
  Component{key: String, name: String, description: String, technology: String, uses: List<&2, Rel.Relationship>}
