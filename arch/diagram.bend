import Base
import near-architecture@0.9.1.0/arc.bend as A
import ./canvas.bend as V

# V's architecture diagram (D2), drawn by Arc.
def main() -> IO(Unit):
  IO.print(A.d2(V.system()))
