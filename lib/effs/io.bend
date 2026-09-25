import Base

# V's I/O: run a program (a C effect, see proc_run.c) and write a file (Bend's File API).

def Proc.run(cmd: String) -> IO(Result<&1, &1, U32 & String, String>):
  import "./proc_run.c"

# Standard output of a command; "" if it failed.
def out_of(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Done{v}:
      v
    case Fail{_}:
      ""

def ok_of(r: Result<&1, &1, U32 & String, String>) -> Bool:
  match r:
    case Done{_}:
      True{}
    case Fail{_}:
      False{}

def sh(cmd: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, String> <- Proc.run(cmd)
    return out_of(r)

def ok(cmd: String) -> IO(Bool):
  do IO<Bool>:
    r : Result<&1, &1, U32 & String, String> <- Proc.run(cmd)
    return ok_of(r)

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
      IO.die(Unit, 1, "cannot write file")

def write_file(path: String, text: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
    write_opened(r, text)
