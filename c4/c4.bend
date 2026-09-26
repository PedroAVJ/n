import Base
import ../lib/effs/io.bend as X

# C4, by Simon Brown (https://c4model.com): a software system's architecture at four levels of zoom,
# plus where it runs. Its metamodel, as Structurizr (C4's reference tool) defines it:
#   static structure, a containment hierarchy: software system -> container -> component
#     (-> code, which is the source itself); people use software systems.
#   deployment, a second hierarchy: environment -> deployment node -> (deployment node,
#     infrastructure node, software system instance, container instance).
#   relationships join any two elements, with a description and a technology.
#   views: system landscape, system context, containers, components, dynamic and deployment,
#     all in a workspace. Each is drawn with D2.
# Every element and relationship may also carry tags, a URL and free-form properties.

# ---- the metamodel: what every element may carry ----
type Property is Data:
  Property{name: String, value: String}

type Extra is Data:
  Extra{tags: List<&2, String>, url: String, properties: List<&2, Property>}

# No tags, no URL, no properties.
def plain() -> Extra:
  Extra{[], "", []}

# ---- static structure ----
type Person is Data:
  Person{key: String, name: String, description: String, extra: Extra}

type Component is Data:
  Component{key: String, name: String, description: String, technology: String, extra: Extra}

type Container is Data:
  Container{key: String, name: String, description: String, technology: String, components: List<&2, Component>, extra: Extra}

type SoftwareSystem is Data:
  SoftwareSystem{key: String, name: String, description: String, containers: List<&2, Container>, extra: Extra}

# Its ends are keys of any two elements: people, software systems, containers, components, infrastructure nodes.
type Relationship is Data:
  Relationship{source: String, destination: String, description: String, technology: String, extra: Extra}

# ---- deployment ----
type InfrastructureNode is Data:
  InfrastructureNode{key: String, name: String, description: String, technology: String, extra: Extra}

type SoftwareSystemInstance is Data:
  SoftwareSystemInstance{system: String, extra: Extra}

type ContainerInstance is Data:
  ContainerInstance{container: String, extra: Extra}

# A machine, virtual machine, runtime or other place things run, nested as deep as they are.
type DeploymentNode is Data:
  DeploymentNode{key: String, name: String, description: String, technology: String, instances: Nat, children: List<&2, DeploymentNode>, infrastructure: List<&2, InfrastructureNode>, systems: List<&2, SoftwareSystemInstance>, containers: List<&2, ContainerInstance>, extra: Extra}

type DeploymentEnvironment is Data:
  DeploymentEnvironment{name: String, nodes: List<&2, DeploymentNode>}

type Model is Data:
  Model{people: List<&2, Person>, systems: List<&2, SoftwareSystem>, environments: List<&2, DeploymentEnvironment>, relationships: List<&2, Relationship>}

# ---- views ----
# One numbered step of a dynamic view.
type Step is Data:
  Step{source: String, destination: String, description: String, technology: String}

# System landscape: every person and software system. System context: one software system, the people
# who use it and the systems it talks to. Containers: inside a software system. Components: inside a
# container. Dynamic: numbered steps, within a system or container ("*" for everything). Deployment:
# one environment's nodes and the instances on them, for one system ("*" for all).
type View is Data:
  SystemLandscape{}
  SystemContext{system: String}
  Containers{system: String}
  Components{container: String}
  Dynamic{scope: String, steps: List<&2, Step>}
  Deployment{scope: String, environment: String}

type ViewDef is Data:
  ViewDef{key: String, view: View}

type Workspace is Data:
  Workspace{name: String, description: String, model: Model, views: List<&2, ViewDef>}

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
        case Component{k, n, d, t, _}:
          Element{k, n, d, t, ComponentLevel{}, s, c} <> component_elements(rest, s, c)

def container_elements(cs: List<&2, Container>, +s: String) -> List<&2, Element>:
  match cs:
    case []:
      []
    case x <> rest:
      match x:
        case Container{+k, n, d, t, comps, _}:
          Element{k, n, d, t, ContainerLevel{}, s, k} <> List.append(&2, Element, component_elements(comps, s, k), container_elements(rest, s))

