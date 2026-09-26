import Base
import ../../../general/rose/type.bend as R
import ../../../general/rose/ops.bend as RO
import ../../../general/compound/type.bend as C
import ../../../general/compound/ops.bend as CO
import ../../../general/compound/edge/type.bend as E
import ../type.bend as A
import ../ops.bend as O
import ../system/deployment/type.bend as D
import ./type.bend as Vw

# ---- one element as a D2 box, in C4's colors: people dark blue, what the view is about blue,
# everything around it gray ----
def level_name(l: A.Level) -> String:
  match l:
    case A.PersonLevel{}:
      "Person"
    case A.SystemLevel{}:
      "Software System"
    case A.ContainerLevel{}:
      "Container"
    case A.ComponentLevel{}:
      "Component"
    case A.ExternalLevel{}:
      "Software System"

def kind_line(+l: A.Level, +t: String) -> String:
  Bool.pick(String, String.is_empty(t), "[" ++ level_name(l) ++ "]", "[" ++ level_name(l) ++ ": " ++ t ++ "]")

def is_person(l: A.Level) -> Bool:
  match l:
    case A.PersonLevel{}:
      True{}
    case _:
      False{}

def focus_fill(l: A.Level) -> String:
  match l:
    case A.PersonLevel{}:
      "#08427B"
    case A.SystemLevel{}:
      "#1168BD"
    case A.ContainerLevel{}:
      "#438DD5"
    case A.ComponentLevel{}:
      "#85BBF0"
    case A.ExternalLevel{}:
      "#999999"

def fill(+l: A.Level, focus: Bool) -> String:
  match focus:
    case False{}:
      Bool.pick(String, is_person(l), "#08427B", "#999999")
    case True{}:
      focus_fill(l)

def box(+path: String, e: A.Element, +focus: Bool) -> String:
  match e:
    case A.Element{n, d, t, +l}:
      path ++ ": |md\n  **" ++ n ++ "**\n\n  " ++ kind_line(l, t) ++ "\n\n  " ++ d ++ "\n| {shape: " ++ Bool.pick(String, is_person(l), "c4-person", "rectangle") ++ "; style.fill: \"" ++ fill(l, focus) ++ "\"; style.stroke: \"" ++ fill(l, focus) ++ "\"; style.font-color: \"#FFFFFF\"}\n"

def element(+k: String, +rs: List<&2, R.Rose<A.Element>>) -> A.Element:
  Maybe.default(&2, A.Element, RO.find(A.Element, k, rs), A.Element{k, "", "", A.ExternalLevel{}})

# D2 names are the keys, prefixed so none is a D2 keyword (like near).
def boxes(ks: List<&2, String>, +prefix: String, +focus: Bool, +rs: List<&2, R.Rose<A.Element>>) -> String:
  match ks:
    case []:
      ""
    case +k <> rest:
      box(prefix ++ "e_" ++ k, element(k, rs), focus) ++ boxes(rest, prefix, focus, rs)

