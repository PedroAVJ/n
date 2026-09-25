import Base
import near-architecture@0.9.1.0/arc.bend as Arc
import ../lib/deploy.bend as D
import ./canvas.bend as V

# V is well formed, and what runs on the machine is reachable only from it or the private network.
law well_formed:
  {Arc.well_formed(V.system()) == True{} : Bool}
law machine_private:
  {Arc.servers_private(V.system()) == True{} : Bool}
law parts_ours:
  {Arc.parts_ours(V.system()) == True{} : Bool}

# Every package V publishes follows the hub's rules (name and version); `v deploy` also requires its LICENSE.
law packages_ok:
  {D.packages_ok(V.packages()) == True{} : Bool}

# V is open source: everything it is made of (Arc, the library, the CLI, its C effect) ships in a
# published package. An unpublished part cannot be used, so nothing deploys until it is declared.
law parts_published:
  {D.parts_published(V.system(), V.packages()) == True{} : Bool}

# The repository reaches GitHub only through `v deploy`: its source lives on GitHub, so it declares a GitHub target.
law source_deployed:
  {D.source_deployed(V.system(), V.targets()) == True{} : Bool}

# What N and V publish is open source, so the repository is public; `v deploy` checks GitHub agrees.
law open_source:
  {D.open_source(V.targets()) == True{} : Bool}
