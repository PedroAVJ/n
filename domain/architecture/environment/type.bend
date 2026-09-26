import Base
import ./party/type.bend as P
import ./external/type.bend as X
import ./constraint/type.bend as K

# What a system is designed against: who uses it, the systems around it, and its constraints.
type Environment is Data:
  Environment{parties: List<&2, P.Party>, externals: List<&2, X.External>, constraints: List<&2, K.Constraint>}
