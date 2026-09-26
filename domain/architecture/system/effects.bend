import Base
import bend-kit-files@0.1.0.0/files.bend as Fs
import ./release/type.bend as Rl
import ./release/ops.bend as RlO
import ./plan/type.bend as P
import ./plan/ops.bend as PO

# The system's effects: reading the repository, the Bend hub and GitHub (a snapshot of the world), and
# changing them (a deploy). Programs run with their arguments, never through a shell; files are read with
# Base's File API.

# ---- running a program ----
# Temporary: bend-kit-process does this, but no Bend version runs both it (2.0.27 only) and bend-kit-files (2.0.28+).
def Program.run(cmd: String, args: String) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/program_run.c"
  import "./effs/program_run.js"

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

def read(path: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_opened(r)

# ---- the repository's files ----
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

def files(+root: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    out : String <- run("git", ["-C", root, "ls-files", "-co", "--exclude-standard"])
    return nonempty(String.lines(out))

# ---- what an entry reaches: it and every file it imports, followed in Bend ----
def second_word(+t: String) -> String:
  Maybe.default(&2, String, List.get(&2, String, nonempty(String.split(t, ' ')), 1n), "")

def unquote(+w: String) -> String:
  Bool.pick(String, String.starts_with(w, "\""), Maybe.default(&2, String, List.get(&2, String, String.split(w, '"'), 1n), ""), w)

# The file a line imports, relative to the repository, or "" when it imports none of the repository's.
def import_of(+line: String, +dir: String) -> String:
  +w = unquote(second_word(String.trim(line)))
  Bool.pick(String, String.starts_with(String.trim(line), "import ") && (String.starts_with(w, "./") || String.starts_with(w, "../")),
    Fs.path.normalize(Fs.path.join(dir, w)), "")

def imports(ls: List<&2, String>, +dir: String) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      nonempty(import_of(l, dir) <> imports(rest, dir))

# Each step reads one file; the number of files squared bounds the walk.
def reach(fuel: Nat, +todo: List<&2, String>, +seen: List<&2, String>, +root: String) -> IO(List<&2, String>):
  match fuel:
    case 0n:
      IO.pure(List<&2, String>, seen)
    case 1n+k:
      match todo:
        case []:
          IO.pure(List<&2, String>, seen)
        case +f <> rest:
          do IO<List<&2, String>>:
            text : String <- read(root ++ "/" ++ f)
            +known : Bool = List.contains(~String, ~String.eq, seen, f)
            reach(k, List.append(&2, String, rest, Bool.pick(List<&2, String>, known, [], imports(String.lines(text), Fs.path.parent(f)))), Bool.pick(List<&2, String>, known, seen, f <> seen), root)

# ---- the Bend hub: has it published this package, with these exact files? ----
def differing(fs: List<&2, String>, +local: String, +hub: String) -> IO(String):
  match fs:
    case []:
      IO.pure(String, "")
    case +f <> rest:
      do IO<String>:
        mine : String <- read(local ++ "/" ++ f)
        theirs : String <- read(hub ++ "/" ++ f)
        more : String <- differing(rest, local, hub)
        return Bool.pick(String, String.eq(mine, theirs), more, f)

def hub_of(+published: String, +f: String) -> P.Hub:
  Bool.pick(P.Hub, String.is_empty(published), P.Unpublished{}, Bool.pick(P.Hub, String.is_empty(f), P.Same{}, P.Differs{f}))

def hub_state(+home: String, +root: String, p: Rl.Package) -> IO(P.Hub):
  match p:
    case Rl.Package{n, v, +e, _}:
      do IO<P.Hub>:
        +hash : String <- read(home ++ "/.bend/lib/names/" ++ n ++ "@" ++ v)
        +files : List<&2, String> <- reach(1000n, [e], [], root)
        f : String <- differing(files, root, home ++ "/.bend/lib/" ++ String.trim(hash))
        return hub_of(String.trim(hash), f)

def hub_states(+home: String, +root: String, ps: List<&2, Rl.Package>) -> IO(List<&2, P.Hub>):
  match ps:
    case []:
      IO.pure(List<&2, P.Hub>, [])
    case p <> rest:
      do IO<List<&2, P.Hub>>:
        h : P.Hub <- hub_state(home, root, p)
        hs : List<&2, P.Hub> <- hub_states(home, root, rest)
        return h <> hs

# ---- GitHub ----
def first_word(+t: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, nonempty(String.split(t, '\t'))), "")

def pushed(+root: String, +sha: String) -> IO(Bool):
  Bool.pick(IO(Bool), String.is_empty(sha), IO.pure(Bool, False{}), succeeds("git", ["-C", root, "merge-base", "--is-ancestor", "HEAD", sha]))

def remote(+root: String, r: Rl.Repository) -> IO(P.Remote):
  match r:
    case Rl.Repository{+name, _}:
      do IO<P.Remote>:
        origin : String <- run("git", ["-C", root, "remote", "get-url", "origin"])
        vis : String <- run("gh", ["repo", "view", name, "--json", "visibility", "--jq", ".visibility"])
        status : String <- run("git", ["-C", root, "status", "--porcelain"])
        head : String <- run("git", ["-C", root, "ls-remote", "origin", "refs/heads/main"])
        up : Bool <- pushed(root, first_word(head))
        return P.Remote{String.trim(origin), String.to_lower(String.trim(vis)), String.is_empty(String.trim(status)), up}

# ---- a snapshot: everything a plan needs ----
def root() -> IO(String):
  do IO<String>:
    t : String <- run("git", ["rev-parse", "--show-toplevel"])
    return String.trim(t)

# The files, what the packages' entries and the system's own entry reach, the hub, and GitHub.
def observe(+root: String, +entry: String, r: Rl.Release) -> IO(P.Observed):
  match r:
    case Rl.Release{repo, +ps}:
      do IO<P.Observed>:
        +h : String <- home()
        +fs : List<&2, String> <- files(root)
        reached : List<&2, String> <- reach(Nat.mul(1n+List.length(&2, String, fs), 1n+List.length(&2, String, fs)), entry <> RlO.entries(ps), [], root)
        hs : List<&2, P.Hub> <- hub_states(h, root, ps)
        rm : P.Remote <- remote(root, repo)
        return P.Observed{fs, reached, hs, rm}

# ---- a deploy: carry out a plan with nothing blocked ----
def apply(+root: String, +bend: String, s: P.Step) -> IO(Unit):
  match s:
    case P.Current{_}:
      IO.print(PO.show(s))
    case P.Publish{+n, +v, +e}:
      do IO<Unit>:
        out : String <- run(bend, [root ++ "/" ++ e, "--publish", n ++ "@" ++ v])
        IO.print(Bool.pick(String, String.contains(out, "published"), "published " ++ n ++ "@" ++ v, "failed   publish " ++ n ++ "@" ++ v))
    case P.Push{+r}:
      do IO<Unit>:
        ok : Bool <- succeeds("git", ["-C", root, "push", "-q", "origin", "HEAD:main"])
        IO.print(Bool.pick(String, ok, "pushed   github " ++ r, "failed   push github " ++ r))
    case P.Blocked{_, _}:
      IO.print(PO.show(s))

def apply_all(+root: String, +bend: String, ss: List<&2, P.Step>) -> IO(Unit):
  match ss:
    case []:
      IO.pure(Unit, Unit{})
    case s <> rest:
      do IO<Unit>:
        apply(root, bend, s)
        apply_all(root, bend, rest)

def deploy_if(blocked: Bool, +root: String, +ss: List<&2, P.Step>) -> IO(Unit):
  match blocked:
    case True{}:
      IO.die(Unit, 1, PO.show_all(ss) ++ "nothing deployed: the plan is blocked")
    case False{}:
      do IO<Unit>:
        +h : String <- home()
        apply_all(root, h ++ "/.bend/bin/bend", ss)

def deploy(+root: String, +ss: List<&2, P.Step>) -> IO(Unit):
  deploy_if(PO.any_blocked(ss), root, ss)
