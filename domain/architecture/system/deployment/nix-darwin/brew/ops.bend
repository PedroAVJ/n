import Base
import ./type.bend as Br

# ---- string literals: Nix (mac.nix), Ruby (the Brewfile) and Bend (an imported settings file) ----
# One character of a double-quoted literal: backslash, quote and the language's `x` (Nix's $, Ruby's #)
# are escaped, and so is a newline.
def quote_char(+c: Char, +x: Char) -> String:
  Bool.pick(String, Char.is_eq(c, '\\') || Char.is_eq(c, '"') || Char.is_eq(c, x), "\\" ++ String.from_list([c]),
    Bool.pick(String, Char.is_eq(c, '\n'), "\\n", String.from_list([c])))

def quote_chars(cs: List<&2, Char>, +x: Char) -> String:
  match cs:
    case []:
      ""
    case c <> rest:
      quote_char(c, x) ++ quote_chars(rest, x)

# A string's characters as a Nix string literal writes them, without the quotes.
def nix_esc(s: String) -> String:
  quote_chars(String.to_list(s), '$')

def nix_str(s: String) -> String:
  "\"" ++ nix_esc(s) ++ "\""

def ruby_str(s: String) -> String:
  "\"" ++ quote_chars(String.to_list(s), '#') ++ "\""

def bend_str(s: String) -> String:
  "\"" ++ quote_chars(String.to_list(s), '"') ++ "\""

# ---- the Homebrew section of mac.nix: one list per kind; entries nix-darwin has no option for are raw
# Brewfile lines ----
def tap_nix(b: Br.Brew) -> String:
  match b:
    case Br.Tap{n}:
      " " ++ nix_str(n)
    case _:
      ""

def formula_nix(b: Br.Brew) -> String:
  match b:
    case Br.Formula{n}:
      " " ++ nix_str(n)
    case _:
      ""

def cask_nix(b: Br.Brew) -> String:
  match b:
    case Br.Cask{n}:
      " " ++ nix_str(n)
    case _:
      ""

def other_nix(b: Br.Brew) -> String:
  match b:
    case Br.Other{l}:
      "    " ++ l ++ "\n"
    case _:
      ""

def mas_name(b: Br.Brew) -> List<&2, String>:
  match b:
    case Br.Mas{n, _}:
      [n]
    case _:
      []

def mas_names(xs: List<&2, Br.Brew>) -> List<&2, String>:
  match xs:
    case []:
      []
    case b <> rest:
      List.append(&2, String, mas_name(b), mas_names(rest))

def occurrences(xs: List<&2, String>, +x: String) -> Nat:
  match xs:
    case []:
      0n
    case y <> rest:
      Nat.add(Bool.pick(Nat, String.eq(x, y), 1n, 0n), occurrences(rest, x))

# masApps is an attribute set: an app name the list repeats gets its id added.
def mas_nix(b: Br.Brew, +names: List<&2, String>) -> String:
  match b:
    case Br.Mas{+n, +id}:
      " " ++ nix_str(Bool.pick(String, Nat.is_gt(occurrences(names, n), 1n), n ++ " (" ++ id ++ ")", n)) ++ " = " ++ id ++ ";"
    case _:
      ""

