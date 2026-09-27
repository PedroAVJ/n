import Base
import ./type.bend as S

# A style as CSS: its declarations, its class name (from a hash of what it says), and its rules.

def length(l: S.Length) -> String:
  match l:
    case S.Px{n}:
      Nat.show(n) ++ "px"
    case S.Percent{n}:
      Nat.show(n) ++ "%"

def color(c: S.Color) -> String:
  match c:
    case S.Rgb{r, g, b}:
      "rgb(" ++ Nat.show(r) ++ "," ++ Nat.show(g) ++ "," ++ Nat.show(b) ++ ")"
    case S.Transparent{}:
      "transparent"

def decl(d: S.Decl) -> String:
  match d:
    case S.Padding{l}:
      "padding:" ++ length(l)
    case S.Margin{l}:
      "margin:" ++ length(l)
    case S.Gap{l}:
      "gap:" ++ length(l)
    case S.Background{c}:
      "background:" ++ color(c)
    case S.Foreground{c}:
      "color:" ++ color(c)
    case S.Border{w, c}:
      "border:" ++ length(w) ++ " solid " ++ color(c)
    case S.Radius{l}:
      "border-radius:" ++ length(l)
    case S.FontSize{l}:
      "font-size:" ++ length(l)
    case S.Family{f}:
      match f:
        case S.Sans{}:
          "font-family:ui-sans-serif,system-ui,-apple-system,sans-serif"
        case S.Mono{}:
          "font-family:ui-monospace,Menlo,monospace"
    case S.Weight{n}:
      "font-weight:" ++ Nat.show(n)
    case S.Width{l}:
      "width:" ++ length(l)
    case S.MaxWidth{l}:
      "max-width:" ++ length(l)
    case S.MinHeight{l}:
      "min-height:" ++ length(l)
    case S.Flex{dir}:
      match dir:
        case S.Row{}:
          "display:flex;flex-direction:row"
        case S.Column{}:
          "display:flex;flex-direction:column"
    case S.Centered{}:
      "margin-left:auto;margin-right:auto"
    case S.Pointer{}:
      "cursor:pointer"
    case S.Underline{c}:
      "text-decoration:underline wavy " ++ color(c)

def decls(ds: List<&2, S.Decl>) -> String:
  match ds:
    case []:
      ""
    case d <> rest:
      decl(d) ++ ";" ++ decls(rest)

def condition(c: S.Condition) -> String:
  match c:
    case S.Hover{}:
      "hover"
    case S.Focus{}:
      "focus"
    case S.Dark{}:
      "dark"
    case S.Below{l}:
      "below " ++ length(l)

def rules_text(rs: List<&2, S.Rule>) -> String:
  match rs:
    case []:
      ""
    case S.When{c, ds} <> rest:
      condition(c) ++ "{" ++ decls(ds) ++ "}" ++ rules_text(rest)

# ---- the class name: s, then eight hex digits of a djb2 hash of what the style says ----
def hash.go(cs: List<&2, Char>, +h: U32) -> U32:
  match cs:
    case []:
      h
    case c <> rest:
      hash.go(rest, (h * 33 + Char.to_u32(c) : U32))

def hex_digit(+n: U32) -> String:
  String.take(String.drop("0123456789abcdef", U32.to_nat(n)), 1n)

def hex.go(n: Nat, +x: U32) -> String:
  match n:
    case 0n:
      ""
    case 1n+k:
      hex.go(k, (x / 16 : U32)) ++ hex_digit((x % 16 : U32))

def name(s: S.Style) -> String:
  match s:
    case S.Style{ds, rs}:
      "s" ++ hex.go(8n, hash.go(String.to_list(decls(ds) ++ "|" ++ rules_text(rs)), 5381))

# ---- the CSS for one style ----
def rule(+cls: String, r: S.Rule) -> String:
  match r:
    case S.When{c, ds}:
      match c:
        case S.Hover{}:
          "." ++ cls ++ ":hover{" ++ decls(ds) ++ "}"
        case S.Focus{}:
          "." ++ cls ++ ":focus{" ++ decls(ds) ++ "}"
        case S.Dark{}:
          "@media (prefers-color-scheme: dark){." ++ cls ++ "{" ++ decls(ds) ++ "}}"
        case S.Below{l}:
          "@media (max-width: " ++ length(l) ++ "){." ++ cls ++ "{" ++ decls(ds) ++ "}}"

def rules(+cls: String, rs: List<&2, S.Rule>) -> String:
  match rs:
    case []:
      ""
    case r <> rest:
      rule(cls, r) ++ rules(cls, rest)

def css.of(+cls: String, s: S.Style) -> String:
  match s:
    case S.Style{ds, rs}:
      "." ++ cls ++ "{" ++ decls(ds) ++ "}" ++ rules(cls, rs)

def css(+s: S.Style) -> String:
  css.of(name(s), s)

# The stylesheet for a page's styles, each class once.
def sheet.go(ss: List<&2, S.Style>, +seen: List<&2, String>) -> String:
  match ss:
    case []:
      ""
    case +s <> +rest:
      +cls = name(s)
      Bool.pick(String, List.contains(~String, ~String.eq, seen, cls), sheet.go(rest, seen), css(s) ++ sheet.go(rest, cls <> seen))

def sheet(ss: List<&2, S.Style>) -> String:
  sheet.go(ss, [])
