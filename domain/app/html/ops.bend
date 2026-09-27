import Base
import ../../../general/markup/type.bend as M
import ../../../general/markup/ops.bend as MO
import ../style/type.bend as S
import ../style/ops.bend as SO
import ./type.bend as H

# Html lowered to markup, with each style as its generated class; a document with its stylesheet.

def cls(+s: S.Style) -> M.Attribute:
  M.Attribute{"class", SO.name(s)}

def data(ds: List<&2, H.Datum>) -> List<&2, M.Attribute>:
  match ds:
    case []:
      []
    case H.Datum{n, v} <> rest:
      M.Attribute{"data-" ++ n, v} <> data(rest)

def lower(hs: List<&2, H.Html>) -> List<&2, M.Node>:
  match hs:
    case []:
      []
    case H.Text{t} <> rest:
      M.Text{t} <> lower(rest)
    case H.Main{s, cs} <> rest:
      M.Element{"main", [cls(s)], lower(cs)} <> lower(rest)
    case H.Div{s, cs} <> rest:
      M.Element{"div", [cls(s)], lower(cs)} <> lower(rest)
    case H.Heading{s, t} <> rest:
      M.Element{"h1", [cls(s)], [M.Text{t}]} <> lower(rest)
    case H.Paragraph{s, cs} <> rest:
      M.Element{"p", [cls(s)], lower(cs)} <> lower(rest)
    case H.Span{s, cs} <> rest:
      M.Element{"span", [cls(s)], lower(cs)} <> lower(rest)
    case H.Region{id, s, cs} <> rest:
      M.Element{"div", [M.Attribute{"id", id}, M.Attribute{"aria-live", "polite"}, cls(s)], lower(cs)} <> lower(rest)
    case H.Button{id, label, ds, s} <> rest:
      M.Element{"button", M.Attribute{"type", "button"} <> M.Attribute{"id", id} <> cls(s) <> data(ds), [M.Text{label}]} <> lower(rest)
    case H.TextArea{+id, label, placeholder, value, s} <> rest:
      M.Element{"label", [M.Attribute{"for", id}, M.Attribute{"class", "visually-hidden"}], [M.Text{label}]} <>
      M.Element{"textarea", [M.Attribute{"id", id}, M.Attribute{"placeholder", placeholder}, M.Attribute{"spellcheck", "true"}, cls(s)], [M.Text{value}]} <> lower(rest)
    case H.Field{+id, label, placeholder, s} <> rest:
      M.Element{"label", [M.Attribute{"for", id}, M.Attribute{"class", "visually-hidden"}], [M.Text{label}]} <>
      M.Void{"input", [M.Attribute{"id", id}, M.Attribute{"type", "text"}, M.Attribute{"placeholder", placeholder}, cls(s)]} <> lower(rest)
    case H.Link{href, s, cs} <> rest:
      M.Element{"a", [M.Attribute{"href", href}, cls(s)], lower(cs)} <> lower(rest)

# Every style the elements use, in order.
def styles(hs: List<&2, H.Html>) -> List<&2, S.Style>:
  match hs:
    case []:
      []
    case H.Text{_} <> rest:
      styles(rest)
    case H.Main{s, cs} <> rest:
      s <> List.append(&2, S.Style, styles(cs), styles(rest))
    case H.Div{s, cs} <> rest:
      s <> List.append(&2, S.Style, styles(cs), styles(rest))
    case H.Heading{s, _} <> rest:
      s <> styles(rest)
    case H.Paragraph{s, cs} <> rest:
      s <> List.append(&2, S.Style, styles(cs), styles(rest))
    case H.Span{s, cs} <> rest:
      s <> List.append(&2, S.Style, styles(cs), styles(rest))
    case H.Region{_, s, cs} <> rest:
      s <> List.append(&2, S.Style, styles(cs), styles(rest))
    case H.Button{_, _, _, s} <> rest:
      s <> styles(rest)
    case H.TextArea{_, _, _, _, s} <> rest:
      s <> styles(rest)
    case H.Field{_, _, _, s} <> rest:
      s <> styles(rest)
    case H.Link{_, s, cs} <> rest:
      s <> List.append(&2, S.Style, styles(cs), styles(rest))

# A fragment: elements printed on their own, for a region the page replaces.
def fragment(+hs: List<&2, H.Html>) -> String:
  MO.print(lower(hs))

def base_css() -> String:
  "*{box-sizing:border-box}body{margin:0}.visually-hidden{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}"

def document(d: H.Document) -> String:
  match d:
    case H.Document{title, +body, script}:
      "<!doctype html>" ++ MO.print([M.Element{"html", [M.Attribute{"lang", "en"}], [
        M.Element{"head", [], [
          M.Void{"meta", [M.Attribute{"charset", "utf-8"}]},
          M.Void{"meta", [M.Attribute{"name", "viewport"}, M.Attribute{"content", "width=device-width, initial-scale=1"}]},
          M.Element{"title", [], [M.Text{title}]},
          M.Element{"style", [], [M.Raw{base_css() ++ SO.sheet(styles(body))}]}]},
        M.Element{"body", [], List.append(&2, M.Node, lower(body), [M.Element{"script", [M.Attribute{"src", script}], []}])}]}])
