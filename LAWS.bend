import Base
import ./domain/architecture/ops.bend as O
import ./domain/architecture/system/ops.bend as SO
import ./domain/architecture/system/release/ops.bend as RlO
import ./architecture.bend as V

# V is well formed: keys are unique, and every relationship and every instance names something that exists.
law well_formed:
  {O.well_formed(V.architecture()) == True{} : Bool}

# Only V's own containers are opened up into components, and on a server everything stays private.
law components_ours:
  {O.components_ours(O.containers(V.architecture())) == True{} : Bool}
law servers_private:
  {O.servers_private(V.architecture()) == True{} : Bool}

# A device reaches a server only over the tailnet; on a server, only what a device reaches is on the
# tailnet; a data API hosts the app only while private.
law devices_via_tailnet:
  {O.devices_via_tailnet(V.architecture()) == True{} : Bool}
law exposure_follows_reach:
  {O.exposure_follows_reach(V.architecture()) == True{} : Bool}
law shared_hosting_private:
  {O.shared_hosting_private(V.architecture()) == True{} : Bool}

# Every package follows the hub's rules, and everything V is made of ships in one.
law packages_ok:
  {RlO.packages_ok(RlO.packages(SO.release(V.system()))) == True{} : Bool}
law components_published:
  {SO.components_published(V.system()) == True{} : Bool}

# V is open source, so it publishes from a public repository.
law open_source:
  {O.open_source(V.architecture()) == True{} : Bool}
