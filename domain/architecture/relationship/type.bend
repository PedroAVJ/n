import Base

# A relationship, stored on its source: the destination's key, what the source does with it, and how.
type Relationship is Data:
  Relationship{destination: String, description: String, technology: String}