# Part 0 taps, 1 masApps, 2 brews, 3 casks, 4 extraConfig.
def all_nix(xs: List<&2, Br.Brew>, +part: Nat, +names: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case +b <> rest:
      Bool.pick(String, Nat.is_eq(part, 0n), tap_nix(b),
        Bool.pick(String, Nat.is_eq(part, 1n), mas_nix(b, names),
          Bool.pick(String, Nat.is_eq(part, 2n), formula_nix(b),
            Bool.pick(String, Nat.is_eq(part, 3n), cask_nix(b), other_nix(b))))) ++ all_nix(rest, part, names)

def nix_section(+xs: List<&2, Br.Brew>) -> String:
  "  homebrew.taps = [" ++ all_nix(xs, 0n, []) ++ " ];\n" ++
  "  homebrew.masApps = {" ++ all_nix(xs, 1n, mas_names(xs)) ++ " };\n" ++
  "  homebrew.brews = [" ++ all_nix(xs, 2n, []) ++ " ];\n" ++
  "  homebrew.casks = [" ++ all_nix(xs, 3n, []) ++ " ];\n" ++
  "  homebrew.extraConfig = ''\n" ++ all_nix(xs, 4n, []) ++ "  '';\n"

# ---- the Brewfile, for brew bundle ----
def brewfile_line(b: Br.Brew) -> String:
  match b:
    case Br.Tap{n}:
      "tap " ++ ruby_str(n)
    case Br.Formula{n}:
      "brew " ++ ruby_str(n)
    case Br.Cask{n}:
      "cask " ++ ruby_str(n)
    case Br.Mas{n, id}:
      "mas " ++ ruby_str(n) ++ ", id: " ++ id
    case Br.Other{l}:
      l

def brewfile(xs: List<&2, Br.Brew>) -> String:
  match xs:
    case []:
      ""
    case b <> rest:
      brewfile_line(b) ++ "\n" ++ brewfile(rest)

# ---- reading a Brewfile (as `brew bundle dump` writes it): a line's options after the name are dropped,
# except a Mac App Store app's id ----
def digits_of(cs: List<&2, Char>) -> String:
  match cs:
    case []:
      ""
    case +c <> rest:
      Bool.pick(String, Char.is_digit(c), String.from_list([c]) ++ digits_of(rest), "")

# The digits after "id:", "" when there are none.
def mas_id(+l: String) -> String:
  digits_of(String.to_list(String.trim(Maybe.default(&2, String, List.get(&2, String, String.split(String.drop(l, 4n), ':'), 1n), ""))))

def entry_of(+kind: String, +name: String, +l: String) -> List<&2, Br.Brew>:
  Bool.pick(List<&2, Br.Brew>, String.is_empty(l) || String.starts_with(l, "#"), [],
    Bool.pick(List<&2, Br.Brew>, String.eq(kind, "tap"), [Br.Tap{name}],
      Bool.pick(List<&2, Br.Brew>, String.eq(kind, "brew"), [Br.Formula{name}],
        Bool.pick(List<&2, Br.Brew>, String.eq(kind, "cask"), [Br.Cask{name}],
          Bool.pick(List<&2, Br.Brew>, String.eq(kind, "mas"), [Br.Mas{name, mas_id(l)}], [Br.Other{l}])))))

def first_word(+l: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, String.split(l, ' ')), "")

def quoted_name(+l: String) -> String:
  Maybe.default(&2, String, List.get(&2, String, String.split(l, '"'), 1n), "")

def of_lines(ls: List<&2, String>) -> List<&2, Br.Brew>:
  match ls:
    case []:
      []
    case l <> rest:
      +t = String.trim(l)
      List.append(&2, Br.Brew, entry_of(first_word(t), quoted_name(t), t), of_lines(rest))

def of_brewfile(text: String) -> List<&2, Br.Brew>:
  of_lines(String.lines(text))

# ---- Bend source for a list of entries (an imported settings file names the types Br) ----
def bend_expr(b: Br.Brew) -> String:
  match b:
    case Br.Tap{n}:
      "Br.Tap{" ++ bend_str(n) ++ "}"
    case Br.Formula{n}:
      "Br.Formula{" ++ bend_str(n) ++ "}"
    case Br.Cask{n}:
      "Br.Cask{" ++ bend_str(n) ++ "}"
    case Br.Mas{n, id}:
      "Br.Mas{" ++ bend_str(n) ++ ", " ++ bend_str(id) ++ "}"
    case Br.Other{l}:
      "Br.Other{" ++ bend_str(l) ++ "}"

def bend_exprs(xs: List<&2, Br.Brew>) -> List<&2, String>:
  match xs:
    case []:
      []
    case b <> rest:
      ("    " ++ bend_expr(b)) <> bend_exprs(rest)

def bend_list(xs: List<&2, Br.Brew>) -> String:
  "  [\n" ++ String.join(bend_exprs(xs), ",\n") ++ "\n  ]"
