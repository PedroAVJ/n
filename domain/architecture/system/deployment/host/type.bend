import Base

# Whose machine it is: a device the owner has (by its inventory key), a provider's cloud, or someone else's.
type Host is Data:
  Owned{device: String}
  Cloud{provider: String}
  Other{}
