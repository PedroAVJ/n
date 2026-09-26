import Base
import ./type.bend as Az
import ../../plan/type.bend as P
import ../../../environment/agreement/type.bend as G
import ../../../environment/agreement/ops.bend as GO

def keep_if(c: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      x <> rest
    case False{}:
      rest

# ---- resources: what Azure has against what the system declares ----
def same(a: Az.Resource, b: Az.Resource) -> Bool:
  match a b:
    case Az.Resource{an, ak, ag} Az.Resource{bn, bk, bg}:
      String.eq(an, bn) && String.eq(ak, bk) && String.eq(ag, bg)

def listed(+r: Az.Resource, rs: List<&2, Az.Resource>) -> Bool:
  match rs:
    case []:
      False{}
    case x <> rest:
      same(r, x) || listed(r, rest)

def keep_resource(c: Bool, r: Az.Resource, rest: List<&2, Az.Resource>) -> List<&2, Az.Resource>:
  match c:
    case True{}:
      r <> rest
    case False{}:
      rest

# The resources in `xs` that are not in `ys` (same name, type and resource group).
def absent(xs: List<&2, Az.Resource>, +ys: List<&2, Az.Resource>) -> List<&2, Az.Resource>:
  match xs:
    case []:
      []
    case +r <> rest:
      keep_resource(Bool.not(listed(r, ys)), r, absent(rest, ys))

# What Azure has that the system does not declare.
def undeclared(observed: List<&2, Az.Resource>, +declared: List<&2, Az.Resource>) -> List<&2, Az.Resource>:
  absent(observed, declared)

# What the system declares that Azure does not have.
def missing(declared: List<&2, Az.Resource>, +observed: List<&2, Az.Resource>) -> List<&2, Az.Resource>:
  absent(declared, observed)

def show(r: Az.Resource) -> String:
  match r:
    case Az.Resource{n, k, g}:
      n ++ " (" ++ k ++ " in " ++ g ++ ")"

def shown(rs: List<&2, Az.Resource>) -> List<&2, String>:
  match rs:
    case []:
      []
    case r <> rest:
      show(r) <> shown(rest)

# ---- permissions ----
# ARM patterns use '*' for zero or more characters; matching is case insensitive.
def glob_chars(+ps: List<&2, Char>, +vs: List<&2, Char>) -> Bool:
  match ps:
    case []:
      match vs:
        case []:
          True{}
        case _ <> _:
          False{}
    case p <> rest:
      match p:
        case '*':
          match vs:
            case []:
              glob_chars(rest, [])
            case v <> tail:
              glob_chars(rest, v <> tail) || glob_chars('*' <> rest, tail)
        case _:
          match vs:
            case []:
              False{}
            case v <> tail:
              Char.is_eq(p, v) && glob_chars(rest, tail)

def glob(pattern: String, value: String) -> Bool:
  glob_chars(String.to_list(String.to_lower(pattern)), String.to_list(String.to_lower(value)))

# A wildcard pattern is covered only by the same pattern or '*'. This conservative rule avoids claiming
# that overlapping wildcards grant exactly equal permissions.
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
    case True{}:
      List.append(&2, String, acts, rest)
    case False{}:
      rest

def scope_actions(+scope: String, xs: List<&2, Az.Permission>) -> List<&2, String>:
  match xs:
    case []:
      []
    case Az.Permission{+s, acts, _} <> rest:
      actions_if(String.eq(scope, s), acts, scope_actions(scope, rest))

def no_exclusions(+scope: String, xs: List<&2, Az.Permission>) -> Bool:
  match xs:
    case []:
      True{}
    case Az.Permission{+s, _, exclusions} <> rest:
      (Bool.not(String.eq(scope, s)) || List.is_empty(&2, String, exclusions)) && no_exclusions(scope, rest)

# Whether the permissions on `scope` are exactly `want`, with nothing excluded.
def exact(+scope: String, +want: List<&2, String>, +actual: List<&2, Az.Permission>) -> Bool:
  +got = scope_actions(scope, actual)
  no_exclusions(scope, actual) && every_covered(got, want) && every_covered(want, got)

# The resource groups where `person` has other than exactly what the agreement grants there (nothing
# granted means no access at all).
def not_minimal(groups: List<&2, String>, +a: G.Agreement, +person: String, +actual: List<&2, Az.Permission>) -> List<&2, String>:
  match groups:
    case []:
      []
    case +g <> rest:
      keep_if(Bool.not(exact(g, GO.granted(a, person, g), actual)), g, not_minimal(rest, a, person, actual))

# Permission minimality: on every resource group, `person` has exactly what the agreement grants there.
def access_minimal(groups: List<&2, String>, +a: G.Agreement, +person: String, +actual: List<&2, Az.Permission>) -> Bool:
  List.is_empty(&2, String, not_minimal(groups, a, person, actual))

# ---- identities ----
def identity_names(xs: List<&2, Az.Identity>) -> List<&2, String>:
  match xs:
    case []:
      []
    case Az.Identity{_, name} <> rest:
      name <> identity_names(rest)

# Who is signed in with this profile, or "" when no one is.
def signed_in(+profile: String, xs: List<&2, Az.Identity>) -> String:
  match xs:
    case []:
      ""
    case Az.Identity{+p, name} <> rest:
      Bool.pick(String, String.eq(profile, p), name, signed_in(profile, rest))

# ---- the steps ----
def blocked_if(+what: String, +xs: List<&2, String>, why: String) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, List.is_empty(&2, String, xs), [], [P.Blocked{what, why ++ String.join(xs, ", ")}])

def verdict(+what: String, +bs: List<&2, P.Step>) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, List.is_empty(&2, P.Step, bs), [P.Current{what}], bs)

def domain(a: G.Agreement) -> String:
  match a:
    case G.Agreement{d, _, _, _}:
      d

def judged(+what: String, +a: G.Agreement, +declared: List<&2, Az.Resource>, o: Az.Observed) -> List<&2, P.Step>:
  match o:
    case Az.Observed{+ids, +rs, gs, ps, +unread}:
      +user = signed_in("azure", ids)
      Bool.pick(List<&2, P.Step>, List.is_empty(&2, String, unread),
        verdict(what, List.concat(&2, P.Step, [
          blocked_if(what, shown(undeclared(rs, declared)), "undeclared resources: "),
          blocked_if(what, shown(missing(declared, rs)), "declared resources missing: "),
          blocked_if(what, GO.unknown_identities(identity_names(ids), a), "identities not in the agreement: "),
          blocked_if(what, GO.outside_domain(a), "people outside the directory domain " ++ domain(a) ++ ": "),
          blocked_if(what, not_minimal(gs, a, GO.person_of(a, user), ps), user ++ " has other access than the agreement grants on: ")])),
        [P.Blocked{what, "cannot read " ++ String.join(unread, ", ") ++ " (is az installed and signed in?)"}])

# What Azure as observed means for the system: Current when every resource is declared and every
# declared resource exists, every identity in use is one of the agreement's people, every person is in
# its directory domain, and the signed-in user has exactly what the agreement grants; else Blocked.
def steps(az: Az.Azure, +a: G.Agreement, o: Az.Observed) -> List<&2, P.Step>:
  match az:
    case Az.Azure{org, project, declared}:
      judged("azure " ++ org ++ " " ++ project, a, declared, o)
