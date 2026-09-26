import Base
import ../../general/rose/ops.bend as RO
import ./type.bend as A
import ./ops.bend as O

# LAW: an architecture's first key is its system's
law first_key_is_system:
  for +a: A.Architecture
  {RO.first(O.keys(a)) == O.system_key(a) : String}
