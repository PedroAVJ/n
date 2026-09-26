import Base

# A rose tree: a keyed value and any number of children, each a rose tree itself.
type Rose<-N: Data> is Data:
  Rose{key: String, value: N, children: List<&2, Rose<N>>}
