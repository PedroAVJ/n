import Base

# V's I/O: running a program with its arguments (the effect below), and reading and writing files with
# Base's File API.

# ---- running a program ----
# Temporary: bend-kit-process does this, but no Bend version runs both it (2.0.27 only) and bend-kit-files (2.0.28+).
def Program.run(cmd: String, args: String) -> IO(Result<&1, &1, U32 & String, String>):
  import "./program_run.c"
  import "./program_run.js"

def out_of(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Done{out}:
      out
    case Fail{_}:
      ""

def ok_of(r: Result<&1, &1, U32 & String, String>) -> Bool:
  match r:
    case Done{_}:
      True{}
    case Fail{_}:
      False{}

# A program's standard output when it exits 0, else "".
def run(cmd: String, args: List<&2, String>) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, String> <- Program.run(cmd, String.join(args, "\u{1f}"))
    return out_of(r)

# Whether a program exits 0.
def succeeds(cmd: String, args: List<&2, String>) -> IO(Bool):
  do IO<Bool>:
    r : Result<&1, &1, U32 & String, String> <- Program.run(cmd, String.join(args, "\u{1f}"))
    return ok_of(r)

def home() -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env("HOME")
    return Result.default(&1, &1, U32 & String, String, r, "")

# ---- reading a file: its text, or "" when it cannot be read ----
def size_of(r: Result<&1, &1, U32 & String, U32>) -> U32:
  match r:
    case Done{n}:
      n
    case Fail{_}:
      0

def text_of(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Done{t}:
      t
    case Fail{_}:
      ""

def read_done(r: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  match r:
    case (f, got):
      do IO<String>:
        File.close(f)
        return text_of(got)

def read_sized(r: File & Result<&1, &1, U32 & String, U32>) -> IO(String):
  match r:
    case (f, n):
      do IO<String>:
        got : File & Result<&1, &1, U32 & String, String> <- File.read(f, size_of(n))
        read_done(got)

def read_opened(r: Result<&1, &1, U32 & String, File>) -> IO(String):
  match r:
    case Done{f}:
      do IO<String>:
        n : File & Result<&1, &1, U32 & String, U32> <- File.size(f)
        read_sized(n)
    case Fail{_}:
      IO.pure(String, "")

def read_head_opened(r: Result<&1, &1, U32 & String, File>, max: U32) -> IO(String):
  match r:
    case Done{f}:
      do IO<String>:
        got : File & Result<&1, &1, U32 & String, String> <- File.read(f, max)
        read_done(got)
    case Fail{_}:
      IO.pure(String, "")

# The first `max` bytes of a file ("" if unreadable): enough for what sits at its top, like imports.
def read_head(path: String, max: U32) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_head_opened(r, max)

def read(path: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_opened(r)

# ---- writing a file ----
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
      IO.die(Unit, 1, "cannot write a file")

def write(path: String, text: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
    write_opened(r, text)

def keep_filled(c: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      x <> rest
    case False{}:
      rest

# The trimmed, non-empty strings.
def nonempty(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      keep_filled(Bool.not(String.is_empty(String.trim(x))), String.trim(x), nonempty(rest))

