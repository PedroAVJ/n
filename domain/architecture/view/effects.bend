import Base
import ../system/effs/io.bend as X
import bend-kit-files@0.1.0.0/files.bend as Fs
import ../type.bend as A
import ./type.bend as Vw
import ./ops.bend as VO

# Drawing views to files: each as <dir>/<name>.d2, and as .png through the d2 program.

def draw(+a: A.Architecture, +dir: String, vs: List<&2, Vw.Named>) -> IO(Unit):
  match vs:
    case []:
      IO.pure(Unit, Unit{})
    case v <> rest:
      match v:
        case Vw.Named{+name, view}:
          do IO<Unit>:
            X.write(dir ++ "/" ++ name ++ ".d2", VO.d2(a, view))
            ok : Bool <- X.succeeds("d2", ["--layout", "elk", "--pad", "40", dir ++ "/" ++ name ++ ".d2", dir ++ "/" ++ name ++ ".png"])
            IO.print(name ++ ": " ++ Bool.pick(String, ok, "drawn", "d2 failed"))
            draw(a, dir, rest)

def render(+a: A.Architecture, +dir: String, vs: List<&2, Vw.Named>) -> IO(Unit):
  do IO<Unit>:
    _ : Result<&1, &1, U32 & String, Unit> <- Fs.mkdir(dir)
    draw(a, dir, vs)
