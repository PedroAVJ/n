import Base
import ../arc/arc.bend as A

# A system as a graph with one start, and its Markdown serialization.
# The graph: every container and part, joined by the links and by containment (a container holds its
# parts). It must have exactly one start, the one item nothing points to, and reach everything from it.
# Rendering requires that as a proof, so a system with two starts does not type-check.

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

# ---- the graph ----
def container_keys(cs: List<&2, A.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case A.Container{k, _, _, _, _, _, _, _, _, _, _, _}:
          k <> container_keys(rest)

def part_keys(ps: List<&2, A.Part>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case A.Part{k, _, _, _, _}:
          k <> part_keys(rest)

def containment(ps: List<&2, A.Part>) -> List<&2, A.Link>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case A.Part{k, _, _, i, _}:
          A.Link{i, k, "", False{}} <> containment(rest)

def items(+s: A.System) -> List<&2, String>:
  List.append(&2, String, container_keys(A.containers(s)), part_keys(A.parts(s)))

def edges(+s: A.System) -> List<&2, A.Link>:
  List.append(&2, A.Link, A.links(s), containment(A.parts(s)))

def keep_new(known: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match known:
    case True{}:
      rest
    case False{}:
      x <> rest

def has_in(+k: String, es: List<&2, A.Link>) -> Bool:
  match es:
    case []:
      False{}
    case e <> rest:
      match e:
        case A.Link{a, b, _, _}:
          (String.eq(b, k) && Bool.not(String.eq(a, k))) || has_in(k, rest)

# The items nothing points to.
def starts(ks: List<&2, String>, +es: List<&2, A.Link>) -> List<&2, String>:
  match ks:
    case []:
      []
    case +k <> +rest:
      keep_new(has_in(k, es), k, starts(rest, es))

def outs(+k: String, es: List<&2, A.Link>) -> List<&2, String>:
  match es:
    case []:
      []
    case e <> +rest:
      match e:
        case A.Link{a, b, _, _}:
          keep_new(Bool.not(String.eq(a, k)), b, outs(k, rest))

def fresh(xs: List<&2, String>, +seen: List<&2, String>, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      acc
    case +x <> rest:
      fresh(rest, seen, keep_new(listed(x, seen) || listed(x, acc), x, acc))

def nth_key(xs: List<&2, String>, n: Nat) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      match n:
        case 0n:
          x
        case 1n+m:
          nth_key(rest, m)

def reach(fuel: Nat, +i: Nat, +seen: List<&2, String>, +es: List<&2, A.Link>) -> List<&2, String>:
  match fuel:
    case 0n:
      seen
    case 1n+k:
      reach(k, 1n+i, List.append(&2, String, seen, fresh(outs(nth_key(seen, i), es), seen, [])), es)

def all_in(xs: List<&2, String>, +ys: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      listed(x, ys) && all_in(rest, ys)

# Links between programs: a link to or from a part counts for the program it belongs to.
def program_links(ls: List<&2, A.Link>, +s: A.System) -> List<&2, A.Link>:
  match ls:
    case []:
      []
    case l <> rest:
      match l:
        case A.Link{a, b, label, live}:
          A.Link{container_of(a, s), container_of(b, s), label, live} <> program_links(rest, s)

def programs(+s: A.System) -> List<&2, String>:
  container_keys(A.containers(s))

# One start: exactly one program nothing links to, and every program reachable from it.
def one_start(+s: A.System) -> Bool:
  Nat.is_eq(List.length(&2, String, starts(programs(s), program_links(A.links(s), s))), 1n) && all_in(programs(s), reach(List.length(&2, String, programs(s)), 0n, starts(programs(s), program_links(A.links(s), s)), program_links(A.links(s), s)))

# ---- the tree it serializes to: the graph walked depth first from its start ----
type Line is Data:
  Line{depth: Nat, key: String, via: String}

def pick_lines(c: Bool, a: List<&2, Line>, b: List<&2, Line>) -> List<&2, Line>:
  match c:
    case True{}:
      a
    case False{}:
      b

def keep_line(c: Bool, x: Line, rest: List<&2, Line>) -> List<&2, Line>:
  match c:
    case True{}:
      x <> rest
    case False{}:
      rest

def child_lines(+d: Nat, +k: String, es: List<&2, A.Link>) -> List<&2, Line>:
  match es:
    case []:
      []
    case e <> +rest:
      match e:
        case A.Link{a, b, label, _}:
          keep_line(String.eq(a, k), Line{d, b, label}, child_lines(d, k, rest))

def walk(+fuel: Nat, stack: List<&2, Line>, +seen: List<&2, String>, +es: List<&2, A.Link>) -> List<&2, Line>:
  match fuel:
    case 0n:
      []
    case 1n+f:
      match stack:
        case []:
          []
        case top <> +rest:
          match top:
            case Line{+d, +k, +via}:
              keep_line(Bool.not(listed(k, seen)), Line{d, k, via}, walk(f, pick_lines(listed(k, seen), rest, List.append(&2, Line, child_lines(1n+d, k, es), rest)), pick_l(listed(k, seen), seen, k <> seen), es))

# ---- serialization ----
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

def node_label(+k: String, ns: List<&2, A.Node>) -> String:
  match ns:
    case []:
      k
    case n <> rest:
      match n:
        case A.Node{nk, name, role, host}:
          pick_s(String.eq(k, nk), role_emoji(role, host) ++ " " ++ name, node_label(k, rest))

def indent(d: Nat) -> String:
  match d:
    case 0n:
      ""
    case 1n+m:
      "  " ++ indent(m)

def render(ls: List<&2, Line>, +s: A.System) -> String:
  match ls:
    case []:
      ""
    case l <> rest:
      match l:
        case Line{d, +k, +via}:
          indent(d) ++ "- **" ++ name_of(k, s) ++ "**" ++ pick_s(String.is_empty(via), "", " (" ++ via ++ ")") ++ " · " ++ node_label(node_of(k, s), A.nodes(s)) ++ "\n" ++ render(rest, s)

def markdown(+s: A.System, ok: {one_start(s) == True{} : Bool}) -> String:
  render(walk(Nat.mul(1n+List.length(&2, String, items(s)), 1n+List.length(&2, A.Link, edges(s))), [Line{0n, head_or(starts(programs(s), program_links(A.links(s), s)), ""), ""}], [], edges(s)), s)

# ---- JSON serialization, for the interactive viewer ----
def esc(s: String) -> String:
  String.join(String.split(s, '"'), "\\\"")

def jstr(s: String) -> String:
  "\"" ++ esc(s) ++ "\""

def jlist(xs: List<&2, String>) -> String:
  "[" ++ String.join(xs, ",") ++ "]"

def jstrs(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      jstr(x) <> jstrs(rest)

def role_name(r: A.NodeRole) -> String:
  match r:
    case A.UserDevice{}:
      "user-device"
    case A.Server{}:
      "server"
    case A.Overlay{}:
      "overlay"
    case A.Outside{}:
      "outside"

def host_name(h: A.Host) -> String:
  match h:
    case A.Owned{d}:
      "owned:" ++ d
    case A.Cloud{p}:
      "cloud:" ++ p
    case A.Other{}:
      "other"

def kind_name(k: A.ContainerKind) -> String:
  match k:
    case A.Client{}:
      "client"
    case A.DataApi{}:
      "data-api"
    case A.Harness{}:
      "harness"
    case A.Proxy{}:
      "proxy"
    case A.ModelApi{}:
      "model-api"
    case A.Cli{}:
      "cli"
    case A.Worker{}:
      "worker"

def owner_name(o: A.Ownership) -> String:
  match o:
    case A.Ours{}:
      "ours"
    case A.Theirs{}:
      "theirs"

def lang_name(l: A.Lang) -> String:
  match l:
    case A.Bend{}:
      "Bend"
    case A.C{}:
      "C"
    case A.Rust{}:
      "Rust"
    case A.TypeScript{}:
      "TypeScript"
    case A.JavaScript{}:
      "JavaScript"
    case A.Python{}:
      "Python"
    case A.Opaque{}:
      "opaque"

# Every object has the same shape: a name, an image ("" means its type's emoji), a type with its emoji,
# and its properties (the key among them). Relations to other objects sit beside the properties.
def prop(k: String, v: String) -> String:
  jstr(k) ++ ":" ++ jstr(v)

def image_kind(i: A.Imagery) -> String:
  match i:
    case A.Plain{}:
      "none"
    case A.Emoji{_}:
      "emoji"
    case A.Icon{_}:
      "icon"
    case A.Logo{_}:
      "logo"
    case A.Photo{_}:
      "photo"

def image_src(i: A.Imagery) -> String:
  match i:
    case A.Plain{}:
      ""
    case A.Emoji{t}:
      t
    case A.Icon{u}:
      u
    case A.Logo{u}:
      u
    case A.Photo{u}:
      u

def entity(key: String, name: String, +image: A.Imagery, ty: String, emoji: String, ps: List<&2, String>, rel: String) -> String:
  "{\"key\":" ++ jstr(key) ++ ",\"name\":" ++ jstr(name) ++ ",\"image\":" ++ jstr(image_src(image)) ++ ",\"imageKind\":" ++ jstr(image_kind(image)) ++ ",\"type\":" ++ jstr(ty) ++ ",\"emoji\":" ++ jstr(emoji) ++ ",\"properties\":{" ++ String.join(ps, ",") ++ "}" ++ rel ++ "}"

# ---- each object's type, named by its most specific kind ----
def org_type(k: A.OrgKind) -> String:
  match k:
    case A.Business{}:
      "Business"
    case A.Nonprofit{}:
      "Nonprofit"
    case A.Community{}:
      "Community"

def system_type(k: A.SystemKind) -> String:
  match k:
    case A.Product{}:
      "Product"
    case A.Project{}:
      "Project"
    case A.Framework{}:
      "Framework"
    case A.Library{}:
      "Library"

def role_type(r: A.NodeRole) -> String:
  match r:
    case A.UserDevice{}:
      "User's device"
    case A.Server{}:
      "Server"
    case A.Overlay{}:
      "Private network"
    case A.Outside{}:
      "Internet"

def program_type(k: A.ContainerKind) -> String:
  match k:
    case A.Client{}:
      "Client"
    case A.DataApi{}:
      "Data API"
    case A.Harness{}:
      "Harness"
    case A.Proxy{}:
      "Proxy"
    case A.ModelApi{}:
      "Model API"
    case A.Cli{}:
      "CLI"
    case A.Worker{}:
      "Worker"

def party_json(+p: A.Party, +channel: String) -> String:
  match p:
    case A.Human{+name, image}:
      entity(name, name, image, "Human", A.party_emoji(p), [prop("channel", channel)], "")
    case A.Organization{+name, image, +k}:
      entity(name, name, image, org_type(k), A.party_emoji(p), [prop("channel", channel)], "")
    case A.Team{+name, image, of}:
      entity(name, name, image, "Team", A.party_emoji(p), [prop("of", of), prop("channel", channel)], "")
    case A.Anyone{}:
      entity("anyone", "Anyone", A.Plain{}, "Anyone", A.party_emoji(p), [prop("channel", channel)], "")

def uses_json(us: List<&2, A.Use>) -> List<&2, String>:
  match us:
    case []:
      []
    case u <> rest:
      match u:
        case A.Use{p, c}:
          party_json(p, c) <> uses_json(rest)

def pick_image(c: Bool, a: A.Imagery, b: A.Imagery) -> A.Imagery:
  match c:
    case True{}:
      a
    case False{}:
      b

def picture_of(+k: String, ps: List<&2, A.Picture>) -> A.Imagery:
  match ps:
    case []:
      A.Plain{}
    case p <> rest:
      match p:
        case A.Picture{pk, i}:
          pick_image(String.eq(k, pk), i, picture_of(k, rest))

def nodes_json(ns: List<&2, A.Node>, +pics: List<&2, A.Picture>) -> List<&2, String>:
  match ns:
    case []:
      []
    case n <> rest:
      match n:
        case A.Node{+k, name, +role, host}:
          entity(k, name, picture_of(k, pics), role_type(role), A.role_emoji(role), [prop("key", k), prop("host", host_name(host))], ",\"role\":" ++ jstr(role_name(role))) <> nodes_json(rest, pics)

def containers_json(cs: List<&2, A.Container>, +pics: List<&2, A.Picture>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case A.Container{+k, name, +kind, owner, +on, _, _, _, +vendors, +frameworks, libraries, languages}:
          entity(k, name, picture_of(k, pics), program_type(kind), A.container_emoji(kind), [prop("key", k), prop("owner", owner_name(owner)), prop("vendors", String.join(vendors, ", ")), prop("frameworks", String.join(frameworks, ", ")), prop("libraries", String.join(libraries, ", ")), prop("languages", String.join(languages, ", "))], ",\"node\":" ++ jstr(on) ++ ",\"brands\":" ++ jlist(jstrs(List.append(&2, String, vendors, frameworks)))) <> containers_json(rest, pics)

def parts_json(ps: List<&2, A.Part>, +pics: List<&2, A.Picture>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      match p:
        case A.Part{+k, name, +lang, +i, +on}:
          entity(k, name, picture_of(k, pics), lang_name(lang) ++ " part", A.lang_emoji(lang), [prop("key", k), prop("program", i), prop("machine", on)], ",\"program\":" ++ jstr(i) ++ ",\"node\":" ++ jstr(on)) <> parts_json(rest, pics)

def links_json(ls: List<&2, A.Link>) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      match l:
        case A.Link{a, b, label, _}:
          ("{\"src\":" ++ jstr(a) ++ ",\"dst\":" ++ jstr(b) ++ ",\"label\":" ++ jstr(label) ++ "}") <> links_json(rest)


# What a product ships as: the kinds of the programs it builds itself, and a Bend library if it
# publishes packages.
def own_types(cs: List<&2, A.Container>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      match c:
        case A.Container{_, _, kind, owner, _, _, _, _, _, _, _, _}:
          keep_new(Bool.not(A.is_ours(owner)), program_type(kind), own_types(rest))

def ships_as(+s: A.System, library: Bool) -> String:
  String.join(List.append(&2, String, List.reverse(&2, String, fresh(own_types(A.containers(s)), [], [])), keep_new(Bool.not(library), "Bend library", [])), ", ")

# The graph as JSON: the system and its owner, tenants, machines, programs, parts and links, from its
# one start (the proof rules out a system with several).
def json(+s: A.System, +name: String, +image: A.Imagery, +pics: List<&2, A.Picture>, +owner: A.Party, +kind: A.SystemKind, library: Bool, +us: List<&2, A.Use>, ok: {one_start(s) == True{} : Bool}, owned: {A.can_own(owner) == True{} : Bool}, minimal: {A.uses_minimal(us) == True{} : Bool}) -> String:
  "{\"system\":" ++ entity(name, name, image, system_type(kind), A.kind_emoji(kind), [prop("ships as", ships_as(s, library))], "") ++
  ",\"owner\":" ++ party_json(owner, "") ++ ",\"users\":" ++ jlist(uses_json(us)) ++
  ",\"start\":" ++ jstr(head_or(starts(programs(s), program_links(A.links(s), s)), "")) ++
  ",\"machines\":" ++ jlist(nodes_json(A.nodes(s), pics)) ++ ",\"programs\":" ++ jlist(containers_json(A.containers(s), pics)) ++
  ",\"parts\":" ++ jlist(parts_json(A.parts(s), pics)) ++ ",\"links\":" ++ jlist(links_json(A.links(s))) ++ "}"
