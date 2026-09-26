import Base
import ./type.bend as D

# ---- what a deploy breaks: compared with what was deployed before (its address and stores) ----
def address(d: D.Deployment) -> String:
  match d:
    case D.Deployment{a, _, _, _}:
      a

def stores(d: D.Deployment) -> List<&2, String>:
  match d:
    case D.Deployment{_, ss, _, _}:
      ss

def accepted(d: D.Deployment) -> List<&2, D.Break>:
  match d:
    case D.Deployment{_, _, acc, _}:
      acc

def keep_break(present: Bool, +o: String, rest: List<&2, D.Break>) -> List<&2, D.Break>:
  match present:
    case True{}:
      rest
    case False{}:
      D.StoreRemoved{o} <> rest

def removed(olds: List<&2, String>, +news: List<&2, String>) -> List<&2, D.Break>:
  match olds:
    case []:
      []
    case +o <> rest:
      keep_break(List.contains(~String, ~String.eq, news, o), o, removed(rest, news))

# The address changing, then each store the new deployment drops. A first deploy (no address before) breaks nothing.
def breaks(+before: String, olds: List<&2, String>, +d: D.Deployment) -> List<&2, D.Break>:
  List.append(&2, D.Break,
    Bool.pick(List<&2, D.Break>, String.is_empty(before) || String.eq(before, address(d)), [], [D.AddressChanged{}]),
    removed(olds, stores(d)))

def break_eq(a: D.Break, b: D.Break) -> Bool:
  match a b:
    case D.AddressChanged{} D.AddressChanged{}:
      True{}
    case D.StoreRemoved{x} D.StoreRemoved{y}:
      String.eq(x, y)
    case _ _:
      False{}

def breaks_eq(a: List<&2, D.Break>, b: List<&2, D.Break>) -> Bool:
  match a:
    case []:
      List.is_empty(&2, D.Break, b)
    case x <> xs:
      match b:
        case []:
          False{}
        case y <> ys:
          break_eq(x, y) && breaks_eq(xs, ys)

def show_break(b: D.Break) -> String:
  match b:
    case D.AddressChanged{}:
      "the address changes"
    case D.StoreRemoved{n}:
      "store " ++ n ++ " is removed"

def shown(bs: List<&2, D.Break>) -> List<&2, String>:
  match bs:
    case []:
      []
    case b <> rest:
      show_break(b) <> shown(rest)

def show_breaks(bs: List<&2, D.Break>) -> String:
  String.join(shown(bs), ", ")

def store_lines(ss: List<&2, String>) -> String:
  match ss:
    case []:
      ""
    case s <> rest:
      "store " ++ s ++ "\n" ++ store_lines(rest)

# What a deploy records as deployed: the address, then one store per line.
def record(+d: D.Deployment) -> String:
  "address " ++ address(d) ++ "\n" ++ store_lines(stores(d))

def keep_rest(c: Bool, +prefix: String, l: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      String.drop(l, String.length(prefix)) <> rest
    case False{}:
      rest

# The lines that start with a prefix, without it.
def after(+prefix: String, ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      keep_rest(String.starts_with(l, prefix), prefix, l, after(prefix, rest))

# The address and stores in a record ("" and [] when nothing was deployed).
def recorded_address(+text: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, after("address ", String.lines(text))), "")

def recorded_stores(+text: String) -> List<&2, String>:
  after("store ", String.lines(text))
