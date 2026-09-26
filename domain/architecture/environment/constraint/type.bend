import Base

# What the system must satisfy without designing: it is open source; it runs on a provider's cloud.
type Constraint is Data:
  OpenSource{}
  RunsOn{provider: String}
