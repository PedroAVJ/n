import Base

# What a container or an outside system is. Client: the app, on a user's device or served to it.
# DataApi: answers queries on records and changes them. Harness: an agent harness, the loop around a
# model. Proxy: forwards connections, adding what the other side lacks (TLS, authentication).
# ModelApi: answers model calls. Cli: a command a person runs. Worker: moves data between data APIs,
# with no API of its own. Library: code other programs import.
type Category is Data:
  Client{}
  DataApi{}
  Harness{}
  Proxy{}
  ModelApi{}
  Cli{}
  Worker{}
  Library{}

# What it provides. Hosting: serving the app itself (its HTML and scripts). Observability: receiving
# errors, traces and logs.
type Capability is Data:
  Hosting{}
  Realtime{}
  BlobStore{}
  Observability{}
