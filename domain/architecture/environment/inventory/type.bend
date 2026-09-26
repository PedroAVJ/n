import Base

# A physical device the owner has.
type Device is Data:
  Device{key: String, name: String, platform: String}

# The owner's cloud vendor.
type Vendor is Data:
  Vendor{name: String, cloud: String}

# What the owner has: its vendor and its devices.
type Inventory is Data:
  Inventory{vendor: Vendor, devices: List<&2, Device>}
