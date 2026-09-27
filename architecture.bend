import Base
import ./domain/architecture/type.bend as A
import ./domain/architecture/relationship/type.bend as Rel
import ./domain/architecture/system/type.bend as S
import ./domain/architecture/system/container/type.bend as Ct
import ./domain/architecture/system/container/component/type.bend as Co
import ./domain/architecture/system/deployment/type.bend as D
import ./domain/architecture/system/release/type.bend as Rl
import ./domain/architecture/environment/type.bend as En
import ./domain/architecture/environment/party/type.bend as P
import ./domain/architecture/environment/external/type.bend as X
import ./domain/architecture/environment/constraint/type.bend as K
import ./domain/architecture/view/type.bend as Vw
import ./domain/architecture/category/type.bend as C
import ./domain/architecture/system/deployment/host/type.bend as H
import ./domain/architecture/environment/inventory/type.bend as I
import ./domain/architecture/environment/agreement/type.bend as G
import ./n/n.bend as N
import ./domain/architecture/system/deployment/launchd/type.bend as Ld
import ./domain/architecture/system/deployment/nix_darwin/type.bend as ND

# V's own architecture: a Bend library that builders import to describe, check and deploy their systems.

def uses(+d: String, +what: String, +how: String) -> Rel.Relationship:
  Rel.Relationship{d, what, how, False{}}

def library() -> Ct.Container:
  Ct.Container{"library", "V", "Data structures for Bend: general ones, and a software system's architecture.",
    C.Library{}, Ct.Ours{}, Ct.Local{}, [], ".", [], [], [], ["Bend", "C", "JavaScript"], [], [
      Co.Component{"rose", "Rose tree", "A keyed value and any number of children.", Co.Bend{}, []},
      Co.Component{"compound", "Compound graph", "Rose trees plus edges, and lifting edges to what shows.", Co.Bend{},
        [uses("rose", "Builds on", "")]},
      Co.Component{"architecture", "Architecture", "A software system in its environment, and its laws.", Co.Bend{},
        [uses("compound", "Is a", "")]},
      Co.Component{"view", "Views", "C4's views of an architecture, drawn with D2.", Co.Bend{},
        [uses("architecture", "Draws", ""), uses("d2", "Renders diagrams with", "d2")]},
      Co.Component{"plan", "Plan and deploy", "What a deploy would change, and changing it.", Co.Bend{},
        [ uses("architecture", "Reads the release from", ""),
          uses("bend", "Publishes packages with", "bend --publish"),
          uses("github", "Pushes source to", "git") ]},
      Co.Component{"n", "N", "A type checker for prompts: flags each phrase with more than one reading before an agent acts on it.", Co.Bend{},
        [uses("openrouter", "Asks Jev which phrases are unclear through", "HTTPS"), uses("claude", "Checks each prompt as a hook of", "UserPromptSubmit")]} ], []}

# N's editor: where .n documents are written until each says exactly one thing. A Next.js app from
# PedroAVJ/n-editor, checking through N's binary; served from Pedro's Mac mini.
def editor() -> Ct.Container:
  Ct.Container{"editor", "N editor", "Where .n documents are written until each says exactly one thing: Jev screens them, Claude gives the readings.",
    C.Client{}, Ct.Ours{}, Ct.Tailnet{}, [C.Hosting{}], "", [], ["Next.js", "Tailwind CSS"], ["React", "markdown-it", "Claude Agent SDK"], ["TypeScript"], [], [],
    [uses("library", "Checks documents with N's binary", "n screen, n prompt, n read"),
     uses("openrouter", "Screens documents with Jev through", "HTTPS"),
     uses("claude", "Checks documents with", "Agent SDK")]}

def browser() -> Ct.Container:
  Ct.Container{"browser", "Safari", "The iPhone's browser.", C.Client{}, Ct.Theirs{}, Ct.Device{}, [], "", ["Apple"], [], [], [], [], [],
    [uses("editor", "Opens N's editor in", "HTTPS over the tailnet")]}

def home() -> String:
  "/Users/pedroantoniovillanuevajuarez"

# The Mac mini runs the editor as a launch agent beside what configures the rest of it, served privately on
# the tailnet at :9447: N's binary built from this repository, the editor built from its own.
def n_bin() -> String:
  home() ++ "/Library/Application Support/N/bin/n"

