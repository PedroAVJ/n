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

# V's own architecture: a Bend library that builders import to describe, check and deploy their systems.

def library() -> Ct.Container:
  Ct.Container{"library", "V", "Data structures for Bend: general ones, and a software system's architecture.", "Bend 2", Ct.Ours{}, Ct.Local{}, [], [
    Co.Component{"rose", "Rose tree", "A keyed value and any number of children.", "Bend 2", []},
    Co.Component{"compound", "Compound graph", "Rose trees plus edges, and lifting edges to what shows.", "Bend 2",
      [Rel.Relationship{"rose", "Builds on", ""}]},
    Co.Component{"architecture", "Architecture", "A software system in its environment, and its laws.", "Bend 2",
      [Rel.Relationship{"compound", "Is a", ""}]},
    Co.Component{"view", "Views", "C4's views of an architecture, drawn with D2.", "Bend 2",
      [Rel.Relationship{"architecture", "Draws", ""}, Rel.Relationship{"d2", "Renders diagrams with", "d2"}]},
    Co.Component{"plan", "Plan and deploy", "What a release would change, and changing it.", "Bend 2",
      [ Rel.Relationship{"architecture", "Reads the release from", ""},
        Rel.Relationship{"bend", "Publishes packages with", "bend --publish"},
        Rel.Relationship{"github", "Pushes source to", "git"} ]} ], []}

def system() -> S.System:
  S.System{"v", "V", "Data structures for your Bend algorithms.", [library()],
    [D.Node{"machine", "Their machine", "macOS or Linux", D.Device{}, [], ["library"]}],
    Rl.Release{Rl.Repository{"PedroAVJ/n", True{}},
      [Rl.Package{"near-v-framework", "0.3.0.0", "v.bend", ["rose", "compound", "architecture", "view", "plan"]}]}}

def environment() -> En.Environment:
  En.Environment{
    [P.Organization{"builders", "Builders", "Build systems in Bend and prove their laws.", P.Community{},
      [ Rel.Relationship{"architecture", "Describe their systems with", "Bend import"},
        Rel.Relationship{"bend", "Run their system.bend with", "bend"} ]}],
    [ X.External{"bend", "Bend", "Checks, proves, runs and publishes Bend programs.", [Rel.Relationship{"hub", "Publishes packages to", "HTTPS"}]},
      X.External{"hub", "Bend hub", "Hosts Bend packages.", []},
      X.External{"github", "GitHub", "Hosts V's source.", []},
      X.External{"d2", "D2", "Draws diagrams from text.", []} ],
    [K.OpenSource{}]}

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
