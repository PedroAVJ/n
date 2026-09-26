import Base
import ./service/type.bend as Sv
import ./setting/type.bend as St
import ./brew/type.bend as Br

# A tailnet HTTPS port served from a container's local port and path.
type Serve is Data:
  Serve{container: String, https: U32, port: U32, path: String}

# A program allowed to listen beyond 127.0.0.1, by process name, and what it belongs to: a container, a
# node, or "macos".
type Listening is Data:
  Listening{process: String, of: String}

# A Mac configured by nix-darwin: its flake host and platform, its user and where logs go, whether
# Tailscale runs from Nix, its settings, firewall and Homebrew, the services and serves the system runs
# on it, the listeners and launch agents it allows, and the flake's extra Nix bindings and config lines.
type NixDarwin is Data:
  NixDarwin{host: String, platform: String, user: String, logs: String, tailscale: Bool, settings: List<&2, St.Setting>, firewall: St.Firewall, brews: List<&2, Br.Brew>, services: List<&2, Sv.Service>, serves: List<&2, Serve>, listeners: List<&2, Listening>, kept: List<&2, String>, lets: String, config: String}
