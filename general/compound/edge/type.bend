import Base

# An edge between two keys: what the source does with the destination, and how.
type Edge is Data:
  Edge{source: String, destination: String, label: String, technology: String}
