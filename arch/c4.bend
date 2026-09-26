import Base
import ../c4/c4.bend as C

# V in C4: builders run the v command and import the V library on their own machines.
def model() -> C.Model:
  C.Model{
    [C.Person{"builders", "Builders", "Build systems in Bend and prove their laws."}],
    [ C.SoftwareSystem{"v", "V", "Checks a system's laws, then plans and deploys it.", [
        C.Container{"cli", "v", "The command: check, import, dryrun, plan, deploy, diagram.", "Bend 2, C", [
          C.Component{"command", "v command", "Reads the project's architecture and runs each step.", "Bend 2"},
          C.Component{"proc", "Run-a-program effect", "Runs other programs and returns their output.", "C"} ]},
        C.Container{"library", "V library", "Arc and the deploy library, imported by a project's Bend code.", "Bend 2", [
          C.Component{"arc", "Arc", "Architecture types and their laws.", "Bend 2"},
          C.Component{"deploy", "Deploy library", "Targets: nix-darwin, Tailscale Serve, the Bend hub, GitHub, Azure.", "Bend 2"},
          C.Component{"c4", "C4", "The C4 metamodel and its views, drawn with D2.", "Bend 2"} ]} ]},
      C.SoftwareSystem{"bend", "Bend", "Checks, proves, runs and publishes Bend programs.", []},
      C.SoftwareSystem{"hub", "Bend hub", "Hosts Bend packages.", []},
      C.SoftwareSystem{"github", "GitHub", "Hosts V's source.", []},
      C.SoftwareSystem{"nix", "nix-darwin", "Configures a Mac from a Nix flake.", []},
      C.SoftwareSystem{"tailscale", "Tailscale", "Serves a machine's ports privately on the tailnet.", []},
      C.SoftwareSystem{"azure", "Azure", "Microsoft's cloud.", []},
      C.SoftwareSystem{"d2", "D2", "Draws diagrams from text.", []} ],
    [ C.Relationship{"builders", "command", "Runs", "terminal"},
      C.Relationship{"builders", "arc", "Describes their systems with", "Bend import"},
      C.Relationship{"command", "arc", "Reads architectures with", ""},
      C.Relationship{"command", "deploy", "Plans and deploys with", ""},
      C.Relationship{"command", "proc", "Runs programs through", ""},
      C.Relationship{"deploy", "arc", "Builds on", ""},
      C.Relationship{"proc", "bend", "Checks, proves and publishes with", "bend"},
      C.Relationship{"proc", "github", "Pushes source to", "git"},
      C.Relationship{"proc", "nix", "Applies Mac configuration with", "darwin-rebuild"},
      C.Relationship{"proc", "tailscale", "Serves ports with", "tailscale serve"},
      C.Relationship{"proc", "azure", "Snapshots resources in", "az"},
      C.Relationship{"proc", "d2", "Renders diagrams with", "d2"},
      C.Relationship{"bend", "hub", "Publishes packages to", "HTTPS"} ]}

def main() -> IO(Unit):
  C.render(model(), "../../arc-viewer/c4", [
    C.Render{"v-1-context", C.Context{"v"}},
    C.Render{"v-2-containers", C.Containers{"v"}},
    C.Render{"v-3-components-cli", C.Components{"cli"}},
    C.Render{"v-3-components-library", C.Components{"library"}} ])
