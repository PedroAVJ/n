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
    case Rl.Release{_, ps, _}:
      ps

def plugins(r: Rl.Release) -> List<&2, Rl.Plugin>:
  match r:
    case Rl.Release{_, _, gs}:
      gs

def repository(r: Rl.Release) -> Rl.Repository:
  match r:
    case Rl.Release{repo, _, _}:
      repo

def is_public(r: Rl.Release) -> Bool:
  match r:
    case Rl.Release{repo, _, _}:
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

# Every plugin's entry file.
def plugin_entries(gs: List<&2, Rl.Plugin>) -> List<&2, String>:
  match gs:
    case []:
      []
    case g <> rest:
      match g:
        case Rl.Plugin{_, _, e, _, _}:
          e <> plugin_entries(rest)

# Every component any plugin ships.
def plugin_components(gs: List<&2, Rl.Plugin>) -> List<&2, String>:
  match gs:
    case []:
      []
    case g <> rest:
      match g:
        case Rl.Plugin{_, _, _, cs, _}:
          List.append(&2, String, cs, plugin_components(rest))

# ---- the repository: Bend only, and no dead code ----
# Bend, or a foreign effect in C or JavaScript (Bend's two lanes).
def is_source(+f: String) -> Bool:
  String.ends_with(f, ".bend") || String.ends_with(f, ".c") || String.ends_with(f, ".js")

def base_name(f: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, List.reverse(&2, String, String.split(f, '/'))), "")

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
# ---- the hub's path rule: every segment is [A-Za-z_][A-Za-z0-9_]* (the file name also ends in .bend, .c or
# .js, or is a LICENSE), under 256 characters ----
def name_char(+c: Char, first: Bool) -> Bool:
  Char.is_lower(c) || Char.is_upper(c) || Char.is_eq(c, '_') || (Bool.not(first) && Char.is_digit(c))

def name_chars_ok(cs: List<&2, Char>, first: Bool) -> Bool:
  match cs:
    case []:
      Bool.not(first)
    case +c <> rest:
      name_char(c, first) && name_chars_ok(rest, False{})

def stem(+f: String) -> String:
  Bool.pick(String, String.ends_with(f, ".bend"), String.take(f, Nat.sub(String.length(f), 5n)),
    Bool.pick(String, String.ends_with(f, ".js"), String.take(f, Nat.sub(String.length(f), 3n)),
      Bool.pick(String, String.ends_with(f, ".c"), String.take(f, Nat.sub(String.length(f), 2n)), f)))

def segments_ok(ss: List<&2, String>) -> Bool:
  match ss:
    case []:
      True{}
    case +s <> rest:
      match rest:
        case []:
          String.eq(s, "LICENSE") || (is_source(s) && name_chars_ok(String.to_list(stem(s)), True{}))
        case _ <> _:
          name_chars_ok(String.to_list(s), True{}) && segments_ok(rest)

def hub_path_ok(+f: String) -> Bool:
  Nat.is_lt(String.length(f), 256n) && segments_ok(String.split(f, '/'))

# The first file the hub would refuse, "" when there is none.
def hub_refused(fs: List<&2, String>) -> String:
  match fs:
    case []:
      ""
    case +f <> rest:
      Bool.pick(String, hub_path_ok(f), hub_refused(rest), f)
