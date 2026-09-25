import Base
import near-architecture@0.9.1.0/arc.bend as A

# A system as a graph with one start, and its Markdown serialization.
# The graph: every container and part, joined by the links and by containment (a container holds its
# parts). It must have exactly one start, the one item nothing points to, and reach everything from it.
# Rendering requires that as a proof, so a system with two starts does not type-check.

def pick_s(c: Bool, a: String, b: String) -> String:
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

def pick_l(c: Bool, a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_b(c: Bool, a: Bool, b: Bool) -> Bool:
  match c:
    case True{}:
      a
    case False{}:
      b

def head_or(xs: List<&2, String>, d: String) -> String:
  match xs:
    case []:
      d
    case x <> _:
      x

# ---- lookups by key ----
def container_on(+k: String, cs: List<&2, A.Container>) -> String:
  match cs:
    case []:
      ""
    case c <> rest:
      match c:
        case A.Container{ck, _, _, _, on, _, _, _, _, _, _, _}:
          pick_s(String.eq(k, ck), on, container_on(k, rest))

def container_name(+k: String, cs: List<&2, A.Container>) -> String:
  match cs:
    case []:
      ""
    case c <> rest:
      match c:
        case A.Container{ck, n, _, _, _, _, _, _, _, _, _, _}:
          pick_s(String.eq(k, ck), n, container_name(k, rest))

def part_field(+k: String, +which: Nat, ps: List<&2, A.Part>) -> String:
  match ps:
    case []:
      ""
    case p <> rest:
      match p:
        case A.Part{pk, n, _, i, on}:
          pick_s(String.eq(k, pk), pick_s(Nat.is_eq(which, 0n), n, pick_s(Nat.is_eq(which, 1n), i, on)), part_field(k, which, rest))

def node_of(+k: String, +s: A.System) -> String:
  pick_s(String.is_empty(container_on(k, A.containers(s))), part_field(k, 2n, A.parts(s)), container_on(k, A.containers(s)))

def container_of(+k: String, +s: A.System) -> String:
  pick_s(String.is_empty(container_on(k, A.containers(s))), part_field(k, 1n, A.parts(s)), k)

def name_of(+k: String, +s: A.System) -> String:
  pick_s(String.is_empty(container_name(k, A.containers(s))), part_field(k, 0n, A.parts(s)), container_name(k, A.containers(s)))

# ---- the graph ----
def container_keys(cs: List<&2, A.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case A.Container{k, _, _, _, _, _, _, _, _, _, _, _}:
          k <> container_keys(rest)

def part_keys(ps: List<&2, A.Part>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case A.Part{k, _, _, _, _}:
          k <> part_keys(rest)

def containment(ps: List<&2, A.Part>) -> List<&2, A.Link>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case A.Part{k, _, _, i, _}:
          A.Link{i, k, "", False{}} <> containment(rest)

def items(+s: A.System) -> List<&2, String>:
  List.append(&2, String, container_keys(A.containers(s)), part_keys(A.parts(s)))

def edges(+s: A.System) -> List<&2, A.Link>:
  List.append(&2, A.Link, A.links(s), containment(A.parts(s)))

def has_in(+k: String, es: List<&2, A.Link>) -> Bool:
  match es:
    case []:
      False{}
    case e <> rest:
      match e:
        case A.Link{a, b, _, _}:
          (String.eq(b, k) && Bool.not(String.eq(a, k))) || has_in(k, rest)

# The items nothing points to.
def starts(ks: List<&2, String>, +es: List<&2, A.Link>) -> List<&2, String>:
  match ks:
    case []:
      []
    case +k <> +rest:
      pick_l(has_in(k, es), starts(rest, es), k <> starts(rest, es))

def outs(+k: String, es: List<&2, A.Link>) -> List<&2, String>:
  match es:
    case []:
      []
    case e <> +rest:
      match e:
        case A.Link{a, b, _, _}:
          pick_l(String.eq(a, k), b <> outs(k, rest), outs(k, rest))

def keep_new(known: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match known:
    case True{}:
      rest
    case False{}:
      x <> rest

def fresh(xs: List<&2, String>, +seen: List<&2, String>, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      acc
    case +x <> rest:
      fresh(rest, seen, keep_new(listed(x, seen) || listed(x, acc), x, acc))

def nth_key(xs: List<&2, String>, n: Nat) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match n:
        case 0n:
          x
        case 1n+m:
          nth_key(rest, m)

def reach(fuel: Nat, +i: Nat, +seen: List<&2, String>, +es: List<&2, A.Link>) -> List<&2, String>:
  match fuel:
    case 0n:
      seen
    case 1n+k:
      reach(k, 1n+i, List.append(&2, String, seen, fresh(outs(nth_key(seen, i), es), seen, [])), es)

def all_in(xs: List<&2, String>, +ys: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      listed(x, ys) && all_in(rest, ys)

# One start, and everything reachable from it.
def one_start(+s: A.System) -> Bool:
  Nat.is_eq(List.length(&2, String, starts(items(s), edges(s))), 1n) && all_in(items(s), reach(List.length(&2, String, items(s)), 0n, starts(items(s), edges(s)), edges(s)))

# ---- the tree it serializes to: the graph walked depth first from its start ----
type Line is Data:
  Line{depth: Nat, key: String, via: String}

def pick_lines(c: Bool, a: List<&2, Line>, b: List<&2, Line>) -> List<&2, Line>:
  match c:
    case True{}:
      a
    case False{}:
      b

def child_lines(+d: Nat, +k: String, es: List<&2, A.Link>) -> List<&2, Line>:
  match es:
    case []:
      []
    case e <> +rest:
      match e:
        case A.Link{a, b, label, _}:
          pick_lines(String.eq(a, k), Line{d, b, label} <> child_lines(d, k, rest), child_lines(d, k, rest))

def walk(+fuel: Nat, stack: List<&2, Line>, +seen: List<&2, String>, +es: List<&2, A.Link>) -> List<&2, Line>:
  match fuel:
    case 0n:
      []
    case 1n+f:
      match stack:
        case []:
          []
        case top <> +rest:
          match top:
            case Line{+d, +k, +via}:
              pick_lines(listed(k, seen), walk(f, rest, seen, es), Line{d, k, via} <> walk(f, List.append(&2, Line, child_lines(1n+d, k, es), rest), k <> seen, es))

# ---- serialization ----
def host_emoji(h: A.Host) -> String:
  match h:
    case A.Owned{_}:
      "🏠"
    case A.Cloud{_}:
      "☁️"
    case A.Other{}:
      "🖥️"

def role_emoji(r: A.NodeRole, h: A.Host) -> String:
  match r:
    case A.UserDevice{}:
      "📱"
    case A.Server{}:
      host_emoji(h)
    case A.Overlay{}:
      "🔒"
    case A.Outside{}:
      "🌐"

def node_label(+k: String, ns: List<&2, A.Node>) -> String:
  match ns:
    case []:
      k
    case n <> rest:
      match n:
        case A.Node{nk, name, role, host}:
          pick_s(String.eq(k, nk), role_emoji(role, host) ++ " " ++ name, node_label(k, rest))

def indent(d: Nat) -> String:
  match d:
    case 0n:
      ""
    case 1n+m:
      "  " ++ indent(m)

def render(ls: List<&2, Line>, +s: A.System) -> String:
  match ls:
    case []:
      ""
    case l <> rest:
      match l:
        case Line{d, +k, +via}:
          indent(d) ++ "- **" ++ name_of(k, s) ++ "**" ++ pick_s(String.is_empty(via), "", " (" ++ via ++ ")") ++ " · " ++ node_label(node_of(k, s), A.nodes(s)) ++ "\n" ++ render(rest, s)

def markdown(+s: A.System, ok: {one_start(s) == True{} : Bool}) -> String:
  render(walk(Nat.mul(1n+List.length(&2, String, items(s)), 1n+List.length(&2, A.Link, edges(s))), [Line{0n, head_or(starts(items(s), edges(s)), ""), ""}], [], edges(s)), s)
