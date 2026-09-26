import Base
import ./container/type.bend as Ct
import ./deployment/type.bend as D
import ./release/type.bend as Rl

# A software system: what you build, where it runs, and what it publishes.
type System is Data:
  System{key: String, name: String, description: String, containers: List<&2, Ct.Container>, deployment: D.Deployment, release: Rl.Release}
