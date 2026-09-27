import Base
import ./type.bend as M

# Printing markup: text and attribute values are escaped; Raw is printed as it is (a stylesheet or a
# script, whose own language has no markup in it).

def escape.go(cs: List<&2, Char>) -> String:
  match cs:
    case []:
      ""
    case +c <> rest:
      Bool.pick(String, Char.is_eq(c, '&'), "&amp;",
        Bool.pick(String, Char.is_eq(c, '<'), "&lt;",
          Bool.pick(String, Char.is_eq(c, '>'), "&gt;",
            Bool.pick(String, Char.is_eq(c, '"'), "&quot;", String.from_list([c]))))) ++ escape.go(rest)

def escape(s: String) -> String:
  escape.go(String.to_list(s))

def attributes(xs: List<&2, M.Attribute>) -> String:
  match xs:
    case []:
      ""
    case M.Attribute{n, v} <> rest:
      " " ++ n ++ "=\"" ++ escape(v) ++ "\"" ++ attributes(rest)

def print(ns: List<&2, M.Node>) -> String:
  match ns:
    case []:
      ""
    case M.Element{+tag, xs, children} <> rest:
      "<" ++ tag ++ attributes(xs) ++ ">" ++ print(children) ++ "</" ++ tag ++ ">" ++ print(rest)
    case M.Void{tag, xs} <> rest:
      "<" ++ tag ++ attributes(xs) ++ ">" ++ print(rest)
    case M.Text{t} <> rest:
      escape(t) ++ print(rest)
    case M.Raw{t} <> rest:
      t ++ print(rest)
