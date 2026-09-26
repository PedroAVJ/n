import Base

# A device is someone's own (a phone, a laptop); a server runs the system for others.
type Role is Data:
  Device{}
  Server{}

# Where containers run: a machine, a runtime inside it, nested as deep as it is. Instances are container keys.
type Node is Data:
  Node{key: String, name: String, technology: String, role: Role, children: List<&2, Node>, instances: List<&2, String>}