def system_elements(ss: List<&2, SoftwareSystem>) -> List<&2, Element>:
  match ss:
    case []:
      []
    case x <> rest:
      match x:
        case SoftwareSystem{+k, n, d, cs, _}:
          Element{k, n, d, "", SystemLevel{}, k, ""} <> List.append(&2, Element, container_elements(cs, k), system_elements(rest))

def person_elements(ps: List<&2, Person>) -> List<&2, Element>:
  match ps:
    case []:
      []
    case x <> rest:
      match x:
        case Person{k, n, d, _}:
          Element{k, n, d, "", PersonLevel{}, "", ""} <> person_elements(rest)

def elements(m: Model) -> List<&2, Element>:
  match m:
    case Model{ps, ss, _, _}:
      List.append(&2, Element, person_elements(ps), system_elements(ss))

def relationships(m: Model) -> List<&2, Relationship>:
  match m:
    case Model{_, _, _, rs}:
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
        case SystemLandscape{}:
          pick_s(is_person(l), k, s)
        case SystemContext{_}:
          pick_s(is_person(l), k, s)
        case Containers{+vs}:
          pick_s(is_person(l), k, pick_s(String.eq(s, vs), c, s))
        case Components{+vc}:
          pick_s(is_person(l), k, pick_s(String.eq(c, vc), k, pick_s(String.eq(s, system_of_container(vc, es)), c, s)))
        case Dynamic{_, _}:
          k
        case Deployment{_, _}:
          k

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
        case SystemLandscape{}:
          pick_l(is_system(l) || is_person(l), [k], [])
        case SystemContext{vs}:
          pick_l(is_system(l) && String.eq(s, vs), [k], [])
        case Containers{vs}:
          pick_l(is_container(l) && String.eq(s, vs), [k], [])
        case Components{vc}:
          pick_l(is_component(l) && String.eq(c, vc), [k], [])
        case Dynamic{_, _}:
          []
        case Deployment{_, _}:
          []

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
        case Relationship{src, dst, d, t, _}:
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
# The box a view draws around its own elements: none for the landscape, a context or all of a
# dynamic view; else the system, container or dynamic view's scope.
def boundary(v: View) -> String:
  match v:
    case SystemLandscape{}:
      ""
    case SystemContext{_}:
      ""
    case Containers{s}:
      s
    case Components{c}:
      c
    case Dynamic{+sc, _}:
      pick_s(String.eq(sc, "*"), "", sc)
    case Deployment{_, _}:
      ""

def scope_name(+sc: String, +es: List<&2, Element>) -> String:
  pick_s(String.eq(sc, "*"), "everything", name_of(sc, es))

def title(v: View, +es: List<&2, Element>) -> String:
  match v:
    case SystemLandscape{}:
      "System landscape"
    case SystemContext{s}:
      "System context: " ++ name_of(s, es)
    case Containers{s}:
      "Containers: " ++ name_of(s, es)
    case Components{c}:
      "Components: " ++ name_of(c, es)
    case Dynamic{sc, _}:
      "Dynamic: " ++ scope_name(sc, es)
    case Deployment{sc, env}:
      "Deployment: " ++ scope_name(sc, es) ++ " · " ++ env

def title_line(+t: String) -> String:
  "title: \"" ++ t ++ "\" {near: top-center; shape: text; style.font-size: 28; style.bold: true}\n"

def d2_edges(+es: List<&2, Element>, +xs: List<&2, Edge>, +inner: List<&2, String>, +b: String, v: View) -> String:
  "direction: down\n" ++ title_line(title(v, es)) ++
  pick_s(String.is_empty(b), boxes(inner, "", True{}, es),
    "e_" ++ b ++ ": \"" ++ name_of(b, es) ++ "\" {style.fill: \"transparent\"; style.stroke: \"#444444\"; style.stroke-dash: 4}\n" ++ boxes(inner, "e_" ++ b ++ ".", True{}, es)) ++
  boxes(around(xs, inner, []), "", False{}, es) ++
  edge_lines(xs, inner, b)

