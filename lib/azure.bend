import Base
import near-architecture@0.9.1.0/arc.bend as Arc

# Public metadata and effective ARM permission patterns only. No credential values.
type Resource is Data:
  Resource{name: String, kind: String, group: String, location: String}

type DeclaredResource is Data:
  DeclaredResource{name: String, kind: String, group: String}

type Permission is Data:
  Permission{scope: String, actions: List<&2, String>, not_actions: List<&2, String>}

type Project is Data:
  Project{name: String}

type Repository is Data:
  Repository{name: String}

type Pipeline is Data:
  Pipeline{name: String, repository: String, yaml: String}

type ServiceConnection is Data:
  ServiceConnection{name: String, kind: String, scheme: String}

type Identity is Data:
  Identity{profile: String, name: String}

def same_resource(a: Resource, b: Resource) -> Bool:
  match a b:
    case Resource{an, ak, ag, al} Resource{bn, bk, bg, bl}:
      String.eq(an, bn) && String.eq(ak, bk) && String.eq(ag, bg) && String.eq(al, bl)

def contains_resource(+x: Resource, xs: List<&2, Resource>) -> Bool:
  match xs:
    case []:
      False{}
    case y <> rest:
      same_resource(x, y) || contains_resource(x, rest)

def all_resources_in(xs: List<&2, Resource>, +ys: List<&2, Resource>) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      contains_resource(x, ys) && all_resources_in(rest, ys)

def resources_equal(+a: List<&2, Resource>, +b: List<&2, Resource>) -> Bool:
  all_resources_in(a, b) && all_resources_in(b, a)

def declared_matches(d: DeclaredResource, r: Resource) -> Bool:
  match d r:
    case DeclaredResource{dn, dk, dg} Resource{rn, rk, rg, _}:
      String.eq(dn, rn) && String.eq(dk, rk) && String.eq(dg, rg)

def resource_declared(+r: Resource, ds: List<&2, DeclaredResource>) -> Bool:
  match ds:
    case []: False{}
    case d <> rest: declared_matches(d, r) || resource_declared(r, rest)

def declaration_exists(+d: DeclaredResource, rs: List<&2, Resource>) -> Bool:
  match rs:
    case []: False{}
    case r <> rest: declared_matches(d, r) || declaration_exists(d, rest)

def all_observed_declared(rs: List<&2, Resource>, +ds: List<&2, DeclaredResource>) -> Bool:
  match rs:
    case []: True{}
    case r <> rest: resource_declared(r, ds) && all_observed_declared(rest, ds)

def all_declared_observed(ds: List<&2, DeclaredResource>, +rs: List<&2, Resource>) -> Bool:
  match ds:
    case []: True{}
    case d <> rest: declaration_exists(d, rs) && all_declared_observed(rest, rs)

def inventory_equal(+ds: List<&2, DeclaredResource>, +rs: List<&2, Resource>) -> Bool:
  all_observed_declared(rs, ds) && all_declared_observed(ds, rs)

def declaration_names(ds: List<&2, DeclaredResource>) -> List<&2, String>:
  match ds:
    case []: []
    case d <> rest:
      match d:
        case DeclaredResource{name, _, _}: name <> declaration_names(rest)

def contains_name(+name: String, xs: List<&2, String>) -> Bool:
  match xs:
    case []: False{}
    case x <> rest: String.eq(name, x) || contains_name(name, rest)

def all_names_in(xs: List<&2, String>, +ys: List<&2, String>) -> Bool:
  match xs:
    case []: True{}
    case x <> rest: contains_name(x, ys) && all_names_in(rest, ys)

def scopes_equal(+declared: List<&2, String>, +observed: List<&2, String>) -> Bool:
  all_names_in(declared, observed) && all_names_in(observed, declared)

# ARM patterns use '*' for zero or more characters; matching is case insensitive.
def glob_chars(+ps: List<&2, Char>, +vs: List<&2, Char>) -> Bool:
  match ps:
    case []:
      match vs:
        case []: True{}
        case _ <> _: False{}
    case p <> rest:
      match p:
        case '*':
          match vs:
            case []: glob_chars(rest, [])
            case v <> tail: glob_chars(rest, v <> tail) || glob_chars('*' <> rest, tail)
        case _:
          match vs:
            case []: False{}
            case v <> tail: Char.is_eq(p, v) && glob_chars(rest, tail)

def glob(pattern: String, value: String) -> Bool:
  glob_chars(String.to_list(String.to_lower(pattern)), String.to_list(String.to_lower(value)))

# A wildcard pattern is covered only by the same pattern or '*'. This conservative
# rule avoids claiming that overlapping wildcards grant exactly equal permissions.
def covers(+want: String, +actual: String) -> Bool:
  String.eq(String.to_lower(want), String.to_lower(actual)) ||
  String.eq(want, "*") ||
  (Bool.not(String.contains(actual, "*")) && glob(want, actual))

def covered(+action: String, patterns: List<&2, String>) -> Bool:
  match patterns:
    case []:
      False{}
    case p <> rest:
      covers(p, action) || covered(action, rest)

def every_covered(xs: List<&2, String>, +by: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      covered(x, by) && every_covered(rest, by)

def actions_if(hit: Bool, acts: List<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match hit:
    case True{}: List.append(&2, String, acts, rest)
    case False{}: rest

def scope_actions(+scope: String, xs: List<&2, Permission>) -> List<&2, String>:
  match xs:
    case []:
      []
    case p <> rest:
      match p:
        case Permission{s, acts, _}:
          actions_if(String.eq(scope, s), acts, scope_actions(scope, rest))

def no_exclusions(+scope: String, xs: List<&2, Permission>) -> Bool:
  match xs:
    case []:
      True{}
    case p <> rest:
      match p:
        case Permission{s, _, exclusions}:
          (Bool.not(String.eq(scope, s)) || List.is_empty(&2, String, exclusions)) && no_exclusions(scope, rest)

def permissions_equal(+scope: String, +want: List<&2, String>, +actual: List<&2, Permission>) -> Bool:
  +got : List<&2, String> = scope_actions(scope, actual)
  no_exclusions(scope, actual) && every_covered(got, want) && every_covered(want, got)

def in_domain(name: String, domain: String) -> Bool:
  String.ends_with(String.to_lower(name), "@" ++ String.to_lower(domain))

def identities_in_domain(xs: List<&2, Identity>, +domain: String) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      match x:
        case Identity{_, name}:
          in_domain(name, domain) && identities_in_domain(rest, domain)

def identity_names(xs: List<&2, Identity>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest:
      match x:
        case Identity{_, name}: name <> identity_names(rest)

# Permission minimality: on every resource group, `person` has exactly what the agreement grants
# there (nothing granted means no access at all).
def access_minimal(groups: List<&2, String>, +a: Arc.Agreement, +person: String, +actual: List<&2, Permission>) -> Bool:
  match groups:
    case []: True{}
    case +g <> rest: permissions_equal(g, Arc.granted(a, person, g), actual) && access_minimal(rest, a, person, actual)
