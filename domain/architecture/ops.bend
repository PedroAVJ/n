import Base
import ../../general/rose/type.bend as R
import ../../general/rose/ops.bend as RO
import ../../general/compound/type.bend as C
import ../../general/compound/ops.bend as CO
import ../../general/compound/edge/type.bend as E
import ./relationship/type.bend as Rel
import ./system/type.bend as S
import ./system/container/type.bend as Ct
import ./system/container/component/type.bend as Co
import ./system/deployment/type.bend as D
import ./environment/type.bend as En
import ./environment/party/type.bend as P
import ./environment/external/type.bend as X
import ./environment/constraint/type.bend as K
import ./system/release/ops.bend as RlO
import ./type.bend as A

# ---- the architecture as a compound graph: the system's tree, the environment's leaves, and every
# element's relationships as edges from it ----
def uses_edges(+src: String, us: List<&2, Rel.Relationship>) -> List<&2, E.Edge>:
  match us:
    case []:
      []
    case u <> rest:
      match u:
        case Rel.Relationship{d, desc, t}:
          E.Edge{src, d, desc, t} <> uses_edges(src, rest)

def component_roses(cs: List<&2, Co.Component>) -> List<&2, R.Rose<A.Element>>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Co.Component{k, n, d, t, _}:
          R.Rose{k, A.Element{n, d, t, A.ComponentLevel{}}, []} <> component_roses(rest)

def component_edges(cs: List<&2, Co.Component>) -> List<&2, E.Edge>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Co.Component{k, _, _, _, us}:
          List.append(&2, E.Edge, uses_edges(k, us), component_edges(rest))

def container_roses(cs: List<&2, Ct.Container>) -> List<&2, R.Rose<A.Element>>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{k, n, d, t, _, _, _, comps, _}:
          R.Rose{k, A.Element{n, d, t, A.ContainerLevel{}}, component_roses(comps)} <> container_roses(rest)

def container_edges(cs: List<&2, Ct.Container>) -> List<&2, E.Edge>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{+k, _, _, _, _, _, _, comps, us}:
          List.append(&2, E.Edge, uses_edges(k, us), List.append(&2, E.Edge, component_edges(comps), container_edges(rest)))

def party_rose(p: P.Party) -> R.Rose<A.Element>:
  match p:
    case P.Human{k, n, d, _}:
      R.Rose{k, A.Element{n, d, "", A.PersonLevel{}}, []}
    case P.Organization{k, n, d, _, _}:
      R.Rose{k, A.Element{n, d, "", A.PersonLevel{}}, []}
    case P.Team{k, n, d, _, _}:
      R.Rose{k, A.Element{n, d, "", A.PersonLevel{}}, []}

def party_edges(p: P.Party) -> List<&2, E.Edge>:
  match p:
    case P.Human{k, _, _, us}:
      uses_edges(k, us)
    case P.Organization{k, _, _, _, us}:
      uses_edges(k, us)
    case P.Team{k, _, _, _, us}:
      uses_edges(k, us)

def parties_roses(ps: List<&2, P.Party>) -> List<&2, R.Rose<A.Element>>:
  match ps:
    case []:
      []
    case p <> rest:
      party_rose(p) <> parties_roses(rest)

def parties_edges(ps: List<&2, P.Party>) -> List<&2, E.Edge>:
  match ps:
    case []:
      []
    case p <> rest:
      List.append(&2, E.Edge, party_edges(p), parties_edges(rest))

def external_roses(xs: List<&2, X.External>) -> List<&2, R.Rose<A.Element>>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case X.External{k, n, d, _}:
          R.Rose{k, A.Element{n, d, "", A.ExternalLevel{}}, []} <> external_roses(rest)

def external_edges(xs: List<&2, X.External>) -> List<&2, E.Edge>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case X.External{k, _, _, us}:
          List.append(&2, E.Edge, uses_edges(k, us), external_edges(rest))

def with_env(sys: R.Rose<A.Element>, +cs: List<&2, Ct.Container>, env: En.Environment) -> C.Compound<A.Element>:
  match env:
    case En.Environment{+ps, +xs, _}:
      C.Compound{sys <> List.append(&2, R.Rose<A.Element>, parties_roses(ps), external_roses(xs)),
        List.append(&2, E.Edge, container_edges(cs), List.append(&2, E.Edge, parties_edges(ps), external_edges(xs)))}

def to_compound(a: A.Architecture) -> C.Compound<A.Element>:
  match a:
    case A.Architecture{s, env}:
      match s:
        case S.System{k, n, d, +cs, _, _}:
          with_env(R.Rose{k, A.Element{n, d, "", A.SystemLevel{}}, container_roses(cs)}, cs, env)

# ---- looking things up ----
def system(a: A.Architecture) -> S.System:
  match a:
    case A.Architecture{s, _}:
      s

