import Base
import ../lib/effs/io.bend as X

# C4, by Simon Brown (https://c4model.com): a software system's architecture at four levels of zoom.
# Its metamodel, as Structurizr (C4's reference tool) defines it, is a containment hierarchy:
#   software system -> container -> component (-> code, which is the source itself)
# People use software systems; a relationship joins any two elements, with a description and a
# technology. Each view below is one level of zoom, drawn with D2.

# ---- the metamodel ----
type Person is Data:
  Person{key: String, name: String, description: String}

type Component is Data:
  Component{key: String, name: String, description: String, technology: String}

type Container is Data:
  Container{key: String, name: String, description: String, technology: String, components: List<&2, Component>}

type SoftwareSystem is Data:
  SoftwareSystem{key: String, name: String, description: String, containers: List<&2, Container>}

type Relationship is Data:
  Relationship{source: String, destination: String, description: String, technology: String}

# Everything in one model: the system being described sits among the people and systems around it.
type Model is Data:
  Model{people: List<&2, Person>, systems: List<&2, SoftwareSystem>, relationships: List<&2, Relationship>}

# ---- the views: the four levels ----
# Context: a software system, the people who use it and the systems it talks to.
# Containers: inside a software system. Components: inside a container.
type View is Data:
  Context{system: String}
  Containers{system: String}
  Components{container: String}

# ---- the hierarchy, flattened: every element with the system and container it sits in ----
type Level is Data:
  PersonLevel{}
  SystemLevel{}
  ContainerLevel{}
  ComponentLevel{}

type Element is Data:
  Element{key: String, name: String, description: String, technology: String, level: Level, system: String, container: String}

def component_elements(cs: List<&2, Component>, +s: String, +c: String) -> List<&2, Element>:
  match cs:
    case []:
      []
    case x <> rest:
      match x:
        case Component{k, n, d, t}:
          Element{k, n, d, t, ComponentLevel{}, s, c} <> component_elements(rest, s, c)

def container_elements(cs: List<&2, Container>, +s: String) -> List<&2, Element>:
  match cs:
    case []:
      []
    case x <> rest:
      match x:
        case Container{+k, n, d, t, comps}:
          Element{k, n, d, t, ContainerLevel{}, s, k} <> List.append(&2, Element, component_elements(comps, s, k), container_elements(rest, s))

def system_elements(ss: List<&2, SoftwareSystem>) -> List<&2, Element>:
  match ss:
    case []:
      []
    case x <> rest:
      match x:
        case SoftwareSystem{+k, n, d, cs}:
          Element{k, n, d, "", SystemLevel{}, k, ""} <> List.append(&2, Element, container_elements(cs, k), system_elements(rest))

def person_elements(ps: List<&2, Person>) -> List<&2, Element>:
  match ps:
    case []:
      []
    case x <> rest:
      match x:
        case Person{k, n, d}:
          Element{k, n, d, "", PersonLevel{}, "", ""} <> person_elements(rest)

def elements(m: Model) -> List<&2, Element>:
  match m:
    case Model{ps, ss, _}:
      List.append(&2, Element, person_elements(ps), system_elements(ss))

def relationships(m: Model) -> List<&2, Relationship>:
  match m:
    case Model{_, _, rs}:
      rs

def ekey(e: Element) -> String:
  match e:
    case Element{k, _, _, _, _, _, _}:
      k

def nothing() -> Element:
  Element{"", "", "", "", PersonLevel{}, "", ""}

def pick_e(c: Bool, a: Element, b: Element) -> Element:
  match c:
    case True{}:
      a
    case False{}:
      b

def find(+k: String, es: List<&2, Element>) -> Element:
  match es:
    case []:
      nothing()
    case +e <> rest:
      pick_e(String.eq(k, ekey(e)), e, find(k, rest))

