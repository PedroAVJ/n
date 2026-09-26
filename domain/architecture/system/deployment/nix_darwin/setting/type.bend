import Base

# How a setting's value is written in Nix. KNix: the value is a whole Nix expression.
type ValueKind is Data:
  KBool{}
  KInt{}
  KFloat{}
  KStr{}
  KNix{}

# One nix-darwin option, its value written as nix-darwin writes it (a string is Nix-escaped, unquoted).
type Setting is Data:
  Setting{option: String, kind: ValueKind, value: String}

# The application firewall: its options exist only while it is on.
type Firewall is Data:
  FirewallOff{}
  FirewallOn{allowSigned: Bool, allowSignedApp: Bool, blockAllIncoming: Bool, stealth: Bool}
