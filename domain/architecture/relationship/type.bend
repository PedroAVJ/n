import Base

# A relationship, stored on its source: the destination's key, what the source does with it, how, and
# whether it is live (a connection held open, like a subscription) rather than a call.
type Relationship is Data:
  Relationship{destination: String, description: String, technology: String, live: Bool}
