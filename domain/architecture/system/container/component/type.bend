import Base
import ../../../relationship/type.bend as Rel

# The language a component is written in.
type Language is Data:
  Bend{}
  C{}
  Rust{}
  TypeScript{}
  JavaScript{}
  Python{}
  Go{}
  Opaque{}

# A piece of a container: a module, a set of functions, a C effect.
type Component is Data:
  Component{key: String, name: String, description: String, language: Language, uses: List<&2, Rel.Relationship>}