# ---- which keys a view shows ----
def keep_unless(c: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      rest
    case False{}:
      x <> rest

def without(+k: String, xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      keep_unless(String.eq(k, x), x, without(k, rest))

# The keys the view is about, drawn inside its boundary.
def inner(+a: A.Architecture, v: Vw.View) -> List<&2, String>:
  match v:
    case Vw.Context{}:
      [O.system_key(a)]
    case Vw.Containers{}:
      O.container_keys(O.containers(a))
    case Vw.Components{c}:
      O.components_of(c, O.containers(a))
    case Vw.Deployment{}:
      []
    case Vw.Dynamic{_}:
      []

# The keys the view may show: its own, the rest of the system at the level above, and the environment.
def visible(+a: A.Architecture, v: Vw.View) -> List<&2, String>:
  match v:
    case Vw.Context{}:
      O.system_key(a) <> O.environment_keys(a)
    case Vw.Containers{}:
      List.append(&2, String, O.container_keys(O.containers(a)), O.environment_keys(a))
    case Vw.Components{+c}:
      List.append(&2, String, O.components_of(c, O.containers(a)), List.append(&2, String, without(c, O.container_keys(O.containers(a))), O.environment_keys(a)))
    case Vw.Deployment{}:
      []
    case Vw.Dynamic{_}:
      []

def boundary(+a: A.Architecture, v: Vw.View) -> String:
  match v:
    case Vw.Context{}:
      ""
    case Vw.Containers{}:
      O.system_key(a)
    case Vw.Components{c}:
      c
    case Vw.Deployment{}:
      ""
    case Vw.Dynamic{_}:
      O.system_key(a)

def ename(e: A.Element) -> String:
  match e:
    case A.Element{n, _, _, _}:
      n

def title(+a: A.Architecture, +rs: List<&2, R.Rose<A.Element>>, v: Vw.View) -> String:
  match v:
    case Vw.Context{}:
      "System context: " ++ ename(element(O.system_key(a), rs))
    case Vw.Containers{}:
      "Containers: " ++ ename(element(O.system_key(a), rs))
    case Vw.Components{c}:
      "Components: " ++ ename(element(c, rs))
    case Vw.Deployment{}:
      "Deployment: " ++ ename(element(O.system_key(a), rs))
    case Vw.Dynamic{_}:
      "Dynamic: " ++ ename(element(O.system_key(a), rs))

# ---- drawing ----
def header(+t: String) -> String:
  "direction: down\ntitle: \"" ++ t ++ "\" {near: top-center; shape: text; style.font-size: 28; style.bold: true}\n"

def roots(c: C.Compound<A.Element>) -> List<&2, R.Rose<A.Element>>:
  match c:
    case C.Compound{rs, _}:
      rs

def keep_edge(c: Bool, e: E.Edge, rest: List<&2, E.Edge>) -> List<&2, E.Edge>:
  match c:
    case True{}:
      e <> rest
    case False{}:
      rest

# The edges with an end among the view's own keys.
def touching(es: List<&2, E.Edge>, +ins: List<&2, String>) -> List<&2, E.Edge>:
  match es:
    case []:
      []
    case e <> rest:
      match e:
        case E.Edge{+x, +y, l, t}:
          keep_edge(CO.has(ins, x) || CO.has(ins, y), E.Edge{x, y, l, t}, touching(rest, ins))

def keep_new(c: Bool, +k: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      k <> rest
    case False{}:
      rest

# The keys around the view's own: whatever its edges reach, once each.
def around(es: List<&2, E.Edge>, +ins: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match es:
    case []:
      []
    case e <> rest:
      match e:
        case E.Edge{+x, +y, _, _}:
          keep_new(Bool.not(CO.has(ins, x) || CO.has(seen, x)), x,
            keep_new(Bool.not(CO.has(ins, y) || CO.has(x <> seen, y) || String.eq(x, y)), y, around(rest, ins, x <> y <> seen)))

def path(+k: String, +ins: List<&2, String>, +b: String) -> String:
  Bool.pick(String, CO.has(ins, k) && Bool.not(String.is_empty(b)), "e_" ++ b ++ ".e_" ++ k, "e_" ++ k)

def label(+d: String, +t: String) -> String:
  "\"" ++ d ++ Bool.pick(String, String.is_empty(t), "", "\\n[" ++ t ++ "]") ++ "\""

def edge_lines(es: List<&2, E.Edge>, +ins: List<&2, String>, +b: String) -> String:
  match es:
    case []:
      ""
    case e <> rest:
      match e:
        case E.Edge{x, y, d, t}:
          path(x, ins, b) ++ " -> " ++ path(y, ins, b) ++ ": " ++ label(d, t) ++ "\n" ++ edge_lines(rest, ins, b)

def inner_boxes(+ins: List<&2, String>, +b: String, +rs: List<&2, R.Rose<A.Element>>) -> String:
  Bool.pick(String, String.is_empty(b), boxes(ins, "", True{}, rs),
    "e_" ++ b ++ ": \"" ++ ename(element(b, rs)) ++ "\" {style.fill: \"transparent\"; style.stroke: \"#444444\"; style.stroke-dash: 4}\n" ++ boxes(ins, "e_" ++ b ++ ".", True{}, rs))

def draw(+t: String, +ins: List<&2, String>, +b: String, +rs: List<&2, R.Rose<A.Element>>, +es: List<&2, E.Edge>) -> String:
  header(t) ++ inner_boxes(ins, b, rs) ++ boxes(around(es, ins, []), "", False{}, rs) ++ edge_lines(es, ins, b)

# Context, containers and components: the view's keys, and the architecture's edges lifted to what shows.
def static_view(+a: A.Architecture, +v: Vw.View) -> String:
  +c = O.to_compound(a)
  +ins = inner(a, v)
  draw(title(a, roots(c), v), ins, boundary(a, v), roots(c), touching(CO.lift(A.Element, c, visible(a, v)), ins))

# ---- dynamic: numbered steps between elements as they are ----
def step_edges(ss: List<&2, Vw.Step>, +n: Nat) -> List<&2, E.Edge>:
  match ss:
    case []:
      []
    case s <> rest:
      match s:
        case Vw.Step{x, y, d, t}:
          E.Edge{x, y, Nat.show(n) ++ ". " ++ d, t} <> step_edges(rest, Nat.add(n, 1n))

# The steps' ends inside the system, once each.
def inside(es: List<&2, E.Edge>, +sys: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match es:
    case []:
      []
    case e <> rest:
      match e:
        case E.Edge{+x, +y, _, _}:
          keep_new(CO.has(sys, x) && Bool.not(CO.has(seen, x)), x,
            keep_new(CO.has(sys, y) && Bool.not(CO.has(x <> seen, y)), y, inside(rest, sys, x <> y <> seen)))

def dynamic_view(+a: A.Architecture, ss: List<&2, Vw.Step>) -> String:
  +c = O.to_compound(a)
  +es = step_edges(ss, 1n)
  +sys = List.append(&2, String, O.container_keys(O.containers(a)), O.all_component_keys(O.containers(a)))
  draw(title(a, roots(c), Vw.Dynamic{[]}), inside(es, sys, []), O.system_key(a), roots(c), es)

# ---- deployment: the machines, nested, with the containers running on them ----
def node_kind(+t: String) -> String:
  Bool.pick(String, String.is_empty(t), "[Deployment Node]", "[Deployment Node: " ++ t ++ "]")

def instance_boxes(ks: List<&2, String>, +p: String, +rs: List<&2, R.Rose<A.Element>>) -> String:
  match ks:
    case []:
      ""
    case +k <> rest:
      box(p ++ "e_" ++ k, element(k, rs), True{}) ++ instance_boxes(rest, p, rs)

def node_lines(ns: List<&2, D.Node>, +prefix: String, +rs: List<&2, R.Rose<A.Element>>) -> String:
  match ns:
    case []:
      ""
    case n <> rest:
      match n:
        case D.Node{+k, name, +t, _, _, _, kids, ins}:
          prefix ++ "d_" ++ k ++ ": \"" ++ name ++ "\\n" ++ node_kind(t) ++ "\" {style.fill: \"#FFFFFF\"; style.stroke: \"#888888\"; style.font-color: \"#000000\"}\n" ++
            instance_boxes(ins, prefix ++ "d_" ++ k ++ ".", rs) ++ node_lines(kids, prefix ++ "d_" ++ k ++ ".", rs) ++ node_lines(rest, prefix, rs)

# Where each instance is drawn: its container's key and its D2 path.
type Placed is Data:
  Placed{key: String, path: String}

def instance_places(ks: List<&2, String>, +p: String) -> List<&2, Placed>:
  match ks:
    case []:
      []
    case +k <> rest:
      Placed{k, p ++ "e_" ++ k} <> instance_places(rest, p)

def places(ns: List<&2, D.Node>, +prefix: String) -> List<&2, Placed>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case D.Node{+k, _, _, _, _, _, kids, ins}:
          List.append(&2, Placed, instance_places(ins, prefix ++ "d_" ++ k ++ "."),
            List.append(&2, Placed, places(kids, prefix ++ "d_" ++ k ++ "."), places(rest, prefix)))

def to_each(ps: List<&2, Placed>, +from: String, +y: String, +d: String, +t: String, +rest: List<&2, E.Edge>) -> List<&2, E.Edge>:
  match ps:
    case []:
      rest
    case p <> more:
      match p:
        case Placed{pk, +pp}:
          keep_edge(String.eq(pk, y) && Bool.not(String.eq(from, pp)), E.Edge{from, pp, d, t}, to_each(more, from, y, d, t, rest))

def from_here(c: Bool, +all: List<&2, Placed>, +pp: String, +y: String, +d: String, +t: String, +tail: List<&2, E.Edge>) -> List<&2, E.Edge>:
  match c:
    case True{}:
      to_each(all, pp, y, d, t, tail)
    case False{}:
      tail

def from_each(ps: List<&2, Placed>, +all: List<&2, Placed>, +x: String, +y: String, +d: String, +t: String, +rest: List<&2, E.Edge>) -> List<&2, E.Edge>:
  match ps:
    case []:
      rest
    case p <> more:
      match p:
        case Placed{pk, +pp}:
          from_here(String.eq(pk, x), all, pp, y, d, t, from_each(more, all, x, y, d, t, rest))

# Each container edge, drawn between every pair of its ends' instances.
def instance_edges(es: List<&2, E.Edge>, +ps: List<&2, Placed>) -> List<&2, E.Edge>:
  match es:
    case []:
      []
    case e <> rest:
      match e:
        case E.Edge{x, y, d, t}:
          from_each(ps, ps, x, y, d, t, instance_edges(rest, ps))

def path_lines(es: List<&2, E.Edge>) -> String:
  match es:
    case []:
      ""
    case e <> rest:
      match e:
        case E.Edge{x, y, d, t}:
          x ++ " -> " ++ y ++ ": " ++ label(d, t) ++ "\n" ++ path_lines(rest)

def deployment_view(+a: A.Architecture) -> String:
  +c = O.to_compound(a)
  +ns = O.nodes(a)
  header(title(a, roots(c), Vw.Deployment{})) ++ node_lines(ns, "", roots(c)) ++
    path_lines(instance_edges(CO.lift(A.Element, c, O.container_keys(O.containers(a))), places(ns, "")))

# ---- a view as D2 ----
def d2(+a: A.Architecture, v: Vw.View) -> String:
  match v:
    case Vw.Context{}:
      static_view(a, Vw.Context{})
    case Vw.Containers{}:
      static_view(a, Vw.Containers{})
    case Vw.Components{c}:
      static_view(a, Vw.Components{c})
    case Vw.Deployment{}:
      deployment_view(a)
    case Vw.Dynamic{ss}:
      dynamic_view(a, ss)
