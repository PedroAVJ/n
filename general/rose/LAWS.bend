import Base
import ./type.bend as R
import ./ops.bend as O

# LAW: a tree's first key is its own
law first_key_is_own:
  for -N: Data
  for +r: R.Rose<N>
  {O.first(O.keys(N, [r])) == O.key(N, r) : String}
