import Base
import ./party/type.bend as P
import ./external/type.bend as X
import ./constraint/type.bend as K
import ./inventory/type.bend as I
import ./agreement/type.bend as G

# What a system is designed against: who uses it, the systems around it, its constraints, what its
# owner has, and the agreement with the people who work on it.
type Environment is Data:
  Environment{parties: List<&2, P.Party>, externals: List<&2, X.External>, constraints: List<&2, K.Constraint>, inventory: I.Inventory, agreement: G.Agreement}
