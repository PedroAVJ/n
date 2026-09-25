import Base
import ../lib/deploy.bend as D
import ./canvas.bend as V

# What `v` reads from this project: where V's library is, its targets and packages.
def main() -> IO(Unit):
  IO.print(D.facts("../lib", V.targets(), [], [], V.packages(), V.near()))
