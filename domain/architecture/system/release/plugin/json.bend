import Base
import bend-net-json@0.3.0.0/json.bend as Json

# Building a plugin's JSON: optional keys are left out when absent.

def with.go(kvs: List<&2, Sigma<&2, &2, String, _ => Json.Val>>, m: Map<&2, Json.Val>) -> Map<&2, Json.Val>:
  match kvs:
    case []:
      m
    case (k, v) <> rest:
      with.go(rest, Map.set(&2, Json.Val, m, k, v))

def obj(kvs: List<&2, Sigma<&2, &2, String, _ => Json.Val>>) -> Json.Val:
  Json.Obj{with.go(kvs, Map.new(&2, Json.Val))}

# A key, or nothing when its value is absent.
def opt(+k: String, m: Maybe<&2, Json.Val>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match m:
    case Some{v}:
      [(k, v)]
    case None{}:
      []

def text(m: Maybe<&2, String>) -> Maybe<&2, Json.Val>:
  match m:
    case Some{s}:
      Some{Json.Str{s}}
    case None{}:
      None{}

def number(m: Maybe<&2, Nat>) -> Maybe<&2, Json.Val>:
  match m:
    case Some{n}:
      Some{Json.Num{Nat.show(n)}}
    case None{}:
      None{}

def flag(m: Maybe<&2, Bool>) -> Maybe<&2, Json.Val>:
  match m:
    case Some{b}:
      Some{Json.Flag{b}}
    case None{}:
      None{}

# A key that is true, or nothing: false is every flag's default.
def when_true(+k: String, b: Bool) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match b:
    case True{}:
      [(k, Json.Flag{True{}})]
    case False{}:
      []

def strs(xs: List<&2, String>) -> List<&2, Json.Val>:
  match xs:
    case []:
      []
    case x <> rest:
      Json.Str{x} <> strs(rest)

def texts(xs: List<&2, String>) -> Json.Val:
  Json.Arr{strs(xs)}

def cat(xss: List<&2, List<&2, Sigma<&2, &2, String, _ => Json.Val>>>) -> Json.Val:
  obj(List.concat(&2, Sigma<&2, &2, String, _ => Json.Val>, xss))

