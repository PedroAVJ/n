# V: describe a system once, as types, in Bend, and derive everything else from it. Named after Victor Taelin, who created Bend.
import Base
import ./v.bend as M
import ./project.bend as P
import ./vimport.bend as I
import ./vdry.bend as D

# The `v` command.
def usage() -> IO(Unit):
  IO.print("usage: v check | plan | snapshot | import | dryrun | deploy | diagram [out.png]")

def plan() -> IO(Unit):
  do IO<Unit>:
    p : String <- P.run_bend("plan.bend")
    IO.print(p)

def pick_io(c: Bool, a: IO(Unit), b: IO(Unit)) -> IO(Unit):
  match c:
    case True{}:
      a
    case False{}:
      b

def first_or(xs: List<String>, d: String) -> String:
  match xs:
    case []:
      d
    case x <> _:
      x

def run(+cmd: String, rest: List<String>) -> IO(Unit):
  pick_io(String.eq(cmd, "check"), M.check(),
  pick_io(String.eq(cmd, "plan"), plan(),
  pick_io(String.eq(cmd, "snapshot"), M.snapshot_only(),
  pick_io(String.eq(cmd, "import"), I.import_mac(),
  pick_io(String.eq(cmd, "dryrun"), D.dryrun(),
  pick_io(String.eq(cmd, "deploy"), M.deploy(),
  pick_io(String.eq(cmd, "diagram"), M.diagram(first_or(rest, "diagram.png")), usage())))))))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case []:
      usage()
    case cmd <> rest:
      run(cmd, rest)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
