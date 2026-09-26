import Base
import ./type.bend as I

def owns.go(xs: List<&2, I.Device>, +key: String, +name: String) -> Bool:
  match xs:
    case []:
      False{}
    case I.Device{+k, +n, _} <> rest:
      (String.eq(key, k) && String.eq(name, n)) || owns.go(rest, key, name)

# Whether the owner has the device with this key, under this name.
def owns(inv: I.Inventory, +key: String, +name: String) -> Bool:
  match inv:
    case I.Inventory{_, devices}:
      owns.go(devices, key, name)

# Whether this provider is the owner's vendor's cloud.
def cloud_ok(inv: I.Inventory, +provider: String) -> Bool:
  match inv:
    case I.Inventory{I.Vendor{_, cloud}, _}:
      String.eq(provider, cloud)
