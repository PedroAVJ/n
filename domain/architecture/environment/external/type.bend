import Base
import ../../relationship/type.bend as Rel

# Another organization's system: only its name and what it does, never its insides.
type External is Data:
  External{key: String, name: String, description: String, uses: List<&2, Rel.Relationship>}