def system_key(a: A.Architecture) -> String:
  match a:
    case A.Architecture{s, _}:
      match s:
        case S.System{k, _, _, _, _, _}:
          k

def containers(a: A.Architecture) -> List<&2, Ct.Container>:
  match a:
    case A.Architecture{s, _}:
      match s:
        case S.System{_, _, _, cs, _, _}:
          cs

def deployment(a: A.Architecture) -> List<&2, D.Node>:
  match a:
    case A.Architecture{s, _}:
      match s:
        case S.System{_, _, _, _, ns, _}:
          ns

def keys(a: A.Architecture) -> List<&2, String>:
  CO.keys(A.Element, to_compound(a))

def container_keys(cs: List<&2, Ct.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{k, _, _, _, _, _, _, _, _}:
          k <> container_keys(rest)

def component_keys(cs: List<&2, Co.Component>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Co.Component{k, _, _, _, _}:
          k <> component_keys(rest)

# Every component key in the system.
def all_component_keys(cs: List<&2, Ct.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{_, _, _, _, _, _, _, comps, _}:
          List.append(&2, String, component_keys(comps), all_component_keys(rest))

# The components inside one container.
def components_of(+k: String, cs: List<&2, Ct.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{ck, _, _, _, _, _, _, comps, _}:
          Bool.pick(List<&2, String>, String.eq(k, ck), component_keys(comps), components_of(k, rest))

def environment_keys(a: A.Architecture) -> List<&2, String>:
  match a:
    case A.Architecture{_, env}:
      match env:
        case En.Environment{ps, xs, _}:
          RO.keys(A.Element, List.append(&2, R.Rose<A.Element>, parties_roses(ps), external_roses(xs)))

# ---- well formed: keys are unique, every relationship and every instance names something that exists ----
def instances(ns: List<&2, D.Node>) -> List<&2, String>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case D.Node{_, _, _, _, kids, ins}:
          List.append(&2, String, ins, List.append(&2, String, instances(kids), instances(rest)))

def all_listed(xs: List<&2, String>, +ks: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      CO.has(ks, x) && all_listed(rest, ks)

def compound_ok(+c: C.Compound<A.Element>) -> Bool:
  CO.resolves(A.Element, c) && CO.unique(A.Element, c)

def well_formed(+a: A.Architecture) -> Bool:
  compound_ok(to_compound(a)) && all_listed(instances(deployment(a)), container_keys(containers(a)))

# ---- only our own containers are opened up into components ----
def ours(o: Ct.Ownership) -> Bool:
  match o:
    case Ct.Ours{}:
      True{}
    case Ct.Theirs{}:
      False{}

def components_ours(cs: List<&2, Ct.Container>) -> Bool:
  match cs:
    case []:
      True{}
    case c <> rest:
      match c:
        case Ct.Container{_, _, _, _, o, _, _, comps, _}:
          (List.is_empty(&2, Co.Component, comps) || ours(o)) && components_ours(rest)

# ---- on a server, everything is reachable only from the machine itself or over the tailnet ----
def private(e: Ct.Exposure) -> Bool:
  match e:
    case Ct.Local{}:
      True{}
    case Ct.Tailnet{}:
      True{}
    case _:
      False{}

def exposure_private(+k: String, cs: List<&2, Ct.Container>) -> Bool:
  match cs:
    case []:
      True{}
    case c <> rest:
      match c:
        case Ct.Container{ck, _, _, _, _, e, _, _, _}:
          Bool.pick(Bool, String.eq(k, ck), private(e), exposure_private(k, rest))

def all_private(ins: List<&2, String>, +cs: List<&2, Ct.Container>) -> Bool:
  match ins:
    case []:
      True{}
    case i <> rest:
      exposure_private(i, cs) && all_private(rest, cs)

def is_server(r: D.Role) -> Bool:
  match r:
    case D.Server{}:
      True{}
    case D.Device{}:
      False{}

def nodes_private(ns: List<&2, D.Node>, +cs: List<&2, Ct.Container>) -> Bool:
  match ns:
    case []:
      True{}
    case n <> rest:
      match n:
        case D.Node{_, _, _, r, kids, ins}:
          (Bool.not(is_server(r)) || all_private(ins, cs)) && nodes_private(kids, cs) && nodes_private(rest, cs)

def servers_private(+a: A.Architecture) -> Bool:
  nodes_private(deployment(a), containers(a))

# ---- open source: a system its environment requires to be open source publishes from a public repository ----
def open_source_required(ks: List<&2, K.Constraint>) -> Bool:
  match ks:
    case []:
      False{}
    case k <> rest:
      match k:
        case K.OpenSource{}:
          True{}
        case K.RunsOn{_}:
          open_source_required(rest)

def open_source(a: A.Architecture) -> Bool:
  match a:
    case A.Architecture{s, env}:
      match s env:
        case S.System{_, _, _, _, _, r} En.Environment{_, _, ks}:
          Bool.not(open_source_required(ks)) || RlO.is_public(r)