def pick_s(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_l(c: Bool, a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      a
    case False{}:
      b

def listed(+x: String, ys: List<&2, String>) -> Bool:
  match ys:
    case []:
      False{}
    case y <> rest:
      String.eq(x, y) || listed(x, rest)

def is_person(l: Level) -> Bool:
  match l:
    case PersonLevel{}:
      True{}
    case _:
      False{}

# ---- lifting: what a view shows an element as ----
# An element outside the view's system shows as its system; inside it, as its container (or, in a
# component view of its own container, as itself). People always show as themselves.
def esystem(e: Element) -> String:
  match e:
    case Element{_, _, _, _, _, s, _}:
      s

def ename(e: Element) -> String:
  match e:
    case Element{_, n, _, _, _, _, _}:
      n

def system_of_container(+c: String, +es: List<&2, Element>) -> String:
  esystem(find(c, es))

def lift_in(e: Element, v: View, +es: List<&2, Element>) -> String:
  match e:
    case Element{+k, _, _, _, +l, +s, +c}:
      match v:
        case Context{_}:
          pick_s(is_person(l), k, s)
        case Containers{+vs}:
          pick_s(is_person(l), k, pick_s(String.eq(s, vs), c, s))
        case Components{+vc}:
          pick_s(is_person(l), k, pick_s(String.eq(c, vc), k, pick_s(String.eq(s, system_of_container(vc, es)), c, s)))

def lift(+k: String, +v: View, +es: List<&2, Element>) -> String:
  lift_in(find(k, es), v, es)

def is_system(l: Level) -> Bool:
  match l:
    case SystemLevel{}:
      True{}
    case _:
      False{}

def is_container(l: Level) -> Bool:
  match l:
    case ContainerLevel{}:
      True{}
    case _:
      False{}

def is_component(l: Level) -> Bool:
  match l:
    case ComponentLevel{}:
      True{}
    case _:
      False{}

# The elements a view is about: the system itself, a system's containers, or a container's components.
def inner_one(e: Element, v: View) -> List<&2, String>:
  match e:
    case Element{k, _, _, _, +l, +s, +c}:
      match v:
        case Context{vs}:
          pick_l(is_system(l) && String.eq(s, vs), [k], [])
        case Containers{vs}:
          pick_l(is_container(l) && String.eq(s, vs), [k], [])
        case Components{vc}:
          pick_l(is_component(l) && String.eq(c, vc), [k], [])

def inner_keys(xs: List<&2, Element>, +v: View) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      List.append(&2, String, inner_one(x, v), inner_keys(rest, v))

# A lifted relationship: two keys the view shows, and what the first does with the second.
type Edge is Data:
  Edge{a: String, b: String, description: String, technology: String}

def drawn(+a: String, +b: String, es: List<&2, Edge>) -> Bool:
  match es:
    case []:
      False{}
    case e <> rest:
      match e:
        case Edge{x, y, _, _}:
          (String.eq(a, x) && String.eq(b, y)) || drawn(a, b, rest)

def cons_edge(c: Bool, e: Edge, rest: List<&2, Edge>) -> List<&2, Edge>:
  match c:
    case True{}:
      e <> rest
    case False{}:
      rest

# Keep an edge that touches the view's own elements, joins two different things, and is not already drawn.
def keep_edge(+a: String, +b: String, d: String, t: String, +inner: List<&2, String>, +rest: List<&2, Edge>) -> List<&2, Edge>:
  cons_edge((listed(a, inner) || listed(b, inner)) && Bool.not(String.eq(a, b)) && Bool.not(String.is_empty(a)) && Bool.not(String.is_empty(b)) && Bool.not(drawn(a, b, rest)), Edge{a, b, d, t}, rest)

def lifted(rs: List<&2, Relationship>, +v: View, +es: List<&2, Element>, +inner: List<&2, String>) -> List<&2, Edge>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case Relationship{src, dst, d, t}:
          keep_edge(lift(src, v, es), lift(dst, v, es), d, t, inner, lifted(rest, v, es, inner))

def more(+k: String, +inner: List<&2, String>, +seen: List<&2, String>, +rest: List<&2, String>) -> List<&2, String>:
  pick_l(listed(k, inner) || listed(k, seen), rest, k <> rest)

# The elements around the view's own: whatever its edges reach.
def around(es: List<&2, Edge>, +inner: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match es:
    case []:
      []
    case e <> rest:
      match e:
        case Edge{+a, +b, _, _}:
          more(a, inner, seen, more(b, inner, a <> seen, around(rest, inner, a <> b <> seen)))

# ---- D2 ----
def level_name(l: Level) -> String:
  match l:
    case PersonLevel{}:
      "Person"
    case SystemLevel{}:
      "Software System"
    case ContainerLevel{}:
      "Container"
    case ComponentLevel{}:
      "Component"

def kind_line(+l: Level, +t: String) -> String:
  pick_s(String.is_empty(t), "[" ++ level_name(l) ++ "]", "[" ++ level_name(l) ++ ": " ++ t ++ "]")

# C4's usual colors: people dark blue, the elements in focus blue, everything around them gray.
def focus_fill(l: Level) -> String:
  match l:
    case PersonLevel{}:
      "#08427B"
    case SystemLevel{}:
      "#1168BD"
    case ContainerLevel{}:
      "#438DD5"
    case ComponentLevel{}:
      "#85BBF0"

def fill(+l: Level, focus: Bool) -> String:
  match focus:
    case False{}:
      pick_s(is_person(l), "#08427B", "#999999")
    case True{}:
      focus_fill(l)

def shape(l: Level) -> String:
  pick_s(is_person(l), "c4-person", "rectangle")

def box(+prefix: String, e: Element, +focus: Bool) -> String:
  match e:
    case Element{k, n, d, t, +l, _, _}:
      prefix ++ "e_" ++ k ++ ": |md\n  **" ++ n ++ "**\n\n  " ++ kind_line(l, t) ++ "\n\n  " ++ d ++ "\n| {shape: " ++ shape(l) ++ "; style.fill: \"" ++ fill(l, focus) ++ "\"; style.stroke: \"" ++ fill(l, focus) ++ "\"; style.font-color: \"#FFFFFF\"}\n"

def boxes(ks: List<&2, String>, +prefix: String, +focus: Bool, +es: List<&2, Element>) -> String:
  match ks:
    case []:
      ""
    case k <> rest:
      box(prefix, find(k, es), focus) ++ boxes(rest, prefix, focus, es)

def path(+k: String, +inner: List<&2, String>, +boundary: String) -> String:
  pick_s(listed(k, inner) && Bool.not(String.is_empty(boundary)), "e_" ++ boundary ++ ".e_" ++ k, "e_" ++ k)

def edge_lines(xs: List<&2, Edge>, +inner: List<&2, String>, +boundary: String) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match x:
        case Edge{a, b, d, +t}:
          path(a, inner, boundary) ++ " -> " ++ path(b, inner, boundary) ++ ": \"" ++ d ++ pick_s(String.is_empty(t), "", "\\n[" ++ t ++ "]") ++ "\"\n" ++ edge_lines(rest, inner, boundary)

def name_of(+k: String, +es: List<&2, Element>) -> String:
  ename(find(k, es))

# D2 names are the element keys, prefixed so none is a D2 keyword (like near).
# The box a view draws around its own elements: none in a context view, else the system or container.
def boundary(v: View) -> String:
  match v:
    case Context{_}:
      ""
    case Containers{s}:
      s
    case Components{c}:
      c

def title(v: View, +es: List<&2, Element>) -> String:
  match v:
    case Context{s}:
      "System context: " ++ name_of(s, es)
    case Containers{s}:
      "Containers: " ++ name_of(s, es)
    case Components{c}:
      "Components: " ++ name_of(c, es)

def d2_edges(+es: List<&2, Element>, +xs: List<&2, Edge>, +inner: List<&2, String>, +b: String, v: View) -> String:
  "direction: down\n" ++
  "title: \"" ++ title(v, es) ++ "\" {near: top-center; shape: text; style.font-size: 28; style.bold: true}\n" ++
  pick_s(String.is_empty(b), boxes(inner, "", True{}, es),
    "e_" ++ b ++ ": \"" ++ name_of(b, es) ++ "\" {style.fill: \"transparent\"; style.stroke: \"#444444\"; style.stroke-dash: 4}\n" ++ boxes(inner, "e_" ++ b ++ ".", True{}, es)) ++
  boxes(around(xs, inner, []), "", False{}, es) ++
  edge_lines(xs, inner, b)

def d2_with(+es: List<&2, Element>, rs: List<&2, Relationship>, +v: View) -> String:
  d2_edges(es, lifted(List.reverse(&2, Relationship, rs), v, es, inner_keys(es, v)), inner_keys(es, v), boundary(v), v)

def d2_view(+m: Model, +v: View) -> String:
  d2_with(elements(m), relationships(m), v)

# ---- rendering: each view to <dir>/<name>.d2 and .png ----
type Render is Data:
  Render{name: String, view: View}

def render(+m: Model, +dir: String, rs: List<&2, Render>) -> IO(Unit):
  match rs:
    case []:
      IO.pure(Unit, Unit{})
    case r <> rest:
      match r:
        case Render{+name, v}:
          do IO<Unit>:
            X.write_file(dir ++ "/" ++ name ++ ".d2", d2_view(m, v))
            out : String <- X.sh("d2 --layout elk --pad 40 " ++ dir ++ "/" ++ name ++ ".d2 " ++ dir ++ "/" ++ name ++ ".png 2>&1")
            IO.print(name ++ ": " ++ out)
            render(m, dir, rest)
