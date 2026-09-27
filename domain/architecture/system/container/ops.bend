import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ../../relationship/type.bend as Rel
import ../../category/type.bend as K
import ../../environment/external/type.bend as Ex
import ./type.bend as Ct
import ./component/type.bend as Co

# A container's stack against its repository: the frameworks and libraries it declares are its
# dependencies, its source files are in its declared languages, and it has the SDK of each model API
# it calls. What it lists as `migrating` may be absent.

def key_of(c: Ct.Container) -> String:
  match c:
    case Ct.Container{k, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      k

def source_of(c: Ct.Container) -> String:
  match c:
    case Ct.Container{_, _, _, _, _, _, _, s, _, _, _, _, _, _, _}:
      s

# Every built container's source folder.
def sources(cs: List<&2, Ct.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      source_of(c) <> sources(rest)

# The other source folders: every one but this container's own, and not the repository's root.
def other_sources(+mine: String, ss: List<&2, String>) -> List<&2, String>:
  match ss:
    case []:
      []
    case +s <> rest:
      +more = other_sources(mine, rest)
      Bool.pick(List<&2, String>, String.eq(s, mine) || String.eq(s, ".") || String.is_empty(s), more, s <> more)

def under_any(+f: String, ds: List<&2, String>) -> Bool:
  match ds:
    case []:
      False{}
    case d <> rest:
      String.starts_with(f, d ++ "/") || under_any(f, rest)

def keep_built(+c: Ct.Container, +rest: List<&2, Ct.Container>) -> List<&2, Ct.Container>:
  Bool.pick(List<&2, Ct.Container>, String.is_empty(source_of(c)), rest, c <> rest)

# The containers built from this repository: those with a source folder.
def built(cs: List<&2, Ct.Container>) -> List<&2, Ct.Container>:
  match cs:
    case []:
      []
    case c <> rest:
      keep_built(c, built(rest))

# ---- names ----
# Declared names are readable names; dependencies are package names.
def package_name(+name: String) -> String:
  Bool.pick(String, String.eq(name, "Next.js"), "next",
  Bool.pick(String, String.eq(name, "Tailwind CSS"), "tailwindcss",
  Bool.pick(String, String.eq(name, "React"), "react",
  Bool.pick(String, String.eq(name, "Convex"), "convex",
  Bool.pick(String, String.eq(name, "OpenRouter SDK"), "@openrouter/sdk",
  Bool.pick(String, String.eq(name, "Sentry SDK"), "@sentry/nextjs",
  Bool.pick(String, String.eq(name, "Claude Agent SDK"), "@anthropic-ai/claude-agent-sdk",
  Bool.pick(String, String.eq(name, "whatsmeow"), "go.mau.fi/whatsmeow", name))))))))

# Whether a language is written in files with this extension.
def language_extension(+name: String, +ext: String) -> Bool:
  (String.eq(name, "TypeScript") && (String.eq(ext, ".ts") || String.eq(ext, ".tsx"))) ||
  (String.eq(name, "Go") && String.eq(ext, ".go")) ||
  (String.eq(name, "JavaScript") && (String.eq(ext, ".js") || String.eq(ext, ".mjs") || String.eq(ext, ".jsx"))) ||
  (String.eq(name, "Python") && String.eq(ext, ".py")) ||
  (String.eq(name, "Bend") && String.eq(ext, ".bend")) ||
  (String.eq(name, "C") && (String.eq(ext, ".c") || String.eq(ext, ".h")))

def any_language(+ext: String, xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      False{}
    case name <> rest:
      language_extension(name, ext) || any_language(ext, rest)

# The extensions of every language V knows; files with other extensions are not source.
def known(+ext: String) -> Bool:
  any_language(ext, ["TypeScript", "Go", "JavaScript", "Python", "Bend", "C"])

# ---- what is missing ----
# The declared names that are neither dependencies nor migrating.
def absent(xs: List<&2, String>, +deps: List<&2, String>, +migrating: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      +more = absent(rest, deps, migrating)
      Bool.pick(List<&2, String>, List.contains(~String, ~String.eq, deps, package_name(x)) || List.contains(~String, ~String.eq, migrating, x), more, x <> more)

# The frameworks and libraries a built container declares but does not depend on.
def stack_missing(c: Ct.Container, +deps: List<&2, String>) -> List<&2, String>:
  match c:
    case Ct.Container{_, _, _, _, _, _, _, source, _, fs, ls, _, +ms, _, _}:
      Bool.pick(List<&2, String>, String.is_empty(source), [], absent(List.append(&2, String, fs, ls), deps, ms))

# The extensions in a built container's source that no declared or migrating language is written in,
# and that are not themselves migrating.
def unwritten(xs: List<&2, String>, +languages: List<&2, String>, +migrating: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      +more = unwritten(rest, languages, migrating)
      Bool.pick(List<&2, String>, any_language(x, languages) || any_language(x, migrating) || List.contains(~String, ~String.eq, migrating, x), more, x <> more)

def languages_missing(c: Ct.Container, +extensions: List<&2, String>) -> List<&2, String>:
  match c:
    case Ct.Container{_, _, _, _, _, _, _, source, _, _, _, langs, +ms, _, _}:
      Bool.pick(List<&2, String>, String.is_empty(source), [], unwritten(extensions, langs, ms))

# ---- the SDK of each model API a container calls ----
def destinations(rs: List<&2, Rel.Relationship>) -> List<&2, String>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case Rel.Relationship{d, _, _, _}:
          d <> destinations(rest)

def component_destinations(cos: List<&2, Co.Component>) -> List<&2, String>:
  match cos:
    case []:
      []
    case co <> rest:
      match co:
        case Co.Component{_, _, _, _, us}:
          List.append(&2, String, destinations(us), component_destinations(rest))

def model_libraries(cat: K.Category, ls: List<&2, String>) -> List<&2, String>:
  match cat:
    case K.ModelApi{}:
      ls
    case _:
      []

# The SDK of the model API with this key, among the externals.
def sdk_of(+dest: String, xs: List<&2, Ex.External>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case Ex.External{k, _, _, cat, _, _, ls, _}:
          List.append(&2, String, Bool.pick(List<&2, String>, String.eq(k, dest), model_libraries(cat, ls), []), sdk_of(dest, rest))

def sdks(ds: List<&2, String>, +xs: List<&2, Ex.External>) -> List<&2, String>:
  match ds:
    case []:
      []
    case d <> rest:
      List.append(&2, String, sdk_of(d, xs), sdks(rest, xs))

# The SDK libraries of the model APIs a built container (or one of its components) calls that it does
# not depend on.
def sdk_missing(c: Ct.Container, +xs: List<&2, Ex.External>, +deps: List<&2, String>) -> List<&2, String>:
  match c:
    case Ct.Container{_, _, _, _, _, _, _, source, _, _, _, _, +ms, cos, us}:
      Bool.pick(List<&2, String>, String.is_empty(source), [],
        absent(Set.to_list(Set.from_list(sdks(List.append(&2, String, destinations(us), component_destinations(cos)), xs))), deps, ms))

# ---- reading the repository's evidence ----
def filled(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      +more = filled(rest)
      Bool.pick(List<&2, String>, String.is_empty(x) || String.eq(x, "."), more, x <> more)

def nth(+xs: List<&2, String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, n), "")

def last(+xs: List<&2, String>) -> String:
  Maybe.default(&2, String, List.head(&2, String, List.reverse(&2, String, xs)), "")

def prefixes(segs: List<&2, String>, +acc: String) -> List<&2, String>:
  match segs:
    case []:
      [acc]
    case +s <> rest:
      acc <> prefixes(rest, Bool.pick(String, String.is_empty(acc), s, acc ++ "/" ++ s))

# A folder and each folder above it, nearest first, ending with the repository root ("").
def folders(+dir: String) -> List<&2, String>:
  List.reverse(&2, String, prefixes(filled(String.split(dir, '/')), ""))

def json_or_null(m: Maybe<&2, Json.Val>) -> Json.Val:
  match m:
    case None{}:
      Json.Null{}
    case Some{v}:
      v

def keys(v: Maybe<&2, Json.Val>) -> List<&2, String>:
  match v:
    case Some{Json.Obj{m}}:
      Map.keys(&2, Json.Val, m)
    case _:
      []

# A package.json's dependencies and devDependencies.
def package_deps(+text: String) -> List<&2, String>:
  +v = json_or_null(Json.parse(text))
  List.append(&2, String, keys(Json.get(v, "dependencies")), keys(Json.get(v, "devDependencies")))

# The module a go.mod line requires, or "".
def module_name(+line: String) -> String:
  +words = filled(String.split(String.join(String.split(String.trim(line), '\t'), " "), ' '))
  +first = nth(words, 0n)
  +second = nth(words, 1n)
  Bool.pick(String, String.eq(first, "require") && String.starts_with(nth(words, 2n), "v"), second,
    Bool.pick(String, String.starts_with(second, "v") && Bool.not(String.eq(first, "module")), first, ""))

def go_deps(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      +more = go_deps(rest)
      Bool.pick(List<&2, String>, String.is_empty(module_name(l)), more, module_name(l) <> more)

# The source extension of a repository path, or "" when it is not source: generated files, and files
# under node_modules, _generated or .next.
def source_ext(+path: String) -> String:
  +parts = String.split(path, '/')
  +name = last(parts)
  +ext = "." ++ last(String.split(name, '.'))
  Bool.pick(String, String.contains(name, ".") && Bool.not(String.contains(name, ".generated.")) && known(ext) &&
    Bool.not(List.contains(~String, ~String.eq, parts, "node_modules") || List.contains(~String, ~String.eq, parts, "_generated") || List.contains(~String, ~String.eq, parts, ".next")),
    ext, "")

def source_exts(paths: List<&2, String>) -> List<&2, String>:
  match paths:
    case []:
      []
    case +p <> rest:
      +more = source_exts(rest)
      Bool.pick(List<&2, String>, String.is_empty(source_ext(p)), more, source_ext(p) <> more)

# The distinct source extensions among repository paths.
def source_extensions(paths: List<&2, String>) -> List<&2, String>:
  Set.to_list(Set.from_list(source_exts(paths)))
