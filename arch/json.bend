import Base
import ../lib/text.bend as T
import ./canvas.bend as V

# This architecture as JSON, for the interactive viewer.
def main() -> IO(Unit):
  IO.print(T.json(V.system(), V.kind(), V.tenants(), {==}))
