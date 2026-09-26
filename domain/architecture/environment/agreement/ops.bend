import Base
import ./type.bend as G

def same_identity(+a: String, +b: String) -> Bool:
  String.eq(String.to_lower(a), String.to_lower(b))

def in_domain(+identity: String, +domain: String) -> Bool:
  String.ends_with(String.to_lower(identity), "@" ++ String.to_lower(domain))

def keep_if(c: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      x <> rest
    case False{}:
      rest

# ---- the people: identities in the organization's directory domain ----
def outside.go(xs: List<&2, G.Person>, +domain: String) -> List<&2, String>:
  match xs:
    case []:
      []
    case G.Person{_, +identity} <> rest:
      keep_if(Bool.not(in_domain(identity, domain)), identity, outside.go(rest, domain))

# The people's identities that are not in the organization's directory domain.
def outside_domain(a: G.Agreement) -> List<&2, String>:
  match a:
    case G.Agreement{+domain, people, _, _}:
      outside.go(people, domain)

# Every person's identity is in the organization's directory domain.
def people_in_domain(a: G.Agreement) -> Bool:
  List.is_empty(&2, String, outside_domain(a))

# The key of the person with this identity (case insensitive), or "" when none has it.
def person_of.go(xs: List<&2, G.Person>, +identity: String) -> String:
  match xs:
    case []:
      ""
    case G.Person{key, +id} <> rest:
      Bool.pick(String, same_identity(identity, id), key, person_of.go(rest, identity))

def person_of(a: G.Agreement, +identity: String) -> String:
  match a:
    case G.Agreement{_, people, _, _}:
      person_of.go(people, identity)

# ---- the identities in use ----
def unknown.go(ids: List<&2, String>, +xs: List<&2, G.Person>) -> List<&2, String>:
  match ids:
    case []:
      []
    case +id <> rest:
      keep_if(String.is_empty(person_of.go(xs, id)), id, unknown.go(rest, xs))

# The identities in use that are none of the agreement's people.
def unknown_identities(ids: List<&2, String>, a: G.Agreement) -> List<&2, String>:
  match a:
    case G.Agreement{_, +people, _, _}:
      unknown.go(ids, people)

# Every identity actually in use is one of the agreement's people.
def identities_known(ids: List<&2, String>, a: G.Agreement) -> Bool:
  List.is_empty(&2, String, unknown_identities(ids, a))

# ---- grants ----
def granted.go(xs: List<&2, G.Grant>, +person: String, +scope: String) -> List<&2, String>:
  match xs:
    case []:
      []
    case G.Grant{+p, +sc, acts} <> rest:
      Bool.pick(List<&2, String>, String.eq(person, p) && String.eq(scope, sc), acts, granted.go(rest, person, scope))

# What `person` is granted on `scope`; [] when nothing is granted there.
def granted(a: G.Agreement, +person: String, +scope: String) -> List<&2, String>:
  match a:
    case G.Agreement{_, _, grants, _}:
      granted.go(grants, person, scope)
