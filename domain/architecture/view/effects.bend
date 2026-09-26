import Base
import ../system/effects.bend as SE
import bend-kit-files@0.1.0.0/files.bend as Fs
import ../type.bend as A
import ./type.bend as Vw
import ./ops.bend as VO

# Drawing views to files: each as <dir>/<name>.d2, and as .png through the d2 program.

def after_write(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case (f, _):
      File.close(f)

def write_opened(r: Result<&1, &1, U32 & String, File>, text: String) -> IO(Unit):
  match r:
    case Done{f}:
      do IO<Unit>:
        w : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, text)
        after_write(w)
    case Fail{_}:
      IO.die(Unit, 1, "cannot write a drawing")

def write(path: String, text: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
    write_opened(r, text)


def draw(+a: A.Architecture, +dir: String, vs: List<&2, Vw.Named>) -> IO(Unit):
  match vs:
    case []:
      IO.pure(Unit, Unit{})
    case v <> rest:
      match v:
        case Vw.Named{+name, view}:
          do IO<Unit>:
            write(dir ++ "/" ++ name ++ ".d2", VO.d2(a, view))
            ok : Bool <- SE.succeeds("d2", ["--layout", "elk", "--pad", "40", dir ++ "/" ++ name ++ ".d2", dir ++ "/" ++ name ++ ".png"])
            IO.print(name ++ ": " ++ Bool.pick(String, ok, "drawn", "d2 failed"))
            draw(a, dir, rest)

def render(+a: A.Architecture, +dir: String, vs: List<&2, Vw.Named>) -> IO(Unit):
  do IO<Unit>:
    _ : Result<&1, &1, U32 & String, Unit> <- Fs.mkdir(dir)
    draw(a, dir, vs)
