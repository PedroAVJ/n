import Base
import near-architecture@0.9.1.0/arc.bend as A

# A system as Markdown: a nested list of the nodes where it runs, each with its containers and their
# parts, in topological order (everything comes before what it links to), with every link as an arrow.
# Emojis mark the kind of node.

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

def without(+x: String, ys: List<&2, String>) -> List<&2, String>:
  match ys:
    case []:
      []
    case +y <> +rest:
      pick_l(String.eq(x, y), rest, y <> without(x, rest))

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

# ---- topological order: repeatedly take the first key nothing remaining points to ----
def blocked(+r: String, +rem: List<&2, String>, es: List<&2, A.Link>) -> Bool:
  match es:
    case []:
      False{}
    case e <> rest:
      match e:
        case A.Link{+a, b, _, _}:
          (String.eq(b, r) && Bool.not(String.eq(a, r)) && listed(a, rem)) || blocked(r, rem, rest)

def first_free(cands: List<&2, String>, +rem: List<&2, String>, +es: List<&2, A.Link>) -> String:
  match cands:
    case []:
      ""
    case +c <> rest:
      pick_s(Bool.not(blocked(c, rem, es)), c, first_free(rest, rem, es))

def next_key(+rem: List<&2, String>, +es: List<&2, A.Link>) -> String:
  pick_s(String.is_empty(first_free(rem, rem, es)), head_or(rem, ""), first_free(rem, rem, es))

def topo(fuel: Nat, +rem: List<&2, String>, +es: List<&2, A.Link>) -> List<&2, String>:
  match fuel:
    case 0n:
      rem
    case 1n+k:
      match rem:
        case []:
          []
        case _ <> _:
          next_key(rem, es) <> topo(k, without(next_key(rem, es), rem), es)

# Links lifted to nodes (level 0n) or to containers (level 1n).
def lifted(ls: List<&2, A.Link>, +level: Nat, +s: A.System) -> List<&2, A.Link>:
  match ls:
    case []:
      []
    case l <> rest:
      match l:
        case A.Link{+a, +b, _, _}:
          A.Link{pick_s(Nat.is_eq(level, 0n), node_of(a, s), container_of(a, s)), pick_s(Nat.is_eq(level, 0n), node_of(b, s), container_of(b, s)), "", False{}} <> lifted(rest, level, s)

def node_keys(ns: List<&2, A.Node>) -> List<&2, String>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case A.Node{k, _, _, _}:
          k <> node_keys(rest)

def container_keys(cs: List<&2, A.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case A.Container{k, _, _, _, _, _, _, _, _, _, _, _}:
          k <> container_keys(rest)

# ---- rendering ----
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

def node_title(+k: String, ns: List<&2, A.Node>) -> String:
  match ns:
    case []:
      k
    case n <> rest:
      match n:
        case A.Node{nk, name, role, host}:
          pick_s(String.eq(k, nk), role_emoji(role, host) ++ " **" ++ name ++ "**", node_title(k, rest))

def targets(+k: String, ls: List<&2, A.Link>, +s: A.System) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> +rest:
      match l:
        case A.Link{a, +b, +label, _}:
          pick_l(String.eq(a, k), (name_of(b, s) ++ pick_s(String.is_empty(label), "", " (" ++ label ++ ")")) <> targets(k, rest, s), targets(k, rest, s))

def arrows(+k: String, +s: A.System) -> String:
  pick_s(String.is_empty(String.join(targets(k, A.links(s), s), "")), "", " → " ++ String.join(targets(k, A.links(s), s), ", "))

# Parts of container c that run on node n; with guest, parts on n whose container runs elsewhere.
def part_lines(ks: List<&2, String>, +c: String, +n: String, +guest: Bool, +s: A.System) -> String:
  match ks:
    case []:
      ""
    case +pk <> rest:
      pick_s(String.eq(part_field(pk, 2n, A.parts(s)), n) && pick_b(guest, Bool.not(String.eq(container_on(part_field(pk, 1n, A.parts(s)), A.containers(s)), n)), String.eq(part_field(pk, 1n, A.parts(s)), c)), pick_s(guest, "  - " ++ part_field(pk, 0n, A.parts(s)) ++ " (part of " ++ name_of(part_field(pk, 1n, A.parts(s)), s) ++ ")", "    - " ++ part_field(pk, 0n, A.parts(s))) ++ arrows(pk, s) ++ "\n", "") ++ part_lines(rest, c, n, guest, s)

def part_keys(ps: List<&2, A.Part>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case A.Part{k, _, _, _, _}:
          k <> part_keys(rest)

def ordered_parts(+s: A.System) -> List<&2, String>:
  topo(List.length(&2, String, part_keys(A.parts(s))), part_keys(A.parts(s)), A.links(s))

def container_lines(cs: List<&2, String>, +n: String, +s: A.System) -> String:
  match cs:
    case []:
      ""
    case +c <> rest:
      pick_s(String.eq(container_on(c, A.containers(s)), n), "  - " ++ name_of(c, s) ++ arrows(c, s) ++ "\n" ++ part_lines(ordered_parts(s), c, n, False{}, s), "") ++ container_lines(rest, n, s)

def node_lines(ns: List<&2, String>, +cs: List<&2, String>, +s: A.System) -> String:
  match ns:
    case []:
      ""
    case +n <> rest:
      "- " ++ node_title(n, A.nodes(s)) ++ "\n" ++ container_lines(cs, n, s) ++ part_lines(ordered_parts(s), "", n, True{}, s) ++ node_lines(rest, cs, s)

def markdown(+s: A.System) -> String:
  node_lines(topo(List.length(&2, String, node_keys(A.nodes(s))), node_keys(A.nodes(s)), lifted(A.links(s), 0n, s)), topo(List.length(&2, String, container_keys(A.containers(s))), container_keys(A.containers(s)), lifted(A.links(s), 1n, s)), s)
