import Base

# Arc, by Pedro Antonio Villanueva Juarez · https://github.com/PedroAVJ/v (V, the framework that uses it)
#
# Arc: a system's architecture as types, in two hierarchies over the same containers.
#   Where it runs: node -> container -> part.
#   What it is:    system -> container -> part.
# Keys work like foreign keys: a container names its host node (`on`), a part its container (`in`)
# and execution node (`on`), and a link two keys. A project states its laws with the predicates
# below; the compiler proves them.

# ---- vocabulary ----
# UserDevice: a user's own device. Server: a machine the project runs. Overlay: the private
# (overlay) network between them. Outside: someone else's servers.
type NodeRole is Data:
  UserDevice{}
  Server{}
  Overlay{}
  Outside{}

type PhysicalDevice is Data:
  PhysicalDevice{key: String, name: String, platform: String}

type Vendor is Data:
  Vendor{name: String, cloud: String}

type Org is Data:
  Org{name: String, vendor: Vendor, devices: List<&2, PhysicalDevice>}

# The agreement between the organization and its people: who they are (identities in the org's
# directory domain), what each is granted per scope (actions; none means no access), and budgets.
# It describes the people who work on the system, not the system; the diagram may omit it.
type Person is Data:
  Person{key: String, identity: String}
type Grant is Data:
  Grant{person: String, scope: String, actions: List<&2, String>}
type Budget is Data:
  Budget{person: String, what: String, amount: Nat, unit: String}
type Agreement is Data:
  Agreement{domain: String, people: List<&2, Person>, grants: List<&2, Grant>, budgets: List<&2, Budget>}
type Host is Data:
  Owned{device: String}
  Cloud{provider: String}
  Other{}

type Node is Data:
  Node{key: String, name: String, role: NodeRole, host: Host}

# What a container is. The list is closed: something that is none of these is not a container.
# Client: the app, on the user's device. The private overlay is a node, not a container.
# DataApi: answers queries on records and changes them.
# Harness: an agent harness, the loop around a model (tools, context, threads), driven over its remote-control API.
# Proxy: forwards connections to another container, adding what it lacks, such as TLS or authentication.
# ModelApi: answers model calls. Cli: a command a person runs. Worker: has no API of its own; it
# only moves data between data APIs, so it is the first thing to fold into a data API's own actions.
type ContainerKind is Data:
  Client{}
  DataApi{}
  Harness{}
  Proxy{}
  ModelApi{}
  Cli{}
  Worker{}

# Whether the project builds and runs it, or uses it as it is.
type Owner is Data:
  Ours{}
  Theirs{}

# Who can reach it: its own machine (127.0.0.1), the local network, the overlay, the device it is on, anyone.
type Exposure is Data:
  Local{}
  Lan{}
  Tailnet{}
  Device{}
  Public{}

# What a container provides. Hosting is serving the app itself (its HTML and scripts); a data API
# may also host the app only while it is private (shared_hosting_ok). Observability is receiving
# a running container's errors, traces and structured logs.
type Cap is Data:
  Hosting{}
  PrivateHosting{}
  Realtime{}
  BlobStore{}
  Observability{}

type Lang is Data:
  Bend{}
  C{}
  Rust{}
  TypeScript{}
  JavaScript{}
  Python{}
  Opaque{}

type Container is Data:
  Container{key: String, name: String, kind: ContainerKind, owner: Owner, on: String, exposure: Exposure, caps: List<&2, Cap>, source: String, vendors: List<&2, String>, frameworks: List<&2, String>, libraries: List<&2, String>, languages: List<&2, String>}

type Part is Data:
  Part{key: String, name: String, lang: Lang, in: String, on: String}

# A talks-to edge between two containers or parts, by key.
type Link is Data:
  Link{src: String, dst: String, label: String, live: Bool}

type System is Data:
  System{org: Org, nodes: List<&2, Node>, containers: List<&2, Container>, parts: List<&2, Part>, links: List<&2, Link>}