def d2_with(+es: List<&2, Element>, rs: List<&2, Relationship>, +v: View) -> String:
  d2_edges(es, lifted(List.reverse(&2, Relationship, rs), v, es, inner_keys(es, v)), inner_keys(es, v), boundary(v), v)

# ---- dynamic views: numbered steps between elements, as they are (not lifted) ----
def step_edges(ss: List<&2, Step>, +n: Nat) -> List<&2, Edge>:
  match ss:
    case []:
      []
    case x <> rest:
      match x:
        case Step{a, b, d, t}:
          Edge{a, b, Nat.show(n) ++ ". " ++ d, t} <> step_edges(rest, Nat.add(n, 1n))

def econtainer(e: Element) -> String:
  match e:
    case Element{_, _, _, _, _, _, c}:
      c

def elevel(e: Element) -> Level:
  match e:
    case Element{_, _, _, _, l, _, _}:
      l

# Inside the scope: in the system or container the view is scoped to, but not the scope itself.
def in_scope(+k: String, +sc: String, +es: List<&2, Element>) -> Bool:
  Bool.not(String.eq(sc, "*")) && Bool.not(String.eq(k, sc)) && (String.eq(esystem(find(k, es)), sc) || String.eq(econtainer(find(k, es)), sc))

def keep_if(c: Bool, +k: String, +rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      k <> rest
    case False{}:
      rest

def scoped(xs: List<&2, Edge>, +sc: String, +es: List<&2, Element>, +seen: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case Edge{+a, +b, _, _}:
          keep_if(in_scope(a, sc, es) && Bool.not(listed(a, seen)), a,
            keep_if(in_scope(b, sc, es) && Bool.not(listed(b, a <> seen)), b, scoped(rest, sc, es, a <> b <> seen)))

def d2_steps(+es: List<&2, Element>, +sc: String, +xs: List<&2, Edge>) -> String:
  d2_edges(es, xs, scoped(xs, sc, es, []), pick_s(String.eq(sc, "*"), "", sc), Dynamic{sc, []})

def d2_dynamic(+es: List<&2, Element>, +sc: String, steps: List<&2, Step>) -> String:
  d2_steps(es, sc, step_edges(steps, 1n))

# ---- deployment views: an environment's nodes, nested, with the instances on them ----
def environments(m: Model) -> List<&2, DeploymentEnvironment>:
  match m:
    case Model{_, _, envs, _}:
      envs

def pick_nodes(c: Bool, a: List<&2, DeploymentNode>, b: List<&2, DeploymentNode>) -> List<&2, DeploymentNode>:
  match c:
    case True{}:
      a
    case False{}:
      b

def env_nodes(envs: List<&2, DeploymentEnvironment>, +name: String) -> List<&2, DeploymentNode>:
  match envs:
    case []:
      []
    case e <> rest:
      match e:
        case DeploymentEnvironment{n, ns}:
          pick_nodes(String.eq(n, name), ns, env_nodes(rest, name))

# An instance is drawn when the view covers its software system ("*" covers all).
def covered(+k: String, +sc: String, +es: List<&2, Element>) -> Bool:
  String.eq(sc, "*") || String.eq(esystem(find(k, es)), sc)

def show_if(c: Bool, text: String) -> String:
  match c:
    case True{}:
      text
    case False{}:
      ""

def times(+n: Nat) -> String:
  pick_s(Nat.is_gt(n, 1n), " ×" ++ Nat.show(n), "")

def node_kind(+t: String) -> String:
  pick_s(String.is_empty(t), "[Deployment Node]", "[Deployment Node: " ++ t ++ "]")

def infra_lines(xs: List<&2, InfrastructureNode>, +p: String) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match x:
        case InfrastructureNode{k, n, d, +t, _}:
          p ++ "i_" ++ k ++ ": |md\n  **" ++ n ++ "**\n\n  " ++ pick_s(String.is_empty(t), "[Infrastructure Node]", "[Infrastructure Node: " ++ t ++ "]") ++ "\n\n  " ++ d ++ "\n| {shape: rectangle; style.fill: \"#FFFFFF\"; style.stroke: \"#888888\"; style.font-color: \"#000000\"}\n" ++ infra_lines(rest, p)

def system_instance_lines(xs: List<&2, SoftwareSystemInstance>, +p: String, +sc: String, +es: List<&2, Element>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match x:
        case SoftwareSystemInstance{+k, _}:
          show_if(covered(k, sc, es), box(p, find(k, es), True{})) ++ system_instance_lines(rest, p, sc, es)

def container_instance_lines(xs: List<&2, ContainerInstance>, +p: String, +sc: String, +es: List<&2, Element>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match x:
        case ContainerInstance{+k, _}:
          show_if(covered(k, sc, es), box(p, find(k, es), True{})) ++ container_instance_lines(rest, p, sc, es)

def node_lines(ns: List<&2, DeploymentNode>, +prefix: String, +sc: String, +es: List<&2, Element>) -> String:
  match ns:
    case []:
      ""
    case x <> rest:
      match x:
        case DeploymentNode{+k, n, _, +t, i, kids, infra, sys, cons, _}:
          prefix ++ "d_" ++ k ++ ": \"" ++ n ++ "\\n" ++ node_kind(t) ++ times(i) ++ "\" {style.fill: \"#FFFFFF\"; style.stroke: \"#888888\"; style.font-color: \"#000000\"}\n" ++
            infra_lines(infra, prefix ++ "d_" ++ k ++ ".") ++ system_instance_lines(sys, prefix ++ "d_" ++ k ++ ".", sc, es) ++
            container_instance_lines(cons, prefix ++ "d_" ++ k ++ ".", sc, es) ++
            node_lines(kids, prefix ++ "d_" ++ k ++ ".", sc, es) ++ node_lines(rest, prefix, sc, es)

# Where each drawn instance or infrastructure node sits: its element's key and its D2 path.
type Placed is Data:
  Placed{key: String, path: String}

def keep_placed(c: Bool, x: Placed, rest: List<&2, Placed>) -> List<&2, Placed>:
  match c:
    case True{}:
      x <> rest
    case False{}:
      rest

def infra_placed(xs: List<&2, InfrastructureNode>, +p: String) -> List<&2, Placed>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case InfrastructureNode{+k, _, _, _, _}:
          Placed{k, p ++ "i_" ++ k} <> infra_placed(rest, p)

def system_placed(xs: List<&2, SoftwareSystemInstance>, +p: String, +sc: String, +es: List<&2, Element>) -> List<&2, Placed>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case SoftwareSystemInstance{+k, _}:
          keep_placed(covered(k, sc, es), Placed{k, p ++ "e_" ++ k}, system_placed(rest, p, sc, es))

def container_placed(xs: List<&2, ContainerInstance>, +p: String, +sc: String, +es: List<&2, Element>) -> List<&2, Placed>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case ContainerInstance{+k, _}:
          keep_placed(covered(k, sc, es), Placed{k, p ++ "e_" ++ k}, container_placed(rest, p, sc, es))

def node_placed(ns: List<&2, DeploymentNode>, +prefix: String, +sc: String, +es: List<&2, Element>) -> List<&2, Placed>:
  match ns:
    case []:
      []
    case x <> rest:
      match x:
        case DeploymentNode{+k, _, _, _, _, kids, infra, sys, cons, _}:
          List.append(&2, Placed, infra_placed(infra, prefix ++ "d_" ++ k ++ "."),
            List.append(&2, Placed, system_placed(sys, prefix ++ "d_" ++ k ++ ".", sc, es),
              List.append(&2, Placed, container_placed(cons, prefix ++ "d_" ++ k ++ ".", sc, es),
                List.append(&2, Placed, node_placed(kids, prefix ++ "d_" ++ k ++ ".", sc, es), node_placed(rest, prefix, sc, es)))))

# A relationship shows between instances: a component's relationships are its container's.
def deployed_key(+k: String, +es: List<&2, Element>) -> String:
  pick_s(is_component(elevel(find(k, es))), econtainer(find(k, es)), k)

def targets(ps: List<&2, Placed>, +src: String, +dk: String, +d: String, +t: String, +rest: List<&2, Edge>) -> List<&2, Edge>:
  match ps:
    case []:
      rest
    case x <> more:
      match x:
        case Placed{pk, +pp}:
          cons_edge(String.eq(pk, dk) && Bool.not(String.eq(src, pp)) && Bool.not(drawn(src, pp, rest)), Edge{src, pp, d, t}, targets(more, src, dk, d, t, rest))

def from_here(c: Bool, +all: List<&2, Placed>, +pp: String, +dk: String, +d: String, +t: String, +tail: List<&2, Edge>) -> List<&2, Edge>:
  match c:
    case True{}:
      targets(all, pp, dk, d, t, tail)
    case False{}:
      tail

def sources(ps: List<&2, Placed>, +all: List<&2, Placed>, +sk: String, +dk: String, +d: String, +t: String, +rest: List<&2, Edge>) -> List<&2, Edge>:
  match ps:
    case []:
      rest
    case x <> more:
      match x:
        case Placed{pk, +pp}:
          from_here(String.eq(pk, sk), all, pp, dk, d, t, sources(more, all, sk, dk, d, t, rest))

def deploy_edges(rs: List<&2, Relationship>, +es: List<&2, Element>, +placed: List<&2, Placed>) -> List<&2, Edge>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case Relationship{src, dst, d, t, _}:
          sources(placed, placed, deployed_key(src, es), deployed_key(dst, es), d, t, deploy_edges(rest, es, placed))

def path_edge_lines(xs: List<&2, Edge>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match x:
        case Edge{a, b, d, +t}:
          a ++ " -> " ++ b ++ ": \"" ++ d ++ pick_s(String.is_empty(t), "", "\\n[" ++ t ++ "]") ++ "\"\n" ++ path_edge_lines(rest)

def d2_nodes(+es: List<&2, Element>, rs: List<&2, Relationship>, +ns: List<&2, DeploymentNode>, +sc: String, +env: String) -> String:
  "direction: down\n" ++ title_line(title(Deployment{sc, env}, es)) ++ node_lines(ns, "", sc, es) ++
    path_edge_lines(deploy_edges(List.reverse(&2, Relationship, rs), es, node_placed(ns, "", sc, es)))

def d2_deployment(+m: Model, +sc: String, +env: String) -> String:
  d2_nodes(elements(m), relationships(m), env_nodes(environments(m), env), sc, env)

def d2_view(+m: Model, v: View) -> String:
  match v:
    case SystemLandscape{}:
      d2_with(elements(m), relationships(m), SystemLandscape{})
    case SystemContext{s}:
      d2_with(elements(m), relationships(m), SystemContext{s})
    case Containers{s}:
      d2_with(elements(m), relationships(m), Containers{s})
    case Components{c}:
      d2_with(elements(m), relationships(m), Components{c})
    case Dynamic{sc, steps}:
      d2_dynamic(elements(m), sc, steps)
    case Deployment{sc, env}:
      d2_deployment(m, sc, env)

# ---- rendering: each of a workspace's views to <dir>/<key>.d2 and .png ----
def render_views(+m: Model, +dir: String, vs: List<&2, ViewDef>) -> IO(Unit):
  match vs:
    case []:
      IO.pure(Unit, Unit{})
    case x <> rest:
      match x:
        case ViewDef{+key, v}:
          do IO<Unit>:
            X.write_file(dir ++ "/" ++ key ++ ".d2", d2_view(m, v))
            out : String <- X.sh("d2 --layout elk --pad 40 " ++ dir ++ "/" ++ key ++ ".d2 " ++ dir ++ "/" ++ key ++ ".png 2>&1")
            IO.print(key ++ ": " ++ out)
            render_views(m, dir, rest)

def render(w: Workspace, +dir: String) -> IO(Unit):
  match w:
    case Workspace{_, _, m, vs}:
      render_views(m, dir, vs)
