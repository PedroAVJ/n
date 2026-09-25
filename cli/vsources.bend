import Base
import ../lib/effs/io.bend as X
import ../lib/vstr.bend as S
import ./project.bend as P

# The repository's files and what its packages ship, read in Bend for the no-dead-code and Bend-only
# laws. Listing the files is the one command it runs (`git ls-files`); every file is read with Bend's
# File API and every import is followed in Bend.

# ---- reading a file ----
def size_of(r: Result<&1, &1, U32 & String, U32>) -> U32:
  match r:
    case Done{n}:
      n
    case Fail{_}:
      0

def read_done(r: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  match r:
    case (f, got):
      do IO<String>:
        File.close(f)
        return X.out_of(got)

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

def read_file(path: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_opened(r)

# ---- paths ----
def choose(c: Bool, a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      a
    case False{}:
      b

def can_pop(xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      False{}
    case +h <> _:
      Bool.not(String.eq(h, ".."))

def tail_of(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case _ <> t:
      t

def norm_step(+seg: String, +stack: List<&2, String>) -> List<&2, String>:
  choose(String.eq(seg, "") || String.eq(seg, "."), stack, choose(String.eq(seg, "..") && can_pop(stack), tail_of(stack), seg <> stack))

def norm_go(segs: List<&2, String>, +stack: List<&2, String>) -> List<&2, String>:
  match segs:
    case []:
      stack
    case +s <> rest:
      norm_go(rest, norm_step(s, stack))

# A path with "." and ".." resolved.
def norm(p: String) -> String:
  String.join(List.reverse(&2, String, norm_go(String.split(p, '/'), [])), "/")

def dir_of(p: String) -> String:
  String.join(List.reverse(&2, String, tail_of(List.reverse(&2, String, String.split(p, '/')))), "/")

# ---- imports ----
def unquote(+w: String) -> String:
  S.pick(String.starts_with(w, "\""), S.nth(String.split(w, '"'), 1n), w)

def import_of(+t: String) -> String:
  S.pick(String.starts_with(t, "import "), unquote(S.nth(S.words(t), 1n)), "")

def relative(+p: String) -> Bool:
  String.starts_with(p, "./") || String.starts_with(p, "../")

def keep_import(+p: String, +dir: String, +rest: List<&2, String>) -> List<&2, String>:
  choose(relative(p), norm(dir ++ "/" ++ p) <> rest, rest)

# The repository files a file imports (Bend modules and C effects), relative to the repository.
def imports_of(ls: List<&2, String>, +dir: String) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      keep_import(import_of(String.trim(l)), dir, imports_of(rest, dir))

# ---- what the packages ship: each entry and everything it imports ----
# Each step handles one import, repeats included; files squared bounds them.
def seen_in(+x: String, ys: List<&2, String>) -> Bool:
  match ys:
    case []:
      False{}
    case y <> rest:
      String.eq(x, y) || seen_in(x, rest)

def ship(fuel: Nat, +todo: List<&2, String>, +seen: List<&2, String>, +root: String) -> IO(List<&2, String>):
  match fuel:
    case 0n:
      IO.pure(List<&2, String>, seen)
    case 1n+k:
      match todo:
        case []:
          IO.pure(List<&2, String>, seen)
        case +f <> rest:
          do IO<List<&2, String>>:
            text : String <- read_file(root ++ "/" ++ f)
            +known : Bool = seen_in(f, seen)
            ship(k, S.append(rest, choose(known, [], imports_of(String.lines(text), dir_of(f)))), choose(known, seen, S.append(seen, [f])), root)

def entries(ps: List<&2, String>, +project: String) -> List<&2, String>:
  match ps:
    case []:
      []
    case +p <> rest:
      norm(project ++ "/" ++ S.nth(S.words(p), 2n)) <> entries(rest, project)

def list_text(xs: List<&2, String>) -> String:
  "[" ++ S.quote_all(xs) ++ "]"

def sources_text(+vlib: String, +files: List<&2, String>, +project: String, +shipped: List<&2, String>) -> String:
  "import Base\n\n# The repository's files, this project's folder and the files its packages ship, for the\n# no-dead-code and Bend-only laws. Written by `v system check`; do not edit.\n" ++
  "def all_files() -> List<&2, String>:\n  " ++ list_text(files) ++ "\n\n" ++
  "def project() -> String:\n  \"" ++ project ++ "\"\n\n" ++
  "def shipped() -> List<&2, String>:\n  " ++ list_text(shipped) ++ "\n"

def write_sources(+f: P.Facts) -> IO(Unit):
  do IO<Unit>:
    +root : String <- X.sh("git rev-parse --show-toplevel")
    +here : String <- X.sh("pwd")
    +listing : String <- X.sh("git -C '" ++ String.trim(root) ++ "' ls-files -co --exclude-standard")
    +files : List<&2, String> = S.nonempty(String.lines(listing))
    +project : String = String.drop(String.trim(here), Nat.add(1n, String.length(String.trim(root))))
    +steps : Nat = Nat.add(1n, List.length(&2, String, files))
    +shipped : List<&2, String> <- ship(Nat.mul(steps, steps), entries(P.packages_of(f), project), [], String.trim(root))
    X.write_file("sources.bend", sources_text(P.vlib_of(f), files, project, shipped))
