import Base
import ../rose/type.bend as R
import ./edge/type.bend as E

# A compound graph: a forest of rose trees (what contains what) plus edges between any two keys.
type Compound<-N: Data> is Data:
  Compound{roots: List<&2, R.Rose<N>>, edges: List<&2, E.Edge>}
