import Base
import ../rose/type.bend as R
import ../rose/ops.bend as RO
import ./edge/type.bend as E
import ./type.bend as C

def keys(-N: Data, c: C.Compound<N>) -> List<&2, String>:
  match c:
    case C.Compound{rs, _}:
      RO.keys(N, rs)

def edges(-N: Data, c: C.Compound<N>) -> List<&2, E.Edge>:
  match c:
    case C.Compound{_, es}:
      es

# ---- invariants ----
def has(+ks: List<&2, String>, +k: String) -> Bool:
  List.contains(~String, ~String.eq, ks, k)

def ends_resolve(es: List<&2, E.Edge>, +ks: List<&2, String>) -> Bool:
  match es:
    case []:
      True{}
    case e <> rest:
      match e:
        case E.Edge{a, b, _, _}:
          has(ks, a) && has(ks, b) && ends_resolve(rest, ks)

# Every edge joins two keys the forest has.
def resolves(-N: Data, +c: C.Compound<N>) -> Bool:
  ends_resolve(edges(N, c), keys(N, c))

def distinct(+ks: List<&2, String>) -> Bool:
  Nat.is_eq(Set.size(Set.from_list(ks)), List.length(&2, String, ks))

# No key names two things.
def unique(-N: Data, c: C.Compound<N>) -> Bool:
  distinct(keys(N, c))

# ---- lifting: an edge as seen when only some keys are visible ----
# A key shows as itself when visible, else as its nearest visible ancestor, else not at all ("").
def above_of(+k: String, ps: List<&2, RO.Place>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case RO.Place{pk, ab}:
          Bool.pick(List<&2, String>, String.eq(k, pk), ab, above_of(k, rest))

def visible_or(hit: Bool, +k: String, rest: String) -> String:
  match hit:
    case True{}:
      k
    case False{}:
      rest

def first_visible(cands: List<&2, String>, +visible: List<&2, String>) -> String:
  match cands:
    case []:
      ""
    case +c <> rest:
      visible_or(has(visible, c), c, first_visible(rest, visible))

def shown_as(+k: String, +ps: List<&2, RO.Place>, +visible: List<&2, String>) -> String:
  first_visible(k <> above_of(k, ps), visible)

def drawn(+a: String, +b: String, es: List<&2, E.Edge>) -> Bool:
  match es:
    case []:
      False{}
    case e <> rest:
      match e:
        case E.Edge{x, y, _, _}:
          (String.eq(a, x) && String.eq(b, y)) || drawn(a, b, rest)

def keep(c: Bool, e: E.Edge, rest: List<&2, E.Edge>) -> List<&2, E.Edge>:
  match c:
    case True{}:
      e <> rest
    case False{}:
      rest

# An edge is kept when both ends show, as two different things, not already drawn.
def keep_edge(+a: String, +b: String, l: String, t: String, +rest: List<&2, E.Edge>) -> List<&2, E.Edge>:
  keep(Bool.not(String.is_empty(a)) && Bool.not(String.is_empty(b)) && Bool.not(String.eq(a, b)) && Bool.not(drawn(a, b, rest)), E.Edge{a, b, l, t}, rest)

def lift_edges(es: List<&2, E.Edge>, +ps: List<&2, RO.Place>, +visible: List<&2, String>) -> List<&2, E.Edge>:
  match es:
    case []:
      []
    case e <> rest:
      match e:
        case E.Edge{a, b, l, t}:
          keep_edge(shown_as(a, ps, visible), shown_as(b, ps, visible), l, t, lift_edges(rest, ps, visible))

# The compound's edges between the visible keys, each end moved up to what shows.
def lift(-N: Data, c: C.Compound<N>, +visible: List<&2, String>) -> List<&2, E.Edge>:
  match c:
    case C.Compound{rs, es}:
      lift_edges(List.reverse(&2, E.Edge, es), RO.places(N, rs, []), visible)
