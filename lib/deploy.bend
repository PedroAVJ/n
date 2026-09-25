import Base
import ../arc/arc.bend as A

# V's deployment layer for an Arc system: services, routes, how each runs, what a change breaks,
# and the minimality checks against a machine (launch agents, listeners). A project supplies the data.

def str_eq(a: String, b: String) -> Bool:
  String.eq(a, b)

def has(+s: String, xs: List<&2, String>) -> Bool:
  A.has(s, xs)

# A declared stack item or source extension that is still being migrated.
type Migration is Data:
  Migration{container: String, missing: String}

def migration(+key: String, +name: String, xs: List<&2, Migration>) -> Bool:
  match xs:
    case []:
      False{}
    case m <> rest:
      match m:
        case Migration{k, n}:
          (str_eq(key, k) && str_eq(name, n)) || migration(key, name, rest)

# Names on a canvas are readable names; snapshots record package names.
def package_name(name: String) -> String:
  match name:
    case "Next.js": "next"
    case "Tailwind CSS": "tailwindcss"
    case "React": "react"
    case "shadcn/ui": "shadcn/ui"
    case "Convex": "convex"
    case "OpenRouter SDK": "@openrouter/sdk"
    case "Sentry SDK": "@sentry/nextjs"
    case "whatsmeow": "go.mau.fi/whatsmeow"
    case _: name

