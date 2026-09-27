import Base
import ../effs/io.bend as X
import ../plan/type.bend as P
import ../../environment/external/type.bend as Ex
import ./type.bend as Ct
import ./ops.bend as O

# Each built container's stack against the repository at `root`: its dependencies (the nearest
# package.json at or above its source folder, the root go.mod, and shadcn/ui when components.json sits
# beside that package.json) and the extensions of its source files, less those in another container's
# folder inside its own.

def under(+root: String, +dir: String, +file: String) -> String:
  Bool.pick(String, String.is_empty(dir), root ++ "/" ++ file, root ++ "/" ++ dir ++ "/" ++ file)

# The first of these folders with a package.json, or "" (the root).
def package_dir(dirs: List<&2, String>, +root: String) -> IO(String):
  match dirs:
    case []:
      IO.pure(String, "")
    case +d <> rest:
      do IO<String>:
        text : String <- X.read(under(root, d, "package.json"))
        later : String <- package_dir(rest, root)
        return Bool.pick(String, String.is_empty(String.trim(text)), later, d)

def dependencies(+root: String, +source: String, +go: List<&2, String>) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +dir : String <- package_dir(O.folders(source), root)
    package : String <- X.read(under(root, dir, "package.json"))
    components : String <- X.read(under(root, dir, "components.json"))
    return List.append(&2, String, O.package_deps(package),
      List.append(&2, String, go, Bool.pick(List<&2, String>, String.is_empty(String.trim(components)), [], ["shadcn/ui"])))

def outside(fs: List<&2, String>, +others: List<&2, String>) -> List<&2, String>:
  match fs:
    case []:
      []
    case +f <> rest:
      +more = outside(rest, others)
      Bool.pick(List<&2, String>, O.under_any(f, others), more, f <> more)

def extensions(+root: String, +source: String, +others: List<&2, String>) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    out : String <- X.run("git", ["-C", root, "ls-files", "-co", "--exclude-standard", "--", source])
    return O.source_extensions(outside(X.nonempty(String.lines(out)), others))

def blocked(+what: String, xs: List<&2, String>, +why: String) -> List<&2, P.Step>:
  match xs:
    case []:
      []
    case x <> rest:
      P.Blocked{what, x ++ why} <> blocked(what, rest, why)

def or_current(+what: String, bs: List<&2, P.Step>) -> List<&2, P.Step>:
  match bs:
    case []:
      [P.Current{what}]
    case b <> rest:
      b <> rest

def check(+c: Ct.Container, +root: String, +xs: List<&2, Ex.External>, +go: List<&2, String>, +others: List<&2, String>) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    +deps : List<&2, String> <- dependencies(root, O.source_of(c), go)
    exts : List<&2, String> <- extensions(root, O.source_of(c), O.other_sources(O.source_of(c), others))
    +what : String = "stack " ++ O.key_of(c)
    return or_current(what, List.append(&2, P.Step, blocked(what, O.stack_missing(c, deps), " is declared but not a dependency"),
      List.append(&2, P.Step, blocked(what, O.languages_missing(c, exts), " files have no declared language"),
        blocked(what, O.sdk_missing(c, xs, deps), " is the SDK of a model API it calls but not a dependency"))))

def checks_with(cs: List<&2, Ct.Container>, +root: String, +xs: List<&2, Ex.External>, +go: List<&2, String>, +others: List<&2, String>) -> IO(List<&2, P.Step>):
  match cs:
    case []:
      IO.pure(List<&2, P.Step>, [])
    case c <> rest:
      do IO<List<&2, P.Step>>:
        one : List<&2, P.Step> <- check(c, root, xs, go, others)
        more : List<&2, P.Step> <- checks_with(rest, root, xs, go, others)
        return List.append(&2, P.Step, one, more)

# The stack of every container built from the repository at `root`.
def checks(+root: String, +cs: List<&2, Ct.Container>, +xs: List<&2, Ex.External>) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    mod : String <- X.read(root ++ "/go.mod")
    checks_with(O.built(cs), root, xs, O.go_deps(String.lines(mod)), O.sources(O.built(cs)))
