import Base
import ./type.bend as R
import ./ops.bend as O
import ./LAWS.bend as Laws

def Laws.first_key_is_own(N, r):
  match r:
    case R.Rose{k, v, kids}:
      {==}
