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
#   bend system.bend import    print each nix-darwin Mac's current settings as Bend

def dryrun() -> IO(Unit):
  do IO<Unit>:
    +root : String <- SE.root()
    steps : List<&2, P.Step> <- SE.plan_all(root, "system.bend", V.architecture())
    IO.print(PO.show_all(steps))

def deploy() -> IO(Unit):
  do IO<Unit>:
    +root : String <- SE.root()
    SE.deploy_all(root, "system.bend", V.architecture())

def diagram() -> IO(Unit):
  do IO<Unit>:
    +root : String <- SE.root()
    VE.render(V.architecture(), root ++ "/diagrams", V.views())

def import_mac() -> IO(Unit):
  do IO<Unit>:
    +root : String <- SE.root()
    SE.import_all(root, V.architecture())

def command(+c: String) -> IO(Unit):
  Bool.pick(IO(Unit), String.eq(c, "dryrun"), dryrun(),
    Bool.pick(IO(Unit), String.eq(c, "import"), import_mac(),
    Bool.pick(IO(Unit), String.eq(c, "deploy"), deploy(),
      Bool.pick(IO(Unit), String.eq(c, "diagram"), diagram(),
        IO.print("usage: bend system.bend dryrun | deploy | diagram | import")))))

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
