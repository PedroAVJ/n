import Base
import ../c4/c4.bend as C

# V in C4: builders run the v command and import the V library on their own machines.
def model() -> C.Model:
  C.Model{
    [C.Person{"builders", "Builders", "Build systems in Bend and prove their laws.", C.plain()}],
    [ C.SoftwareSystem{"v", "V", "Checks a system's laws, then plans and deploys it.", [
        C.Container{"cli", "v", "The command: check, import, dryrun, plan, deploy, diagram.", "Bend 2, C", [
          C.Component{"command", "v command", "Reads the project's architecture and runs each step.", "Bend 2", C.plain()},
          C.Component{"proc", "Run-a-program effect", "Runs other programs and returns their output.", "C", C.plain()} ], C.plain()},
        C.Container{"library", "V library", "Arc and the deploy library, imported by a project's Bend code.", "Bend 2", [
          C.Component{"arc", "Arc", "Architecture types and their laws.", "Bend 2", C.plain()},
          C.Component{"deploy", "Deploy library", "Targets: nix-darwin, Tailscale Serve, the Bend hub, GitHub, Azure.", "Bend 2", C.plain()},
          C.Component{"c4", "C4", "The C4 metamodel and its views, drawn with D2.", "Bend 2", C.plain()} ], C.plain()} ], C.plain()},
      C.SoftwareSystem{"bend", "Bend", "Checks, proves, runs and publishes Bend programs.", [], C.plain()},
      C.SoftwareSystem{"hub", "Bend hub", "Hosts Bend packages.", [], C.plain()},
      C.SoftwareSystem{"github", "GitHub", "Hosts V's source.", [], C.plain()},
      C.SoftwareSystem{"nix", "nix-darwin", "Configures a Mac from a Nix flake.", [], C.plain()},
      C.SoftwareSystem{"tailscale", "Tailscale", "Serves a machine's ports privately on the tailnet.", [], C.plain()},
      C.SoftwareSystem{"azure", "Azure", "Microsoft's cloud.", [], C.plain()},
      C.SoftwareSystem{"d2", "D2", "Draws diagrams from text.", [], C.plain()} ],
    [ C.DeploymentEnvironment{"Local", [
        C.DeploymentNode{"machine", "Their machine", "", "macOS or Linux", 1n, [], [], [],
          [C.ContainerInstance{"cli", C.plain()}, C.ContainerInstance{"library", C.plain()}], C.plain()} ]} ],
    [ C.Relationship{"builders", "command", "Runs", "terminal", C.plain()},
      C.Relationship{"builders", "arc", "Describes their systems with", "Bend import", C.plain()},
      C.Relationship{"command", "arc", "Reads architectures with", "", C.plain()},
      C.Relationship{"command", "deploy", "Plans and deploys with", "", C.plain()},
      C.Relationship{"command", "proc", "Runs programs through", "", C.plain()},
      C.Relationship{"deploy", "arc", "Builds on", "", C.plain()},
      C.Relationship{"proc", "bend", "Checks, proves and publishes with", "bend", C.plain()},
      C.Relationship{"proc", "github", "Pushes source to", "git", C.plain()},
      C.Relationship{"proc", "nix", "Applies Mac configuration with", "darwin-rebuild", C.plain()},
      C.Relationship{"proc", "tailscale", "Serves ports with", "tailscale serve", C.plain()},
      C.Relationship{"proc", "azure", "Snapshots resources in", "az", C.plain()},
      C.Relationship{"proc", "d2", "Renders diagrams with", "d2", C.plain()},
      C.Relationship{"bend", "hub", "Publishes packages to", "HTTPS", C.plain()} ]}

def workspace() -> C.Workspace:
  C.Workspace{"V", "V's architecture.", model(), [
    C.ViewDef{"v-1-context", C.SystemContext{"v"}},
    C.ViewDef{"v-2-containers", C.Containers{"v"}},
    C.ViewDef{"v-3-components-cli", C.Components{"cli"}},
    C.ViewDef{"v-3-components-library", C.Components{"library"}},
    C.ViewDef{"v-4-dynamic-deploy", C.Dynamic{"v", [
      C.Step{"builders", "command", "Runs v system deploy", "terminal"},
      C.Step{"command", "arc", "Reads the project's architecture", ""},
      C.Step{"command", "proc", "Proves the laws", ""},
      C.Step{"proc", "bend", "Checks the proofs", "bend"},
      C.Step{"command", "deploy", "Plans the changes", ""},
      C.Step{"command", "proc", "Applies them", ""},
      C.Step{"proc", "nix", "Configures the machine", "darwin-rebuild"} ]}},
    C.ViewDef{"v-5-deployment", C.Deployment{"v", "Local"}} ]}

def main() -> IO(Unit):
  C.render(workspace(), "../../arc-viewer/c4")