# ---- access ----
def org(s: System) -> Org:
  match s:
    case System{o, _, _, _, _}:
      o

def nodes(s: System) -> List<&2, Node>:
  match s:
    case System{_, n, _, _, _}:
      n

def containers(s: System) -> List<&2, Container>:
  match s:
    case System{_, _, c, _, _}:
      c

def parts(s: System) -> List<&2, Part>:
  match s:
    case System{_, _, _, p, _}:
      p

def links(s: System) -> List<&2, Link>:
  match s:
    case System{_, _, _, _, l}:
      l

def nkey(n: Node) -> String:
  match n:
    case Node{k, _, _, _}:
      k

def ckey(c: Container) -> String:
  match c:
    case Container{k, _, _, _, _, _, _, _, _, _, _, _}:
      k

def con(c: Container) -> String:
  match c:
    case Container{_, _, _, _, o, _, _, _, _, _, _, _}:
      o

def caps(c: Container) -> List<&2, Cap>:
  match c:
    case Container{_, _, _, _, _, _, cs, _, _, _, _, _}:
      cs

def pkey(p: Part) -> String:
  match p:
    case Part{k, _, _, _, _}:
      k

def pin(p: Part) -> String:
  match p:
    case Part{_, _, _, i, _}:
      i

def pon(p: Part) -> String:
  match p:
    case Part{_, _, _, _, on}:
      on

def nkeys(xs: List<&2, Node>) -> List<&2, String>:
  match xs:
    case []:
      []
    case n <> rest:
      nkey(n) <> nkeys(rest)

def ckeys(xs: List<&2, Container>) -> List<&2, String>:
  match xs:
    case []:
      []
    case c <> rest:
      ckey(c) <> ckeys(rest)

def pkeys(xs: List<&2, Part>) -> List<&2, String>:
  match xs:
    case []:
      []
    case p <> rest:
      pkey(p) <> pkeys(rest)

# Keys links may name: containers and parts.
def keys(+s: System) -> List<&2, String>:
  List.append(&2, String, ckeys(containers(s)), pkeys(parts(s)))

# ---- predicates on the vocabulary ----
def is_server(r: NodeRole) -> Bool:
  match r:
    case Server{}:
      True{}
    case _:
      False{}

def is_outside(r: NodeRole) -> Bool:
  match r:
    case Outside{}:
      True{}
    case _:
      False{}

def is_device(r: NodeRole) -> Bool:
  match r:
    case UserDevice{}:
      True{}
    case _:
      False{}

def is_overlay(r: NodeRole) -> Bool:
  match r:
    case Overlay{}:
      True{}
    case _:
      False{}