def stack_item(+key: String, +name: String, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  has(key ++ ":" ++ package_name(name), deps) || migration(key, name, ms)

def stack_items(+key: String, xs: List<&2, String>, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match xs:
    case []:
      True{}
    case name <> rest:
      stack_item(key, name, deps, ms) && stack_items(key, rest, deps, ms)

def container_stack(c: A.Container, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match c:
    case A.Container{+key, _, _, _, _, _, _, source, _, frameworks, libraries, _}:
      String.is_empty(source) || (stack_items(key, frameworks, deps, ms) && stack_items(key, libraries, deps, ms))

def containers_stack(xs: List<&2, A.Container>, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match xs:
    case []:
      True{}
    case c <> rest:
      container_stack(c, deps, ms) && containers_stack(rest, deps, ms)

# A source container calling a model API needs the API's declared SDK.
def model_sdk_caller(caller: A.Container, sdk: List<&2, String>, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match caller:
    case A.Container{key, _, _, _, _, _, _, source, _, _, _, _}:
      String.is_empty(source) || stack_items(key, sdk, deps, ms)

def model_sdk_target(target: A.Container, caller: A.Container, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match target:
    case A.Container{_, _, A.ModelApi{}, _, _, _, _, _, _, _, sdk, _}:
      model_sdk_caller(caller, sdk, deps, ms)
    case _:
      True{}

def model_sdk(link: A.Link, +s: A.System, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match link:
    case A.Link{src, dst, _, _}:
      model_sdk_target(A.container(A.home(dst, s), A.containers(s)), A.container(A.home(src, s), A.containers(s)), deps, ms)

def model_sdks(xs: List<&2, A.Link>, +s: A.System, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match xs:
    case []:
      True{}
    case link <> rest:
      model_sdk(link, s, deps, ms) && model_sdks(rest, s, deps, ms)

def stack_present(+s: A.System, +deps: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  containers_stack(A.containers(s), deps, ms) && model_sdks(A.links(s), s, deps, ms)

def language_extension(+name: String, +ext: String) -> Bool:
  (str_eq(name, "TypeScript") && (str_eq(ext, ".ts") || str_eq(ext, ".tsx"))) ||
  (str_eq(name, "Go") && str_eq(ext, ".go")) ||
  (str_eq(name, "JavaScript") && (str_eq(ext, ".js") || str_eq(ext, ".mjs") || str_eq(ext, ".jsx"))) ||
  (str_eq(name, "Python") && str_eq(ext, ".py"))

def any_language(+ext: String, xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      False{}
    case name <> rest:
      language_extension(name, ext) || any_language(ext, rest)

def extension_ok(+key: String, fields: List<&2, String>, +languages: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match fields:
    case k <> +ext <> _:
      Bool.not(str_eq(key, k)) || any_language(ext, languages) || migration(key, ext, ms)
    case _:
      True{}

def extensions_ok(+key: String, xs: List<&2, String>, +languages: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match xs:
    case []:
      True{}
    case entry <> rest:
      extension_ok(key, String.split(entry, ':'), languages, ms) && extensions_ok(key, rest, languages, ms)

def container_languages(c: A.Container, +extensions: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match c:
    case A.Container{key, _, _, _, _, _, _, source, _, _, _, languages}:
      String.is_empty(source) || extensions_ok(key, extensions, languages, ms)

def stack_languages(xs: List<&2, A.Container>, +extensions: List<&2, String>, +ms: List<&2, Migration>) -> Bool:
  match xs:
    case []:
      True{}
    case c <> rest:
      container_languages(c, extensions, ms) && stack_languages(rest, extensions, ms)

# ---- deployment facts ----
# The address a system is reached at, and the data stores that must survive.
type Deployment is Data:
  Deployment{url: String, stores: List<&2, String>}

# ---- compatibility: what a change breaks, compared to what was applied ----
type Break is Data:
  UrlChanged{}
  StoreRemoved{name: String}

def keep(present: Bool, o: String, rest: List<&2, Break>) -> List<&2, Break>:
  match present:
    case True{}:
      rest
    case False{}:
      StoreRemoved{o} <> rest

def removed(olds: List<&2, String>, +news: List<&2, String>) -> List<&2, Break>:
  match olds:
    case []:
      []
    case +o <> rest:
      keep(has(o, news), o, removed(rest, news))

def url_break(same: Bool) -> List<&2, Break>:
  match same:
    case True{}:
      []
    case False{}:
      [UrlChanged{}]

def breaks(old: Deployment, new: Deployment) -> List<&2, Break>:
  match old new:
    case Deployment{ou, os} Deployment{nu, ns}:
      List.append(&2, Break, url_break(str_eq(ou, nu)), removed(os, ns))

def break_eq(a: Break, b: Break) -> Bool:
  match a b:
    case UrlChanged{} UrlChanged{}:
      True{}
    case StoreRemoved{x} StoreRemoved{y}:
      str_eq(x, y)
    case _ _:
      False{}

def is_empty(b: List<&2, Break>) -> Bool:
  match b:
    case []:
      True{}
    case _ <> _:
      False{}

def breaks_eq(a: List<&2, Break>, b: List<&2, Break>) -> Bool:
  match a:
    case []:
      is_empty(b)
    case x <> xs:
      match b:
        case []:
          False{}
        case y <> ys:
          break_eq(x, y) && breaks_eq(xs, ys)

# ---- services: how each container is installed and served ----
# port: where it listens locally; serve: its private Tailscale HTTPS port (0 = not served).
type Service is Data:
  Service{container: A.Container, label: String, script: String, port: U32, serve: U32}

def serve_of(s: Service) -> U32:
  match s:
    case Service{_, _, _, _, serve}:
      serve

def serves(xs: List<&2, Service>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case s <> rest:
      serve_of(s) <> serves(rest)

def not_in(+p: U32, xs: List<&2, U32>) -> Bool:
  match xs:
    case []:
      True{}
    case q <> rest:
      (U32.is_eq(p, 0) || Bool.not(U32.is_eq(p, q))) && not_in(p, rest)

# No two services claim the same Tailscale port.
def distinct(xs: List<&2, U32>) -> Bool:
  match xs:
    case []:
      True{}
    case +p <> +rest:
      not_in(p, rest) && distinct(rest)

# A private-network HTTPS port served by a path on a service's local port (e.g. an app's URL -> its data API's HTTP routes).
type Route is Data:
  Route{container: A.Container, serve: U32, port: U32, path: String}

def route_serves(xs: List<&2, Route>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case r <> rest:
      match r:
        case Route{_, serve, _, _}:
          serve <> route_serves(rest)

# Every private-network port served: the services' and the routes'.
def all_serves(ss: List<&2, Service>, rs: List<&2, Route>) -> List<&2, U32>:
  List.append(&2, U32, serves(ss), route_serves(rs))

# Only private containers on a server run as services.
def on_server(c: A.Container, +ns: List<&2, A.Node>) -> Bool:
  A.is_server(A.node_role(A.con(c), ns))

def service_ok(s: Service, +ns: List<&2, A.Node>) -> Bool:
  match s:
    case Service{+c, _, _, _, _}:
      on_server(c, ns) && A.private_ok(c, ns)

# ---- exposure is honest ----
def eq_bool(a: Bool, b: Bool) -> Bool:
  match a:
    case True{}:
      b
    case False{}:
      Bool.not(b)

def served_service(+k: String, xs: List<&2, Service>) -> Bool:
  match xs:
    case []:
      False{}
    case s <> rest:
      match s:
        case Service{c, _, _, _, serve}:
          (str_eq(k, A.ckey(c)) && Bool.not(U32.is_eq(serve, 0))) || served_service(k, rest)

def served_route(+k: String, xs: List<&2, Route>) -> Bool:
  match xs:
    case []:
      False{}
    case r <> rest:
      match r:
        case Route{c, _, _, _}:
          str_eq(k, A.ckey(c)) || served_route(k, rest)

# On a server, a container is on the private network exactly when it is served there; otherwise it is local.
def exposure_honest(c: A.Container, +ss: List<&2, Service>, +rs: List<&2, Route>, +ns: List<&2, A.Node>) -> Bool:
  match c:
    case A.Container{+k, _, _, _, on, exposure, _, _, _, _, _, _}:
      Bool.not(A.is_server(A.node_role(on, ns))) || eq_bool(A.is_tailnet(exposure), served_service(k, ss) || served_route(k, rs))

def all_exposure_honest(xs: List<&2, A.Container>, +ss: List<&2, Service>, +rs: List<&2, Route>, +ns: List<&2, A.Node>) -> Bool:
  match xs:
    case []:
      True{}
    case c <> rest:
      exposure_honest(c, ss, rs, ns) && all_exposure_honest(rest, ss, rs, ns)

def route_ok(r: Route, +ns: List<&2, A.Node>) -> Bool:
  match r:
    case Route{+c, _, _, _}:
      on_server(c, ns) && A.private_ok(c, ns)

def all_routes_ok(xs: List<&2, Route>, +ns: List<&2, A.Node>) -> Bool:
  match xs:
    case []:
      True{}
    case r <> rest:
      route_ok(r, ns) && all_routes_ok(rest, ns)

def all_services_ok(xs: List<&2, Service>, +ns: List<&2, A.Node>) -> Bool:
  match xs:
    case []:
      True{}
    case s <> rest:
      service_ok(s, ns) && all_services_ok(rest, ns)

def port_of(s: Service) -> U32:
  match s:
    case Service{_, _, _, port, _}:
      port

def ports(xs: List<&2, Service>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case s <> rest:
      port_of(s) <> ports(rest)

# No declared port (other than 0, "none") is in `taken`.
def clear_of(xs: List<&2, U32>, +taken: List<&2, U32>) -> Bool:
  match xs:
    case []:
      True{}
    case +p <> rest:
      not_in(p, taken) && clear_of(rest, taken)

# ---- how each service runs (pinned by Nix) ----
type Prog is Data:
  RunNode{}
  RunPython{}
  RunBash{}

# An environment variable: a plain value, or a Nix expression (e.g. a path in a derivation the project defines).
type Env is Data:
  Env{key: String, value: String}
  NixEnv{key: String, expr: String}

# When a service starts: at login (in the user's session: login Keychain, apps) or at boot (no session).
type Start is Data:
  AtLogin{}
  AtBoot{}

type Run is Data:
  Run{label: String, prog: Prog, args: List<&2, String>, dir: String, env: List<&2, Env>, log: String, start: Start}

# ---- machine minimality: every launch agent is declared ----
def run_label(r: Run) -> String:
  match r:
    case Run{label, _, _, _, _, _, _}:
      label

# ---- surviving a reboot ----
def at_login(s: Start) -> Bool:
  match s:
    case AtLogin{}:
      True{}
    case AtBoot{}:
      False{}

def needs_login(xs: List<&2, Run>) -> Bool:
  match xs:
    case []:
      False{}
    case r <> rest:
      match r:
        case Run{_, _, _, _, _, _, s}:
          at_login(s) || needs_login(rest)

# Services that start at login need the machine to log `user` in by itself.
def survives_reboot(xs: List<&2, Run>, auto_login_user: String, user: String) -> Bool:
  Bool.not(needs_login(xs)) || String.eq(auto_login_user, user)

def run_labels(xs: List<&2, Run>) -> List<&2, String>:
  match xs:
    case []:
      []
    case r <> rest:
      run_label(r) <> run_labels(rest)

# ---- network minimality: every program reachable from other machines is declared ----
# A program allowed to listen beyond 127.0.0.1, by process name, and what it belongs to: a container's key, or "macos".
type Listener is Data:
  Listener{process: String, of: String}

def listener_processes(xs: List<&2, Listener>) -> List<&2, String>:
  match xs:
    case []:
      []
    case l <> rest:
      match l:
        case Listener{p, _}:
          p <> listener_processes(rest)

def listener_owners(xs: List<&2, Listener>) -> List<&2, String>:
  match xs:
    case []:
      []
    case l <> rest:
      match l:
        case Listener{_, o}:
          o <> listener_owners(rest)

def keep_listener(known: Bool, e: String, rest: List<&2, String>) -> List<&2, String>:
  match known:
    case True{}:
      rest
    case False{}:
      e <> rest

def head_or_empty(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case w <> _:
      w

def first_word(s: String) -> String:
  head_or_empty(String.split(s, ' '))

# The exposed listeners ("process port") whose process nothing declares.
def undeclared_listeners(xs: List<&2, String>, +declared: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +e <> rest:
      keep_listener(has(first_word(e), declared), e, undeclared_listeners(rest, declared))

# Launch agents the project declares: its services' and the ones it keeps.
def declared_agents(rs: List<&2, Run>, kept: List<&2, String>) -> List<&2, String>:
  List.append(&2, String, run_labels(rs), kept)

def pick_undeclared(known: Bool, a: String, rest: List<&2, String>) -> List<&2, String>:
  match known:
    case True{}:
      rest
    case False{}:
      a <> rest

# The loaded agents that nothing declares.
def undeclared(xs: List<&2, String>, +declared: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +a <> rest:
      pick_undeclared(has(a, declared), a, undeclared(rest, declared))

# ---- the deploy plan, one step per line, for `v system deploy` to execute ----
#   service <launchd label> <install script>
#   serve <private-network https port> <local port>[path]
def plan_serve(none: Bool, serve: U32, port: U32) -> String:
  match none:
    case True{}:
      ""
    case False{}:
      "serve " ++ U32.show(serve) ++ " " ++ U32.show(port) ++ "\n"

def plan_step(s: Service) -> String:
  match s:
    case Service{_, label, script, port, +serve}:
      "service " ++ label ++ " " ++ script ++ "\n" ++ plan_serve(U32.is_eq(serve, 0), serve, port)

def plan_steps(xs: List<&2, Service>) -> String:
  match xs:
    case []:
      ""
    case s <> rest:
      plan_step(s) ++ plan_steps(rest)

def plan_routes(xs: List<&2, Route>) -> String:
  match xs:
    case []:
      ""
    case r <> rest:
      match r:
        case Route{_, serve, port, path}:
          "serve " ++ U32.show(serve) ++ " " ++ U32.show(port) ++ path ++ "\n" ++ plan_routes(rest)

def plan(ss: List<&2, Service>, rs: List<&2, Route>) -> String:
  plan_steps(ss) ++ plan_routes(rs)

# ---- the deployment as text: its URL, then its stores ----
def quoted_names(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      "\"" ++ x ++ "\", " ++ quoted_names(rest)

def show_deployment(d: Deployment) -> String:
  match d:
    case Deployment{url, stores}:
      url ++ "\n" ++ quoted_names(stores)

# ---- where a project deploys: only what it declares runs ----
# NixDarwin: configure a Mac with nix-darwin (its flake host). TailscaleServe: serve the plan's ports on the
# private network. BendHub: publish the project's packages. AzureSnapshot: read-only ARM and DevOps facts.
# GitHub: push the project's repository (owner/name) to its main branch; public says whether it is open.
type Target is Data:
  NixDarwin{host: String}
  TailscaleServe{}
  BendHub{}
  AzureSnapshot{organization: String, project: String}
  GitHub{repo: String, public: Bool}

# A package published to the Bend hub: its name, version (four numbers), entry file (relative to the
# project) and the parts of the project it ships.
type Package is Data:
  Package{name: String, version: String, entry: String, parts: List<&2, String>}

# ---- no dead code, Bend only ----
# Every library definition is an entry point for whoever imports it, so a repository of packages has
# dead code exactly when a source file ships in no package.
def listed(+x: String, ys: List<&2, String>) -> Bool:
  match ys:
    case []:
      False{}
    case y <> rest:
      String.eq(x, y) || listed(x, rest)

def is_source(+f: String) -> Bool:
  String.ends_with(f, ".bend") || String.ends_with(f, ".c")

def first_or_empty(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> _:
      x

def base_name(f: String) -> String:
  first_or_empty(List.reverse(&2, String, String.split(f, '/')))

# A file that is neither Bend source nor a C effect: only the license, readme and ignore list may be.
def allowed(+f: String) -> Bool:
  is_source(f) || String.eq(base_name(f), "LICENSE") || String.eq(f, "README.md") || String.eq(f, ".gitignore")

def bend_only(fs: List<&2, String>) -> Bool:
  match fs:
    case []:
      True{}
    case +f <> rest:
      allowed(f) && bend_only(rest)

# The project's own folder (its architecture) is configuration, not shipped code.
def needs_shipping(+f: String, +project: String) -> Bool:
  is_source(f) && Bool.not(String.starts_with(f, project ++ "/"))

def no_dead_code(fs: List<&2, String>, +project: String, +shipped: List<&2, String>) -> Bool:
  match fs:
    case []:
      True{}
    case +f <> rest:
      (Bool.not(needs_shipping(f, project)) || listed(f, shipped)) && no_dead_code(rest, project, shipped)

# ---- the repository is deployed through V ----
def is_github(t: Target) -> Bool:
  match t:
    case GitHub{_, _}:
      True{}
    case NixDarwin{_}:
      False{}
    case TailscaleServe{}:
      False{}
    case BendHub{}:
      False{}
    case AzureSnapshot{_, _}:
      False{}

def has_github(ts: List<&2, Target>) -> Bool:
  match ts:
    case []:
      False{}
    case t <> rest:
      is_github(t) || has_github(rest)

def vendor_github(vs: List<&2, String>) -> Bool:
  match vs:
    case []:
      False{}
    case v <> rest:
      String.eq(v, "GitHub") || vendor_github(rest)

def on_github(cs: List<&2, A.Container>) -> Bool:
  match cs:
    case []:
      False{}
    case c <> rest:
      match c:
        case A.Container{_, _, _, _, _, _, _, _, vs, _, _, _}:
          vendor_github(vs) || on_github(rest)

# A system whose source lives on GitHub declares a GitHub target, so `v system deploy` is how it gets there.
def source_deployed(+s: A.System, ts: List<&2, Target>) -> Bool:
  Bool.not(on_github(A.containers(s))) || has_github(ts)

def visibility(p: Bool) -> String:
  match p:
    case True{}:
      "public"
    case False{}:
      "private"

def is_bend_hub(t: Target) -> Bool:
  match t:
    case BendHub{}:
      True{}
    case GitHub{_, _}:
      False{}
    case NixDarwin{_}:
      False{}
    case TailscaleServe{}:
      False{}
    case AzureSnapshot{_, _}:
      False{}

def has_bend_hub(ts: List<&2, Target>) -> Bool:
  match ts:
    case []:
      False{}
    case t <> rest:
      is_bend_hub(t) || has_bend_hub(rest)

def public_github(ts: List<&2, Target>) -> Bool:
  match ts:
    case []:
      False{}
    case t <> rest:
      match t:
        case GitHub{_, p}:
          p || public_github(rest)
        case BendHub{}:
          public_github(rest)
        case NixDarwin{_}:
          public_github(rest)
        case TailscaleServe{}:
          public_github(rest)
        case AzureSnapshot{_, _}:
          public_github(rest)

# What a project publishes to the Bend hub is open source, so its repository is public too.
# `v system deploy` checks the repository's real visibility against the declaration.
def open_source(+ts: List<&2, Target>) -> Bool:
  Bool.not(has_bend_hub(ts)) || public_github(ts)

def digits_only(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case c <> rest:
      Char.is_digit(c) && digits_only(rest)

def all_numbers(xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case +x <> rest:
      Bool.not(String.is_empty(x)) && digits_only(String.to_list(x)) && all_numbers(rest)

def name_chars(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case +c <> rest:
      (Char.is_lower(c) || Char.is_digit(c) || Char.is_eq(c, '-')) && name_chars(rest)

# The hub's rules: a name is 12 to 64 characters of a-z, 0-9 and -; a version is four numbers.
def package_ok(p: Package) -> Bool:
  match p:
    case Package{+n, +v, _, _}:
      Nat.is_ge(String.length(n), 12n) && Nat.is_le(String.length(n), 64n) && name_chars(String.to_list(n)) &&
      Nat.is_eq(List.length(&2, String, String.split(v, '.')), 4n) && all_numbers(String.split(v, '.'))

def packages_ok(xs: List<&2, Package>) -> Bool:
  match xs:
    case []:
      True{}
    case p <> rest:
      package_ok(p) && packages_ok(rest)

def package_parts(xs: List<&2, Package>) -> List<&2, String>:
  match xs:
    case []:
      []
    case Package{_, _, _, ps} <> rest:
      List.append(&2, String, ps, package_parts(rest))

# Everything the project is made of ships in a declared package: an open-source project is what it
# publishes, so an unpublished part cannot be used.
def parts_published(+s: A.System, xs: List<&2, Package>) -> Bool:
  A.all_in(A.pkeys(A.parts(s)), package_parts(xs))

# ---- facts `v` reads from a project: where V's library is, its targets, services and packages ----
def fact_lines(+k: String, xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      k ++ " " ++ x ++ "\n" ++ fact_lines(k, rest)

def service_ports(xs: List<&2, Service>) -> List<&2, String>:
  match xs:
    case []:
      []
    case s <> rest:
      U32.show(port_of(s)) <> service_ports(rest)

def target_line(t: Target) -> String:
  match t:
    case NixDarwin{h}:
      "target nix-darwin " ++ h ++ "\n"
    case TailscaleServe{}:
      "target tailscale-serve\n"
    case BendHub{}:
      "target bend-hub\n"
    case AzureSnapshot{org, project}:
      "target azure " ++ org ++ " " ++ project ++ "\n"
    case GitHub{r, p}:
      "target github " ++ r ++ " " ++ visibility(p) ++ "\n"

def target_lines(xs: List<&2, Target>) -> String:
  match xs:
    case []:
      ""
    case t <> rest:
      target_line(t) ++ target_lines(rest)

def package_lines(xs: List<&2, Package>) -> String:
  match xs:
    case []:
      ""
    case p <> rest:
      match p:
        case Package{n, v, e, _}:
          "package " ++ n ++ " " ++ v ++ " " ++ e ++ "\n" ++ package_lines(rest)

def source_line(empty: Bool, key: String, source: String) -> String:
  match empty:
    case True{}:
      ""
    case False{}:
      "source " ++ key ++ " " ++ source ++ "\n"

def source_lines(xs: List<&2, A.Container>) -> String:
  match xs:
    case []:
      ""
    case c <> rest:
      match c:
        case A.Container{key, _, _, _, _, _, _, +source, _, _, _, _}:
          source_line(String.is_empty(source), key, source) ++ source_lines(rest)

def facts(vlib: String, ts: List<&2, Target>, rs: List<&2, Run>, ss: List<&2, Service>, ps: List<&2, Package>, cs: List<&2, A.Container>) -> String:
  "vlib " ++ vlib ++ "\n" ++ target_lines(ts) ++ fact_lines("label", run_labels(rs)) ++ fact_lines("port", service_ports(ss)) ++ package_lines(ps) ++ source_lines(cs)

# ---- the nix-darwin flake: pinned inputs, the machine's module, and one launchd job per run ----
def prog(p: Prog) -> String:
  match p:
    case RunNode{}:
      "\"${pkgs.nodejs_24}/bin/node\""
    case RunPython{}:
      "\"${pkgs.python3.withPackages (ps: [ ps.watchdog ])}/bin/python3\""
    case RunBash{}:
      "\"${pkgs.bash}/bin/bash\""

def strs(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      " \"" ++ x ++ "\"" ++ strs(rest)

def env1(e: Env) -> String:
  match e:
    case Env{k, v}:
      " " ++ k ++ " = \"" ++ v ++ "\";"
    case NixEnv{k, x}:
      " " ++ k ++ " = " ++ x ++ ";"

def envs(xs: List<&2, Env>) -> String:
  match xs:
    case []:
      ""
    case e <> rest:
      env1(e) ++ envs(rest)

# At login: a launch agent in the user's session. At boot: a launch daemon that runs as the user.
def job_kind(s: Start) -> String:
  match s:
    case AtLogin{}:
      "launchd.user.agents"
    case AtBoot{}:
      "launchd.daemons"

def user_name(s: Start, +user: String) -> String:
  match s:
    case AtLogin{}:
      ""
    case AtBoot{}:
      " UserName = \"" ++ user ++ "\";"

def job(r: Run, +user: String, +logs: String) -> String:
  match r:
    case Run{+label, p, args, dir, env, +log, +start}:
      "      " ++ job_kind(start) ++ ".\"" ++ label ++ "\".serviceConfig = {\n" ++
      "        Label = \"" ++ label ++ "\";" ++ user_name(start, user) ++ "\n" ++
      "        ProgramArguments = [ " ++ prog(p) ++ strs(args) ++ " ];\n" ++
      "        WorkingDirectory = \"" ++ dir ++ "\";\n" ++
      "        EnvironmentVariables = {" ++ envs(env) ++ " };\n" ++
      "        RunAtLoad = true; KeepAlive = true; ThrottleInterval = 10;\n" ++
      "        StandardOutPath = \"" ++ logs ++ "/" ++ log ++ ".log\";\n" ++
      "        StandardErrorPath = \"" ++ logs ++ "/" ++ log ++ ".log\";\n" ++
      "      };\n"

def jobs(xs: List<&2, Run>, +user: String, +logs: String) -> String:
  match xs:
    case []:
      ""
    case r <> rest:
      job(r, user, logs) ++ jobs(rest, user, logs)

# `lets` are Nix bindings the jobs may use (e.g. a derivation); `config` is extra nix-darwin config lines.
def flake(host: String, system: String, lets: String, config: String, +user: String, +logs: String, rs: List<&2, Run>) -> String:
  "# Generated by V. Do not edit; change the project and run `v system deploy`.\n" ++
  "{\n" ++
  "  inputs.nixpkgs.url = \"github:NixOS/nixpkgs/nixpkgs-unstable\";\n" ++
  "  inputs.nix-darwin.url = \"github:nix-darwin/nix-darwin/master\";\n" ++
  "  inputs.nix-darwin.inputs.nixpkgs.follows = \"nixpkgs\";\n" ++
  "  outputs = { nixpkgs, nix-darwin, ... }: {\n" ++
  "    darwinConfigurations." ++ host ++ " = nix-darwin.lib.darwinSystem {\n" ++
  "      system = \"" ++ system ++ "\";\n" ++
  "      modules = [ ./mac.nix ({ pkgs, ... }: let\n" ++ lets ++
  "      in {\n" ++ config ++ jobs(rs, user, logs) ++ "      }) ];\n    };\n  };\n}"