def editor_dir() -> String:
  home() ++ "/Library/Application Support/N/editor"

def mac_mini() -> D.Node:
  D.Node{"mac-mini", "Mac mini", "macOS", D.Server{}, H.Owned{"mac-mini"},
    D.Launchd{Ld.Launchd{
      [Ld.Program{n_bin(), Ld.Bend{"n/n.bend"}}, Ld.Program{editor_dir(), Ld.Next{"PedroAVJ/n-editor"}}],
      [Ld.Agent{"editor", "com.pedro.n-editor", "/run/current-system/sw/bin/node", [editor_dir() ++ "/server.js"],
        [Ld.Variable{"PORT", "4610"}, Ld.Variable{"HOSTNAME", "127.0.0.1"}, Ld.Variable{"N_BIN", n_bin()},
         Ld.Variable{"N_KEYCHAIN", "com.pedro.codexvoice.openrouter.v1"}], "n-editor", 4610}],
      [ND.Serve{"editor", 9447, 4610, ""}]}}, [], ["editor"]}

def system() -> S.System:
  S.System{"v", "V", "Data structures for your Bend algorithms.", [library(), editor(), browser()],
    D.Deployment{"https://pedros-mac-mini.tail90fb4c.ts.net:9447", [], [], [
      D.Node{"machine", "Their machine", "macOS or Linux", D.Device{}, H.Other{}, D.Unmanaged{}, [], ["library"]},
      mac_mini(),
      D.Node{"iphone", "iPhone", "iOS", D.Device{}, H.Owned{"iphone"}, D.Unmanaged{}, [], ["browser"]}]},
    Rl.Release{Rl.Repository{"PedroAVJ/n", True{}},
      [Rl.Package{"near-v-framework", "0.6.0.0", "v.bend", ["rose", "compound", "architecture", "view", "plan"]}],
      [Rl.Plugin{"n", N.version(), "n/n.bend", ["n"], Rl.Repository{"PedroAVJ/near-plugins", True{}}}]}}

def external(+k: String, +n: String, +d: String, c: C.Category, us: List<&2, Rel.Relationship>) -> X.External:
  X.External{k, n, d, c, [], [], [], us}

def environment() -> En.Environment:
  En.Environment{
    [P.Organization{"builders", "Builders", "Build systems in Bend and prove their laws.", P.Community{},
      [uses("architecture", "Describe their systems with", "Bend import"), uses("bend", "Run their system.bend with", "bend")]}],
    [ external("bend", "Bend", "Checks, proves, runs and publishes Bend programs.", C.Cli{}, [uses("hub", "Publishes packages to", "HTTPS")]),
      external("hub", "Bend hub", "Hosts Bend packages.", C.DataApi{}, []),
      external("github", "GitHub", "Hosts V's source.", C.DataApi{}, []),
      external("d2", "D2", "Draws diagrams from text.", C.Cli{}, []),
      external("openrouter", "OpenRouter", "Serves Jev, the model that reads each phrase.", C.ModelApi{}, []),
      external("claude", "Claude Code", "Runs N before it reads a prompt.", C.Cli{}, []) ],
    [K.OpenSource{}],
    I.Inventory{I.Vendor{"Apple", "iCloud"}, [I.Device{"mac-mini", "Mac mini", "macOS"}, I.Device{"iphone", "iPhone", "iOS"}]},
    G.Agreement{"", [], [], []}}

def architecture() -> A.Architecture:
  A.Architecture{system(), environment()}

def views() -> List<&2, Vw.Named>:
  [ Vw.Named{"v-1-context", Vw.Context{}},
    Vw.Named{"v-2-containers", Vw.Containers{}},
    Vw.Named{"v-3-components", Vw.Components{"library"}},
    Vw.Named{"v-4-deployment", Vw.Deployment{}},
    Vw.Named{"v-5-dynamic-deploy", Vw.Dynamic{[
      Vw.Step{"builders", "bend", "Run bend system.bend deploy", "terminal"},
      Vw.Step{"bend", "plan", "Checks the laws, then plans", ""},
      Vw.Step{"plan", "bend", "Publishes what changed", "bend --publish"},
      Vw.Step{"bend", "hub", "Uploads the package", "HTTPS"},
      Vw.Step{"plan", "github", "Pushes the source", "git"} ]}} ]