def one_if(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n

def overlay_nodes.go(xs: List<&2, Node>) -> Nat:
  match xs:
    case []:
      0n
    case n <> rest:
      match n:
        case Node{_, _, role, _}:
          Nat.add(one_if(is_overlay(role)), overlay_nodes.go(rest))

# Private access is represented by exactly one Overlay node.
def overlay_nodes(+s: System) -> Nat:
  overlay_nodes.go(nodes(s))

def is_client(k: ContainerKind) -> Bool:
  match k:
    case Client{}:
      True{}
    case _:
      False{}

def is_data_api(k: ContainerKind) -> Bool:
  match k:
    case DataApi{}:
      True{}
    case _:
      False{}

def is_ours(o: Owner) -> Bool:
  match o:
    case Ours{}:
      True{}
    case Theirs{}:
      False{}

def is_local(e: Exposure) -> Bool:
  match e:
    case Local{}:
      True{}
    case _:
      False{}

def is_tailnet(e: Exposure) -> Bool:
  match e:
    case Tailnet{}:
      True{}
    case _:
      False{}

def is_rust(l: Lang) -> Bool:
  match l:
    case Rust{}:
      True{}
    case _:
      False{}

# ---- keys, like foreign keys ----
def str_eq(a: String, b: String) -> Bool:
  String.eq(a, b)

def has(+s: String, xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      False{}
    case x <> rest:
      str_eq(s, x) || has(s, rest)

def owned_device(+key: String, +name: String, xs: List<&2, PhysicalDevice>) -> Bool:
  match xs:
    case []:
      False{}
    case PhysicalDevice{k, n, _} <> rest:
      (str_eq(key, k) && str_eq(name, n)) || owned_device(key, name, rest)

def host_in_inventory(h: Host, name: String, o: Org) -> Bool:
  match h o:
    case Owned{key} Org{_, _, devices}:
      owned_device(key, name, devices)
    case Cloud{provider} Org{_, Vendor{_, cloud}, _}:
      str_eq(provider, cloud)
    case Other{} _:
      False{}

def node_owned(n: Node, +o: Org) -> Bool:
  match n:
    case Node{_, name, +role, host}:
      Bool.not(is_server(role) || is_device(role)) || host_in_inventory(host, name, o)

def owned_nodes.go(xs: List<&2, Node>, +o: Org) -> Bool:
  match xs:
    case []:
      True{}
    case n <> rest:
      node_owned(n, o) && owned_nodes.go(rest, o)

# Every server and user device is in the owner's inventory or on its vendor's cloud.
def owned_nodes(+s: System) -> Bool:
  owned_nodes.go(nodes(s), org(s))

def pick_str(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# No key names two things.
def distinct_keys(xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case +k <> +rest:
      Bool.not(has(k, rest)) && distinct_keys(rest)

# Every key in `xs` names something in `ks`.
def all_in(xs: List<&2, String>, +ks: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      has(x, ks) && all_in(rest, ks)

def part_ins(xs: List<&2, Part>) -> List<&2, String>:
  match xs:
    case []:
      []
    case p <> rest:
      pin(p) <> part_ins(rest)

def part_ons(xs: List<&2, Part>) -> List<&2, String>:
  match xs:
    case []:
      []
    case p <> rest:
      pon(p) <> part_ons(rest)

def container_ons(xs: List<&2, Container>) -> List<&2, String>:
  match xs:
    case []:
      []
    case c <> rest:
      con(c) <> container_ons(rest)

def link_ends(xs: List<&2, Link>) -> List<&2, String>:
  match xs:
    case []:
      []
    case l <> rest:
      match l:
        case Link{a, b, _, _}:
          a <> b <> link_ends(rest)

# The system is well formed: node keys and container/part keys are unique, every container is on
# a node, every part in a container, and every link joins two things that exist.
def well_formed(+s: System) -> Bool:
  distinct_keys(nkeys(nodes(s))) && distinct_keys(keys(s)) &&
  all_in(container_ons(containers(s)), nkeys(nodes(s))) &&
  all_in(part_ins(parts(s)), ckeys(containers(s))) &&
  all_in(part_ons(parts(s)), nkeys(nodes(s))) &&
  all_in(link_ends(links(s)), keys(s))

# ---- looking things up ----
def part_home(+k: String, xs: List<&2, Part>) -> String:
  match xs:
    case []:
      ""
    case +p <> rest:
      pick_str(str_eq(k, pkey(p)), pin(p), part_home(k, rest))

# The container a key belongs to: itself, or the one its part sits in.
def home(+k: String, +s: System) -> String:
  pick_str(has(k, ckeys(containers(s))), k, part_home(k, parts(s)))

def none() -> Container:
  Container{"", "", Worker{}, Theirs{}, "", Public{}, [], "", [], [], [], []}

def pick_c(hit: Bool, c: Container, other: Container) -> Container:
  match hit:
    case True{}:
      c
    case False{}:
      other

# The container with key `k` (an empty one when `k` is unknown; well_formed rules that out).
def container(+k: String, xs: List<&2, Container>) -> Container:
  match xs:
    case []:
      none()
    case +c <> rest:
      pick_c(str_eq(k, ckey(c)), c, container(k, rest))

def pick_r(hit: Bool, r: NodeRole, other: NodeRole) -> NodeRole:
  match hit:
    case True{}:
      r
    case False{}:
      other

def node_role(+k: String, xs: List<&2, Node>) -> NodeRole:
  match xs:
    case []:
      Outside{}
    case n <> rest:
      match n:
        case Node{nk, _, r, _}:
          pick_r(str_eq(k, nk), r, node_role(k, rest))

def part_node(+k: String, xs: List<&2, Part>) -> String:
  match xs:
    case []:
      ""
    case +p <> rest:
      pick_str(str_eq(k, pkey(p)), pon(p), part_node(k, rest))

# The node a container or part runs on, and its role.
def node_of(+k: String, +s: System) -> String:
  pick_str(has(k, pkeys(parts(s))), part_node(k, parts(s)), con(container(home(k, s), containers(s))))

def role_of(+k: String, +s: System) -> NodeRole:
  node_role(node_of(k, s), nodes(s))

def container_exposure(c: Container) -> Exposure:
  match c:
    case Container{_, _, _, _, _, exposure, _, _, _, _, _, _}:
      exposure

def exposure_of(+k: String, +s: System) -> Exposure:
  container_exposure(container(home(k, s), containers(s)))

# ---- where it runs ----
# On a server, everything is reachable only from the server itself or over the overlay.
def private_ok(c: Container, +ns: List<&2, Node>) -> Bool:
  match c:
    case Container{_, _, _, _, on, +exposure, _, _, _, _, _, _}:
      Bool.not(is_server(node_role(on, ns))) || is_tailnet(exposure) || is_local(exposure)

def all_private(xs: List<&2, Container>, +ns: List<&2, Node>) -> Bool:
  match xs:
    case []:
      True{}
    case c <> rest:
      private_ok(c, ns) && all_private(rest, ns)

def servers_private(+s: System) -> Bool:
  all_private(containers(s), nodes(s))

# A device reaches a server over the overlay only when the destination is exposed to the tailnet.
def devices_via_network.go(xs: List<&2, Link>, +s: System) -> Bool:
  match xs:
    case []:
      True{}
    case l <> rest:
      match l:
        case Link{src, +dst, _, _}:
          (Bool.not(is_device(role_of(src, s)) && is_server(role_of(dst, s))) ||
            is_tailnet(exposure_of(dst, s))) && devices_via_network.go(rest, s)

def devices_via_network(+s: System) -> Bool:
  devices_via_network.go(links(s), s)

# A server container needs overlay exposure exactly when a device-origin link reaches it.
def device_reaches(+key: String, xs: List<&2, Link>, +s: System) -> Bool:
  match xs:
    case []:
      False{}
    case Link{src, dst, _, _} <> rest:
      (is_device(role_of(src, s)) && str_eq(home(dst, s), key)) || device_reaches(key, rest, s)

def exposure_for_reach(c: Container, reached: Bool) -> Bool:
  match reached:
    case True{}: is_tailnet(container_exposure(c))
    case False{}: is_local(container_exposure(c))

def exposure_follows_reach.go(xs: List<&2, Container>, +s: System) -> Bool:
  match xs:
    case []:
      True{}
    case +c <> rest:
      (Bool.not(is_server(role_of(ckey(c), s))) ||
        exposure_for_reach(c, device_reaches(ckey(c), links(s), s))) &&
        exposure_follows_reach.go(rest, s)

def exposure_follows_reach(+s: System) -> Bool:
  exposure_follows_reach.go(containers(s), s)

# ---- what it is: minimality, every capability provided exactly once ----
def is_cap(want: Cap, c: Cap) -> Bool:
  match want c:
    case Hosting{} Hosting{}:
      True{}
    case PrivateHosting{} PrivateHosting{}:
      True{}
    case Realtime{} Realtime{}:
      True{}
    case BlobStore{} BlobStore{}:
      True{}
    case Observability{} Observability{}:
      True{}
    case _ _:
      False{}

def count_in(+want: Cap, cs: List<&2, Cap>) -> Nat:
  match cs:
    case []:
      0n
    case c <> rest:
      Nat.add(one_if(is_cap(want, c)), count_in(want, rest))

def direct(+want: Cap, xs: List<&2, Container>) -> Nat:
  match xs:
    case []:
      0n
    case c <> rest:
      Nat.add(count_in(want, caps(c)), direct(want, rest))

def tailnet_hosting.go(xs: List<&2, Container>) -> Nat:
  match xs:
    case []:
      0n
    case c <> rest:
      match c:
        case Container{_, _, _, _, _, exposure, cs, _, _, _, _, _}:
          Nat.add(one_if(is_tailnet(exposure) && Nat.is_gt(count_in(Hosting{}, cs), 0n)), tailnet_hosting.go(rest))

# How many containers host the app at Tailnet exposure.
def tailnet_hosting(+s: System) -> Nat:
  tailnet_hosting.go(containers(s))

# How many containers provide `want`. One tailnet host plus one overlay composes private hosting.
def provided(want: Cap, +s: System) -> Nat:
  match want:
    case PrivateHosting{}:
      Nat.add(direct(PrivateHosting{}, containers(s)), one_if(Nat.is_eq(tailnet_hosting(s), 1n) && Nat.is_eq(overlay_nodes(s), 1n)))
    case _:
      direct(want, containers(s))

# ---- observability: everything we run reports to the observability provider ----
def cons_if(b: Bool, k: String, xs: List<&2, String>) -> List<&2, String>:
  match b:
    case True{}:
      k <> xs
    case False{}:
      xs

# Keys of the containers that provide `want`.
def providers(+want: Cap, xs: List<&2, Container>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +c <> rest:
      cons_if(Nat.is_gt(count_in(want, caps(c)), 0n), ckey(c), providers(want, rest))

# The container a link end belongs to: a part's container, else the key itself.
def part_container(ps: List<&2, Part>, +k: String) -> String:
  match ps:
    case []:
      k
    case +p <> rest:
      pick_str(str_eq(k, pkey(p)), pin(p), part_container(rest, k))

# Some link from container `k` (or one of its parts) reaches one of `obs`.
def reports_to(ls: List<&2, Link>, +k: String, +ps: List<&2, Part>, +obs: List<&2, String>) -> Bool:
  match ls:
    case []:
      False{}
    case Link{src, dst, _, _} <> rest:
      (str_eq(k, part_container(ps, src)) && has(dst, obs)) || reports_to(rest, k, ps, obs)

def observed.go(xs: List<&2, Container>, +s: System, +obs: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case c <> rest:
      match c:
        case Container{+k, _, _, owner, _, _, _, source, _, _, _, _}:
          (Bool.not(is_ours(owner) && Bool.not(str_eq(source, ""))) || reports_to(links(s), k, parts(s), obs)) && observed.go(rest, s, obs)

# Every container we build (ours, with source) links to a container providing Observability.
def observed(+s: System) -> Bool:
  observed.go(containers(s), s, providers(Observability{}, containers(s)))

def tailnet_data_apis.go(xs: List<&2, Container>) -> Nat:
  match xs:
    case []:
      0n
    case c <> rest:
      match c:
        case Container{_, _, kind, _, _, exposure, _, _, _, _, _, _}:
          Nat.add(one_if(is_data_api(kind) && is_tailnet(exposure)), tailnet_data_apis.go(rest))

# The data APIs the overlay reaches: the client's data API. Local and outside ones are its sources.
def tailnet_data_apis(+s: System) -> Nat:
  tailnet_data_apis.go(containers(s))

def own_data_apis.go(xs: List<&2, Container>, +ns: List<&2, Node>) -> Nat:
  match xs:
    case []:
      0n
    case c <> rest:
      match c:
        case Container{_, _, kind, _, on, _, _, _, _, _, _, _}:
          Nat.add(one_if(is_data_api(kind) && Bool.not(is_outside(node_role(on, ns)))), own_data_apis.go(rest, ns))

# The system's own data APIs: those not on someone else's servers. "Exactly one" means one store.
def own_data_apis(+s: System) -> Nat:
  own_data_apis.go(containers(s), nodes(s))

# A data API may also host the app only while it is private.
def shared_hosting_ok(c: Container) -> Bool:
  match c:
    case Container{_, _, kind, _, _, +exposure, +cs, _, _, _, _, _}:
      Bool.not(Nat.is_gt(count_in(Hosting{}, cs), 0n) && is_data_api(kind)) || is_tailnet(exposure) || is_local(exposure)

def shared_hosting_private.go(xs: List<&2, Container>) -> Bool:
  match xs:
    case []:
      True{}
    case c <> rest:
      shared_hosting_ok(c) && shared_hosting_private.go(rest)

def shared_hosting_private(+s: System) -> Bool:
  shared_hosting_private.go(containers(s))

# ---- a goal: every part of our own non-client containers is Rust ----
def backend(c: Container) -> Bool:
  match c:
    case Container{_, _, kind, owner, _, _, _, _, _, _, _, _}:
      is_ours(owner) && Bool.not(is_client(kind))

def rust_ok(p: Part, +s: System) -> Bool:
  match p:
    case Part{_, _, lang, i, _}:
      Bool.not(backend(container(i, containers(s)))) || is_rust(lang)

def all_rust.go(xs: List<&2, Part>, +s: System) -> Bool:
  match xs:
    case []:
      True{}
    case p <> rest:
      rust_ok(p, s) && all_rust.go(rest, s)

def all_rust(+s: System) -> Bool:
  all_rust.go(parts(s), s)

# Every modeled part belongs to a container we build; someone else's program is a black box.
def container_ours(c: Container) -> Bool:
  match c:
    case Container{_, _, _, owner, _, _, _, _, _, _, _, _}:
      is_ours(owner)

def parts_ours.go(xs: List<&2, Part>, +s: System) -> Bool:
  match xs:
    case []:
      True{}
    case p <> rest:
      container_ours(container(pin(p), containers(s))) && parts_ours.go(rest, s)

def parts_ours(+s: System) -> Bool:
  parts_ours.go(parts(s), s)

# ---- the diagram (D2): nodes as boxes, containers inside their node, parts inside their container ----
def path(+k: String, +s: System) -> String:
  node_of(k, s) ++ "." ++ pick_str(String.eq(home(k, s), k), k, home(k, s) ++ "." ++ k)

def node_box(n: Node) -> String:
  match n:
    case Node{k, name, role, _}:
      match role:
        case Outside{}:
          k ++ ": \"" ++ name ++ "\" {class: node; style.stroke-dash: 4; style.fill: \"#FFFFFF\"}\n"
        case _:
          k ++ ": \"" ++ name ++ "\" {class: node}\n"

def node_boxes(xs: List<&2, Node>) -> String:
  match xs:
    case []:
      ""
    case n <> rest:
      node_box(n) ++ node_boxes(rest)

def stack_label(frameworks: List<&2, String>, libraries: List<&2, String>) -> String:
  match frameworks:
    case []:
      match libraries:
        case []:
          ""
        case _:
          "\\n[" ++ String.join(libraries, ", ") ++ "]"
    case _:
      match libraries:
        case []:
          "\\n[" ++ String.join(frameworks, ", ") ++ "]"
        case _:
          "\\n[" ++ String.join(frameworks, ", ") ++ " · " ++ String.join(libraries, ", ") ++ "]"

def container_box(c: Container) -> String:
  match c:
    case Container{k, name, _, _, on, _, _, _, _, frameworks, libraries, _}:
      on ++ "." ++ k ++ ": \"" ++ name ++ stack_label(frameworks, libraries) ++ "\" {class: container}\n"

def container_boxes(xs: List<&2, Container>) -> String:
  match xs:
    case []:
      ""
    case c <> rest:
      container_box(c) ++ container_boxes(rest)

def part_box(p: Part, +s: System) -> String:
  match p:
    case Part{+k, name, _, _, _}:
      path(k, s) ++ ": \"" ++ name ++ "\" {class: part}\n"

def part_boxes(xs: List<&2, Part>, +s: System) -> String:
  match xs:
    case []:
      ""
    case p <> rest:
      part_box(p, s) ++ part_boxes(rest, s)

def style(live: Bool) -> String:
  match live:
    case True{}:
      "live"
    case False{}:
      "plain"

def edges(xs: List<&2, Link>, +s: System) -> String:
  match xs:
    case []:
      ""
    case l <> rest:
      match l:
        case Link{src, dst, label, live}:
          path(src, s) ++ " -> " ++ path(dst, s) ++ ": \"" ++ label ++ "\" {class: " ++ style(live) ++ "}\n" ++ edges(rest, s)

def d2(+s: System) -> String:
  "direction: right\n" ++
  "classes: {\n" ++
  "  node: {style: {fill: \"#F2F2F2\"; stroke: \"#D9D9D9\"; border-radius: 14; font-size: 26; bold: true}}\n" ++
  "  container: {style: {fill: \"#FFFFFF\"; stroke: \"#8C8C8C\"; border-radius: 10; font-size: 22}}\n" ++
  "  part: {style: {fill: \"#FAFAFA\"; stroke: \"#BFBFBF\"; border-radius: 8; font-size: 18}}\n" ++
  "  live: {style: {stroke: \"#3E8A62\"; stroke-width: 3; font-color: \"#3E8A62\"; font-size: 18; bold: true}}\n" ++
  "  plain: {style: {stroke: \"#8C8C8C\"; stroke-width: 2; font-color: \"#8C8C8C\"; font-size: 16}}\n" ++
  "}\n" ++
  node_boxes(nodes(s)) ++ container_boxes(containers(s)) ++ part_boxes(parts(s), s) ++ edges(links(s), s)

# ---- the agreement: people, their identities and grants ----
def ends_with_at(+identity: String, +domain: String) -> Bool:
  String.ends_with(String.to_lower(identity), "@" ++ String.to_lower(domain))

def people_in.go(xs: List<&2, Person>, +domain: String) -> Bool:
  match xs:
    case []:
      True{}
    case Person{_, identity} <> rest:
      ends_with_at(identity, domain) && people_in.go(rest, domain)

# Every person's identity is in the organization's directory domain.
def people_in_domain(a: Agreement) -> Bool:
  match a:
    case Agreement{domain, people, _, _}:
      people_in.go(people, domain)

def is_identity(+id: String, xs: List<&2, Person>) -> Bool:
  match xs:
    case []:
      False{}
    case Person{_, identity} <> rest:
      str_eq(String.to_lower(id), String.to_lower(identity)) || is_identity(id, rest)

def identities_known.go(ids: List<&2, String>, +xs: List<&2, Person>) -> Bool:
  match ids:
    case []:
      True{}
    case id <> rest:
      is_identity(id, xs) && identities_known.go(rest, xs)

# Every identity actually in use (from a snapshot) is one of the agreement's people.
def identities_known(ids: List<&2, String>, a: Agreement) -> Bool:
  match a:
    case Agreement{_, people, _, _}:
      identities_known.go(ids, people)

def pick_list(c: Bool, a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      a
    case False{}:
      b

def granted.go(xs: List<&2, Grant>, +person: String, +scope: String) -> List<&2, String>:
  match xs:
    case []:
      []
    case Grant{p, sc, acts} <> rest:
      pick_list(str_eq(person, p) && str_eq(scope, sc), acts, granted.go(rest, person, scope))

# What `person` is granted on `scope`; [] when nothing is granted there.
def granted(a: Agreement, +person: String, +scope: String) -> List<&2, String>:
  match a:
    case Agreement{_, _, grants, _}:
      granted.go(grants, person, scope)

