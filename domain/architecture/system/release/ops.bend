import Base
import ./type.bend as Rl

# ---- the hub's rules: a name is 12 to 64 characters of a-z, 0-9 and -; a version is four numbers ----
def digits_only(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case c <> rest:
      Char.is_digit(c) && digits_only(rest)

def all_numbers(xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case +x <> rest:
      Bool.not(String.is_empty(x)) && digits_only(String.to_list(x)) && all_numbers(rest)

def name_chars(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case +c <> rest:
      (Char.is_lower(c) || Char.is_digit(c) || Char.is_eq(c, '-')) && name_chars(rest)

def package_ok(p: Rl.Package) -> Bool:
  match p:
    case Rl.Package{+n, +v, _, _}:
      Nat.is_ge(String.length(n), 12n) && Nat.is_le(String.length(n), 64n) && name_chars(String.to_list(n)) &&
      Nat.is_eq(List.length(&2, String, String.split(v, '.')), 4n) && all_numbers(String.split(v, '.'))

def packages_ok(ps: List<&2, Rl.Package>) -> Bool:
  match ps:
    case []:
      True{}
    case p <> rest:
      package_ok(p) && packages_ok(rest)

def packages(r: Rl.Release) -> List<&2, Rl.Package>:
  match r:
    case Rl.Release{_, ps}:
      ps

def repository(r: Rl.Release) -> Rl.Repository:
  match r:
    case Rl.Release{repo, _}:
      repo

def is_public(r: Rl.Release) -> Bool:
  match r:
    case Rl.Release{repo, _}:
      match repo:
        case Rl.Repository{_, p}:
          p

# Every component any package ships.
def shipped_components(ps: List<&2, Rl.Package>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case Rl.Package{_, _, _, cs}:
          List.append(&2, String, cs, shipped_components(rest))

# Every package's entry file.
def entries(ps: List<&2, Rl.Package>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case Rl.Package{_, _, e, _}:
          e <> entries(rest)

# ---- the repository: Bend only, and no dead code ----
# Bend, or a foreign effect in C or JavaScript (Bend's two lanes).
def is_source(+f: String) -> Bool:
  String.ends_with(f, ".bend") || String.ends_with(f, ".c") || String.ends_with(f, ".js")

def base_name(f: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, List.reverse(&2, String, String.split(f, '/'))), "")

# A file that is neither Bend source nor an effect: only licenses, the readme and the ignore list may be.
def allowed(+f: String) -> Bool:
  is_source(f) || String.eq(base_name(f), "LICENSE") || String.eq(f, "README.md") || String.eq(f, ".gitignore")

def bend_only(fs: List<&2, String>) -> Bool:
  match fs:
    case []:
      True{}
    case +f <> rest:
      allowed(f) && bend_only(rest)

# Every source file is reachable from an entry: a package's, or the system's own.
def no_dead_code(fs: List<&2, String>, +reached: List<&2, String>) -> Bool:
  match fs:
    case []:
      True{}
    case +f <> rest:
      (Bool.not(is_source(f)) || List.contains(~String, ~String.eq, reached, f)) && no_dead_code(rest, reached)

# The first source file nothing reaches, "" when there is none.
def dead(fs: List<&2, String>, +reached: List<&2, String>) -> String:
  match fs:
    case []:
      ""
    case +f <> rest:
      Bool.pick(String, is_source(f) && Bool.not(List.contains(~String, ~String.eq, reached, f)), f, dead(rest, reached))

# The first file that is not Bend, "" when there is none.
def not_bend(fs: List<&2, String>) -> String:
  match fs:
    case []:
      ""
    case +f <> rest:
      Bool.pick(String, allowed(f), not_bend(rest), f)
