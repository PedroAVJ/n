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
import ./category/type.bend as K2
import ./environment/inventory/type.bend as I
import ./environment/inventory/ops.bend as InvO
import ./environment/agreement/type.bend as G
import ./system/deployment/host/type.bend as H
import ./system/deployment/nix_darwin/ops.bend as NDO
import ./system/deployment/nix_darwin/type.bend as ND
import ./system/deployment/nix_darwin/setting/ops.bend as StO
import ./type.bend as A

# ---- the architecture as a compound graph: the system's tree, the environment's leaves, and every
# element's relationships as edges from it ----
def uses_edges(+src: String, us: List<&2, Rel.Relationship>) -> List<&2, E.Edge>:
  match us:
    case []:
      []
    case u <> rest:
      match u:
        case Rel.Relationship{d, desc, t, _}:
          E.Edge{src, d, desc, t} <> uses_edges(src, rest)

def language_name(l: Co.Language) -> String:
  match l:
    case Co.Bend{}:
      "Bend 2"
    case Co.C{}:
      "C"
    case Co.Rust{}:
      "Rust"
    case Co.TypeScript{}:
      "TypeScript"
    case Co.JavaScript{}:
      "JavaScript"
    case Co.Python{}:
      "Python"
    case Co.Go{}:
      "Go"
    case Co.Opaque{}:
      ""

# A container's technology, as drawn: its frameworks and languages, else its vendors.
def technology(+vs: List<&2, String>, +fs: List<&2, String>, +ls: List<&2, String>) -> String:
  Bool.pick(String, List.is_empty(&2, String, List.append(&2, String, fs, ls)), String.join(vs, ", "), String.join(List.append(&2, String, fs, ls), ", "))

def component_roses(cs: List<&2, Co.Component>) -> List<&2, R.Rose<A.Element>>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Co.Component{k, n, d, l, _}:
          R.Rose{k, A.Element{n, d, language_name(l), A.ComponentLevel{}}, []} <> component_roses(rest)

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
        case Ct.Container{k, n, d, _, _, _, _, _, vs, fs, _, ls, _, comps, _}:
          R.Rose{k, A.Element{n, d, technology(vs, fs, ls), A.ContainerLevel{}}, component_roses(comps)} <> container_roses(rest)

def container_edges(cs: List<&2, Ct.Container>) -> List<&2, E.Edge>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{+k, _, _, _, _, _, _, _, _, _, _, _, _, comps, us}:
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
        case X.External{k, n, d, _, _, _, _, _}:
          R.Rose{k, A.Element{n, d, "", A.ExternalLevel{}}, []} <> external_roses(rest)

def external_edges(xs: List<&2, X.External>) -> List<&2, E.Edge>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case X.External{k, _, _, _, _, _, _, us}:
          List.append(&2, E.Edge, uses_edges(k, us), external_edges(rest))

def with_env(sys: R.Rose<A.Element>, +cs: List<&2, Ct.Container>, env: En.Environment) -> C.Compound<A.Element>:
  match env:
    case En.Environment{+ps, +xs, _, _, _}:
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

def deployment(a: A.Architecture) -> D.Deployment:
  match a:
    case A.Architecture{s, _}:
      match s:
        case S.System{_, _, _, _, dep, _}:
          dep

def deployment_nodes(d: D.Deployment) -> List<&2, D.Node>:
  match d:
    case D.Deployment{_, _, _, ns}:
      ns

# The machines, nested.
def nodes(a: A.Architecture) -> List<&2, D.Node>:
  deployment_nodes(deployment(a))

def keys(a: A.Architecture) -> List<&2, String>:
  CO.keys(A.Element, to_compound(a))

