import Base
import ./PROOF.bend as Proof
import ./architecture.bend as V
import ./domain/architecture/system/ops.bend as SO
import ./domain/architecture/system/effects.bend as SE
import ./domain/architecture/system/plan/type.bend as P
import ./domain/architecture/system/plan/ops.bend as PO
import ./domain/architecture/view/effects.bend as VE

# V as a system. It compiles only while V's laws hold, so nothing below runs unless they do.
#   bend system.bend dryrun    what a deploy would change
#   bend system.bend deploy    change it: publish the package, push the source
#   bend system.bend diagram   draw V's views into diagrams/

def dryrun() -> IO(Unit):
  do IO<Unit>:
    +root : String <- SE.root()
    o : P.Observed <- SE.observe(root, "system.bend", SO.release(V.system()))
    IO.print(PO.show_all(PO.plan(SO.release(V.system()), o)))

def deploy() -> IO(Unit):
  do IO<Unit>:
    +root : String <- SE.root()
    o : P.Observed <- SE.observe(root, "system.bend", SO.release(V.system()))
    SE.deploy(root, PO.plan(SO.release(V.system()), o))

def diagram() -> IO(Unit):
  do IO<Unit>:
    +root : String <- SE.root()
    VE.render(V.architecture(), root ++ "/diagrams", V.views())

def command(+c: String) -> IO(Unit):
  Bool.pick(IO(Unit), String.eq(c, "dryrun"), dryrun(),
    Bool.pick(IO(Unit), String.eq(c, "deploy"), deploy(),
      Bool.pick(IO(Unit), String.eq(c, "diagram"), diagram(),
        IO.print("usage: bend system.bend dryrun | deploy | diagram"))))

def first(xs: List<&1, String>) -> String:
  match xs:
    case []:
      ""
    case x <> _:
      x

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    command(first(args))
