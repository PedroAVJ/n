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

def system() -> S.System:
  S.System{"v", "V", "Data structures for your Bend algorithms.", [library()],
    D.Deployment{"", [], [], [D.Node{"machine", "Their machine", "macOS or Linux", D.Device{}, H.Other{}, D.Unmanaged{}, [], ["library"]}]},
    Rl.Release{Rl.Repository{"PedroAVJ/n", True{}},
      [Rl.Package{"near-v-framework", "0.4.0.0", "v.bend", ["rose", "compound", "architecture", "view", "plan"]}],
      [Rl.Plugin{"n", "0.2.0", "n/n.bend", ["n"], Rl.Repository{"PedroAVJ/n-plugin", True{}}}]}}

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
    I.Inventory{I.Vendor{"", ""}, []},
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