def container_keys(cs: List<&2, Ct.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{k, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
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
        case Ct.Container{_, _, _, _, _, _, _, _, _, _, _, _, _, comps, _}:
          List.append(&2, String, component_keys(comps), all_component_keys(rest))

# The components inside one container.
def components_of(+k: String, cs: List<&2, Ct.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{ck, _, _, _, _, _, _, _, _, _, _, _, _, comps, _}:
          Bool.pick(List<&2, String>, String.eq(k, ck), component_keys(comps), components_of(k, rest))

def environment_keys(a: A.Architecture) -> List<&2, String>:
  match a:
    case A.Architecture{_, env}:
      match env:
        case En.Environment{ps, xs, _, _, _}:
          RO.keys(A.Element, List.append(&2, R.Rose<A.Element>, parties_roses(ps), external_roses(xs)))

# ---- well formed: keys are unique, every relationship and every instance names something that exists ----
def instances(ns: List<&2, D.Node>) -> List<&2, String>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case D.Node{_, _, _, _, _, _, kids, ins}:
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
  compound_ok(to_compound(a)) && all_listed(instances(nodes(a)), container_keys(containers(a)))

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
        case Ct.Container{_, _, _, _, o, _, _, _, _, _, _, _, _, comps, _}:
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
        case Ct.Container{ck, _, _, _, _, e, _, _, _, _, _, _, _, _, _}:
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
        case D.Node{_, _, _, r, _, _, kids, ins}:
          (Bool.not(is_server(r)) || all_private(ins, cs)) && nodes_private(kids, cs) && nodes_private(rest, cs)

def servers_private(+a: A.Architecture) -> Bool:
  nodes_private(nodes(a), containers(a))

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
        case S.System{_, _, _, _, _, r} En.Environment{_, _, ks, _, _}:
          Bool.not(open_source_required(ks)) || RlO.is_public(r)

# ---- where each key runs: the containers on server nodes and on device nodes ----
def is_device(r: D.Role) -> Bool:
  match r:
    case D.Device{}:
      True{}
    case D.Server{}:
      False{}

def keep_all(c: Bool, xs: List<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      List.append(&2, String, xs, rest)
    case False{}:
      rest

def on_servers(ns: List<&2, D.Node>) -> List<&2, String>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case D.Node{_, _, _, r, _, _, kids, ins}:
          keep_all(is_server(r), ins, List.append(&2, String, on_servers(kids), on_servers(rest)))

def on_devices(ns: List<&2, D.Node>) -> List<&2, String>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case D.Node{_, _, _, r, _, _, kids, ins}:
          keep_all(is_device(r), ins, List.append(&2, String, on_devices(kids), on_devices(rest)))

# The container a key belongs to: itself, or the one its component sits in, else the key itself.
def home(+k: String, cs: List<&2, Ct.Container>) -> String:
  match cs:
    case []:
      k
    case c <> rest:
      match c:
        case Ct.Container{+ck, _, _, _, _, _, _, _, _, _, _, _, _, comps, _}:
          Bool.pick(String, String.eq(k, ck) || CO.has(component_keys(comps), k), ck, home(k, rest))

def exposure_of(+k: String, cs: List<&2, Ct.Container>) -> Ct.Exposure:
  match cs:
    case []:
      Ct.Public{}
    case c <> rest:
      match c:
        case Ct.Container{ck, _, _, _, _, e, _, _, _, _, _, _, _, _, _}:
          Bool.pick(Ct.Exposure, String.eq(k, ck), e, exposure_of(k, rest))

def is_tailnet(e: Ct.Exposure) -> Bool:
  match e:
    case Ct.Tailnet{}:
      True{}
    case _:
      False{}

def is_local(e: Ct.Exposure) -> Bool:
  match e:
    case Ct.Local{}:
      True{}
    case _:
      False{}

def edges(a: A.Architecture) -> List<&2, E.Edge>:
  CO.edges(A.Element, to_compound(a))

# ---- a device reaches a server only over the tailnet ----
def via_tailnet(es: List<&2, E.Edge>, +cs: List<&2, Ct.Container>, +servers: List<&2, String>, +devices: List<&2, String>) -> Bool:
  match es:
    case []:
      True{}
    case e <> rest:
      match e:
        case E.Edge{x, +y, _, _}:
          (Bool.not(CO.has(devices, home(x, cs)) && CO.has(servers, home(y, cs))) || is_tailnet(exposure_of(home(y, cs), cs))) &&
            via_tailnet(rest, cs, servers, devices)

def devices_via_tailnet(+a: A.Architecture) -> Bool:
  via_tailnet(edges(a), containers(a), on_servers(nodes(a)), on_devices(nodes(a)))

# ---- on a server, a container is on the tailnet exactly when a device reaches it, else local ----
def reached(+k: String, es: List<&2, E.Edge>, +cs: List<&2, Ct.Container>, +devices: List<&2, String>) -> Bool:
  match es:
    case []:
      False{}
    case e <> rest:
      match e:
        case E.Edge{x, y, _, _}:
          (CO.has(devices, home(x, cs)) && String.eq(home(y, cs), k)) || reached(k, rest, cs, devices)

def follows_reach(r: Bool, e: Ct.Exposure) -> Bool:
  match r:
    case True{}:
      is_tailnet(e)
    case False{}:
      is_local(e)

def reach_ok(ks: List<&2, String>, +a: A.Architecture) -> Bool:
  match ks:
    case []:
      True{}
    case +k <> rest:
      follows_reach(reached(k, edges(a), containers(a), on_devices(nodes(a))), exposure_of(k, containers(a))) && reach_ok(rest, a)

def exposure_follows_reach(+a: A.Architecture) -> Bool:
  reach_ok(on_servers(nodes(a)), a)

# ---- capabilities: who provides each, and how many do ----
def cap_eq(a: K2.Capability, b: K2.Capability) -> Bool:
  match a b:
    case K2.Hosting{} K2.Hosting{}:
      True{}
    case K2.Realtime{} K2.Realtime{}:
      True{}
    case K2.BlobStore{} K2.BlobStore{}:
      True{}
    case K2.Observability{} K2.Observability{}:
      True{}
    case _ _:
      False{}

def has_cap(+want: K2.Capability, cs: List<&2, K2.Capability>) -> Bool:
  match cs:
    case []:
      False{}
    case c <> rest:
      cap_eq(want, c) || has_cap(want, rest)

def one_if(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n

def container_providers(+want: K2.Capability, cs: List<&2, Ct.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case Ct.Container{k, _, _, _, _, _, caps, _, _, _, _, _, _, _, _}:
          keep_all(has_cap(want, caps), [k], container_providers(want, rest))

def external_providers(+want: K2.Capability, xs: List<&2, X.External>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      match x:
        case X.External{k, _, _, _, caps, _, _, _}:
          keep_all(has_cap(want, caps), [k], external_providers(want, rest))

def externals(a: A.Architecture) -> List<&2, X.External>:
  match a:
    case A.Architecture{_, env}:
      match env:
        case En.Environment{_, xs, _, _, _}:
          xs

# The containers and outside systems that provide a capability.
def providers(+want: K2.Capability, +a: A.Architecture) -> List<&2, String>:
  List.append(&2, String, container_providers(want, containers(a)), external_providers(want, externals(a)))

def provided(+want: K2.Capability, +a: A.Architecture) -> Nat:
  List.length(&2, String, providers(want, a))

# How many containers host the app privately: Hosting, on the tailnet.
def private_hosts(cs: List<&2, Ct.Container>) -> Nat:
  match cs:
    case []:
      0n
    case c <> rest:
      match c:
        case Ct.Container{_, _, _, _, _, e, +caps, _, _, _, _, _, _, _, _}:
          Nat.add(one_if(has_cap(K2.Hosting{}, caps) && is_tailnet(e)), private_hosts(rest))

def private_hosting(+a: A.Architecture) -> Nat:
  private_hosts(containers(a))

def is_data_api(c: K2.Category) -> Bool:
  match c:
    case K2.DataApi{}:
      True{}
    case _:
      False{}

# The system's own data APIs. "Exactly one" means one store.
def data_apis(cs: List<&2, Ct.Container>) -> Nat:
  match cs:
    case []:
      0n
    case c <> rest:
      match c:
        case Ct.Container{_, _, _, cat, _, _, _, _, _, _, _, _, _, _, _}:
          Nat.add(one_if(is_data_api(cat)), data_apis(rest))

def own_data_apis(+a: A.Architecture) -> Nat:
  data_apis(containers(a))

# A data API may also host the app only while it is private.
def shared_ok(c: Ct.Container) -> Bool:
  match c:
    case Ct.Container{_, _, _, cat, _, +e, +caps, _, _, _, _, _, _, _, _}:
      Bool.not(is_data_api(cat) && has_cap(K2.Hosting{}, caps)) || is_tailnet(e) || is_local(e)

def all_shared_ok(cs: List<&2, Ct.Container>) -> Bool:
  match cs:
    case []:
      True{}
    case c <> rest:
      shared_ok(c) && all_shared_ok(rest)

def shared_hosting_private(+a: A.Architecture) -> Bool:
  all_shared_ok(containers(a))

# ---- observed: everything we build reports to an observability provider ----
def reports(+k: String, es: List<&2, E.Edge>, +cs: List<&2, Ct.Container>, +obs: List<&2, String>) -> Bool:
  match es:
    case []:
      False{}
    case e <> rest:
      match e:
        case E.Edge{x, y, _, _}:
          (String.eq(home(x, cs), k) && CO.has(obs, y)) || reports(k, rest, cs, obs)

def built_observed(cs: List<&2, Ct.Container>, +a: A.Architecture) -> Bool:
  match cs:
    case []:
      True{}
    case c <> rest:
      match c:
        case Ct.Container{+k, _, _, _, o, _, _, +src, _, _, _, _, _, _, _}:
          (Bool.not(ours(o) && Bool.not(String.is_empty(src))) || reports(k, edges(a), containers(a), providers(K2.Observability{}, a))) &&
            built_observed(rest, a)

def observed(+a: A.Architecture) -> Bool:
  built_observed(containers(a), a)

# ---- the environment's inventory and agreement ----
def inventory(a: A.Architecture) -> I.Inventory:
  match a:
    case A.Architecture{_, env}:
      match env:
        case En.Environment{_, _, _, inv, _}:
          inv

def agreement(a: A.Architecture) -> G.Agreement:
  match a:
    case A.Architecture{_, env}:
      match env:
        case En.Environment{_, _, _, _, ag}:
          ag

# ---- every server and device is the owner's, or on its vendor's cloud ----
def host_ok(h: H.Host, +name: String, +inv: I.Inventory) -> Bool:
  match h:
    case H.Owned{k}:
      InvO.owns(inv, k, name)
    case H.Cloud{p}:
      InvO.cloud_ok(inv, p)
    case H.Other{}:
      False{}

def nodes_owned(ns: List<&2, D.Node>, +inv: I.Inventory) -> Bool:
  match ns:
    case []:
      True{}
    case n <> rest:
      match n:
        case D.Node{_, +name, _, _, h, _, kids, _}:
          host_ok(h, name, inv) && nodes_owned(kids, inv) && nodes_owned(rest, inv)

def owned_nodes(+a: A.Architecture) -> Bool:
  nodes_owned(nodes(a), inventory(a))

# ---- every nix-darwin node: its serve ports are distinct, its services and serves run what it hosts, a
# container on it is on the tailnet exactly when it is served, and its listeners belong to something ----
def firewall_typed(nd: ND.NixDarwin) -> Bool:
  match nd:
    case ND.NixDarwin{_, _, _, _, _, st, _, _, _, _, _, _, _, _}:
      StO.firewall_typed(st)

def node_keys(ns: List<&2, D.Node>) -> List<&2, String>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case D.Node{k, _, _, _, _, _, kids, _}:
          k <> List.append(&2, String, node_keys(kids), node_keys(rest))

def darwin_ok(p: D.Platform, +ins: List<&2, String>, +a: A.Architecture) -> Bool:
  match p:
    case D.Darwin{+nd}:
      firewall_typed(nd) && NDO.serve_ports_distinct(nd) && NDO.services_on(nd, ins) && NDO.exposure_honest(nd, containers(a), ins) &&
        NDO.listeners_belong(nd, List.append(&2, String, container_keys(containers(a)), node_keys(nodes(a))))
    case _:
      True{}

def darwin_nodes_ok(ns: List<&2, D.Node>, +a: A.Architecture) -> Bool:
  match ns:
    case []:
      True{}
    case n <> rest:
      match n:
        case D.Node{_, _, _, _, _, p, kids, ins}:
          darwin_ok(p, ins, a) && darwin_nodes_ok(kids, a) && darwin_nodes_ok(rest, a)

def nix_darwin_ok(+a: A.Architecture) -> Bool:
  darwin_nodes_ok(nodes(a), a)
