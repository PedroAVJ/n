import Base
import ./mac.types.bend as T

# String and list helpers for V's command line (explicit recursion; Bend's generic ones take compile-time functions).

def not_empty_keep(e: Bool, s: String, rest: List<&2, String>) -> List<&2, String>:
  match e:
    case True{}:
      rest
    case False{}:
      s <> rest

def nonempty(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +s <> rest:
      not_empty_keep(String.is_empty(s), s, nonempty(rest))

def words(s: String) -> List<&2, String>:
  nonempty(String.split(s, ' '))

def nth(xs: List<&2, String>, n: Nat) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match n:
        case 0n:
          x
        case 1n+m:
          nth(rest, m)

def last(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match rest:
        case []:
          x
        case y <> more:
          last(y <> more)

def count(xs: List<&2, String>) -> Nat:
  List.length(&2, String, xs)

def digit_or_stop(d: Bool, c: Char, tail: String) -> String:
  match d:
    case True{}:
      String.from_list([c]) ++ tail
    case False{}:
      ""

def digits_of(cs: List<&2, Char>) -> String:
  match cs:
    case []:
      ""
    case +c <> rest:
      digit_or_stop(Char.is_digit(c), c, digits_of(rest))

def digits(s: String) -> String:
  digits_of(String.to_list(s))

def keep_new(dup: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match dup:
    case True{}:
      rest
    case False{}:
      x <> rest

def dedupe(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> +rest:
      keep_new(T.has(x, rest), x, dedupe(rest))

def append(a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  List.append(&2, String, a, b)

def quoted(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      ("\"" ++ x ++ "\"") <> quoted(rest)

def quote_all(xs: List<&2, String>) -> String:
  String.join(quoted(xs), ", ")

def join_lines(xs: List<&2, String>) -> String:
  String.join(xs, "\n")

# ---- escaping ----
def pick(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_esc(bs: Bool, q: Bool, c: Char) -> String:
  match bs:
    case True{}:
      "\\\\"
    case False{}:
      match q:
        case True{}:
          "\\\""
        case False{}:
          String.from_list([c])

def esc_char(+c: Char) -> String:
  pick_esc(Char.is_eq(c, '\\'), Char.is_eq(c, '"'), c)

def esc_chars(cs: List<&2, Char>) -> String:
  match cs:
    case []:
      ""
    case c <> rest:
      esc_char(c) ++ esc_chars(rest)

# Escape for a Bend string literal.
def esc(s: String) -> String:
  esc_chars(String.to_list(s))

def nix_esc_char(+c: Char) -> String:
  pick(Char.is_eq(c, '\\'), "\\\\", pick(Char.is_eq(c, '"'), "\\\"", pick(Char.is_eq(c, '\n'), "\\n", String.from_list([c]))))

def nix_esc_chars(cs: List<&2, Char>) -> String:
  match cs:
    case []:
      ""
    case c <> rest:
      nix_esc_char(c) ++ nix_esc_chars(rest)

# A string as a Nix string literal.
def nix_str(s: String) -> String:
  "\"" ++ nix_esc_chars(String.to_list(s)) ++ "\""

def nix_strs(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      " " ++ nix_str(x) ++ nix_strs(rest)

# A list of strings as a Nix list.
def nix_list(xs: List<&2, String>) -> String:
  "[" ++ nix_strs(xs) ++ " ]"

def setting_line(name: String, k: String, v: String) -> String:
  "    T.Setting{\"" ++ esc(name) ++ "\", T." ++ k ++ "{}, \"" ++ esc(v) ++ "\"}"

def line_if(keep: Bool, l: String) -> List<&2, String>:
  match keep:
    case True{}:
      [l]
    case False{}:
      []


# ---- plist values, as `defaults export` writes them (real characters, unlike `defaults read`) ----
def xml_entity(+seg: String) -> String:
  pick(String.starts_with(seg, "amp;"), "&" ++ String.drop(seg, 4n),
  pick(String.starts_with(seg, "lt;"), "<" ++ String.drop(seg, 3n),
  pick(String.starts_with(seg, "gt;"), ">" ++ String.drop(seg, 3n),
  pick(String.starts_with(seg, "quot;"), "\"" ++ String.drop(seg, 5n),
  pick(String.starts_with(seg, "apos;"), "'" ++ String.drop(seg, 5n), "&" ++ seg)))))

def xml_entities(segs: List<&2, String>) -> String:
  match segs:
    case []:
      ""
    case s <> rest:
      xml_entity(s) ++ xml_entities(rest)

def xml_unescape(+s: String) -> String:
  nth(String.split(s, '&'), 0n) ++ xml_entities(List.drop(&2, String, String.split(s, '&'), 1n))

# "<true/>" -> "1", "<false/>" -> "0", "<integer>3</integer>" -> "3", "<string>a &amp; b</string>" -> "a & b"; "" when unset.
def plist_scalar(+v: String) -> String:
  pick(String.starts_with(String.trim(v), "<true/>"), "1",
  pick(String.starts_with(String.trim(v), "<false/>"), "0",
       xml_unescape(nth(String.split(nth(String.split(v, '>'), 1n), '<'), 0n))))

# Shell: the XML value of top-level `key` in `defaults <args> export`-style output (args like "export -g", "-currentHost export com.apple.x").
def export_key(+args: String, +key: String) -> String:
  "defaults " ++ args ++ " - 2>/dev/null | awk -v k='<key>" ++ key ++ "</key>' 'f{s=s $0 \"\\n\"; if ($0 ~ /<\\/string>|<\\/integer>|<\\/real>|\\/>/) {printf \"%s\", s; exit}} $0==\"\\t\"k{f=1}'"
