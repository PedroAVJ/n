import Base
import ./type.bend as R

def key(-N: Data, r: R.Rose<N>) -> String:
  match r:
    case R.Rose{k, _, _}:
      k

# Every key in a forest, each tree's own key before its children's.
def keys(-N: Data, rs: List<&2, R.Rose<N>>) -> List<&2, String>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case R.Rose{k, _, kids}:
          k <> List.append(&2, String, keys(N, kids), keys(N, rest))

# The first key of a list, "" for none.
def first(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> _:
      x

# Where a key sits: the keys above it, nearest first.
type Place is Data:
  Place{key: String, above: List<&2, String>}

def places(-N: Data, rs: List<&2, R.Rose<N>>, +above: List<&2, String>) -> List<&2, Place>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case R.Rose{+k, _, kids}:
          Place{k, above} <> List.append(&2, Place, places(N, kids, k <> above), places(N, rest, above))

def found(-N: Data, hit: Bool, v: N, below: Maybe<&2, N>, after: Maybe<&2, N>) -> Maybe<&2, N>:
  match hit:
    case True{}:
      Some{v}
    case False{}:
      Maybe.or(&2, N, below, after)

# The value at a key, if the forest has it.
def find(-N: Data, +k: String, rs: List<&2, R.Rose<N>>) -> Maybe<&2, N>:
  match rs:
    case []:
      None{}
    case r <> rest:
      match r:
        case R.Rose{rk, v, kids}:
          found(N, String.eq(k, rk), v, find(N, k, kids), find(N, k, rest))
