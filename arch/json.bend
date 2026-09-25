import Base
import ../lib/text.bend as T
import ../lib/deploy.bend as D
import ./canvas.bend as V

# This architecture as JSON, for the interactive viewer.
def main() -> IO(Unit):
  IO.print(T.json(V.system(), V.name(), V.image(), V.owner(), V.kind(), Nat.is_gt(List.length(&2, D.Package, V.packages()), 0n), V.uses(), {==}, {==}, {==}))
