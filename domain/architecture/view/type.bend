import Base

# One numbered step of a dynamic view.
type Step is Data:
  Step{source: String, destination: String, description: String, technology: String}

# C4's levels of zoom over one architecture. Context: the system among its people and the systems
# around it. Containers: inside the system. Components: inside one container. Deployment: the
# machines and what runs on them. Dynamic: numbered steps of one flow.
type View is Data:
  Context{}
  Containers{}
  Components{container: String}
  Deployment{}
  Dynamic{steps: List<&2, Step>}

# A view with the name its drawing is saved under.
type Named is Data:
  Named{name: String, view: View}
