import Base
import ./host/type.bend as H
import ./nix_darwin/type.bend as ND
import ./azure/type.bend as Az
import ./launchd/type.bend as Ld

# A device is someone's own (a phone, a laptop); a server runs the system for others.
type Role is Data:
  Device{}
  Server{}

# What configures a node: nothing V manages, nix-darwin, an Azure subscription, or only the launch agents and
# Tailscale serves V declares on a Mac something else configures.
type Platform is Data:
  Unmanaged{}
  Darwin{config: ND.NixDarwin}
  AzureCloud{config: Az.Azure}
  Launchd{config: Ld.Launchd}

# Where containers run: a machine, a runtime inside it, nested as deep as it is. Instances are container keys.
type Node is Data:
  Node{key: String, name: String, technology: String, role: Role, host: H.Host, platform: Platform, children: List<&2, Node>, instances: List<&2, String>}

# What a deploy breaks, compared with what was deployed before.
type Break is Data:
  AddressChanged{}
  StoreRemoved{name: String}

# Where the system runs: the address it is reached at, the data stores that must survive a deploy, the
# breaks accepted for the next deploy, and the nodes.
type Deployment is Data:
  Deployment{address: String, stores: List<&2, String>, accepted: List<&2, Break>, nodes: List<&2, Node>}
