import Base

# One declared or observed setting of the Mac: its nix-darwin option, how to write its value, and the value.
# KNix values are whole Nix expressions (lists, attribute sets, paths), written as they are.
# Values are kept exactly as nix-darwin would write them, so declared and observed compare directly.
type VKind is Data:
  KBool{}
  KInt{}
  KFloat{}
  KStr{}
  KNix{}

type Setting is Data:
  Setting{option: String, kind: VKind, value: String}

type Change is Data:
  Change{option: String, now: String, want: String}

def cmp_eq(c: Cmp) -> Bool:
  match c:
    case EQ{}:
      True{}
    case _:
      False{}

def snd_eq(r: (String & String) & Cmp) -> Bool:
  match r:
    case (_, c):
      cmp_eq(c)

def str_eq(a: String, b: String) -> Bool:
  snd_eq(String.cmp(a, b))

def option_of(s: Setting) -> String:
  match s:
    case Setting{o, _, _}:
      o

def value_of(s: Setting) -> String:
  match s:
    case Setting{_, _, v}:
      v

# The observed value of `option`, or "(unset)".

def pick_value(hit: Bool, s: Setting, other: String) -> String:
  match hit:
    case True{}:
      value_of(s)
    case False{}:
      other


def lookup(+option: String, now: List<&2, Setting>) -> String:
  match now:
    case []:
      "(unset)"
    case +s <> rest:
      pick_value(str_eq(option, option_of(s)), s, lookup(option, rest))

def change_if(same: Bool, option: String, now: String, want: String, rest: List<&2, Change>) -> List<&2, Change>:
  match same:
    case True{}:
      rest
    case False{}:
      Change{option, now, want} <> rest

# Dry run: every declared setting whose observed value differs.

def change_if_str(+observed: String, option: String, +value: String, rest: List<&2, Change>) -> List<&2, Change>:
  change_if(str_eq(observed, value), option, observed, value, rest)

# The nix literal for a value.

def diff_one(s: Setting, +now: List<&2, Setting>, rest: List<&2, Change>) -> List<&2, Change>:
  match s:
    case Setting{+option, _, +value}:
      change_if_str(lookup(option, now), option, value, rest)

def diff(want: List<&2, Setting>, +now: List<&2, Setting>) -> List<&2, Change>:
  match want:
    case []:
      []
    case s <> rest:
      diff_one(s, now, diff(rest, now))

def literal(k: VKind, v: String) -> String:
  match k:
    case KStr{}:
      "\"" ++ v ++ "\""
    case _:
      v

def line(s: Setting) -> String:
  match s:
    case Setting{option, k, v}:
      "  " ++ option ++ " = " ++ literal(k, v) ++ ";\n"

def lines(xs: List<&2, Setting>) -> String:
  match xs:
    case []:
      ""
    case s <> rest:
      line(s) ++ lines(rest)

# A Homebrew entry: kind is "tap", "brew", "cask", "mas" (name is the Nix attribute `"App" = id`) or "other" (a raw Brewfile line).
type Brew is Data:
  Brew{kind: String, name: String}

def brew_key(b: Brew) -> String:
  match b:
    case Brew{k, n}:
      k ++ " " ++ n

def keys(xs: List<&2, Brew>) -> List<&2, String>:
  match xs:
    case []:
      []
    case b <> rest:
      brew_key(b) <> keys(rest)

def has(+s: String, xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      False{}
    case x <> rest:
      str_eq(s, x) || has(s, rest)

def keep_if(missing: Bool, k: String, rest: List<&2, String>) -> List<&2, String>:
  match missing:
    case True{}:
      k <> rest
    case False{}:
      rest

# Entries of `a` that are not in `b`.
def minus(a: List<&2, String>, +b: List<&2, String>) -> List<&2, String>:
  match a:
    case []:
      []
    case +k <> rest:
      keep_if(Bool.not(has(k, b)), k, minus(rest, b))

# Nix for the Homebrew section: one list per kind; entries nix-darwin has no option for are raw Brewfile lines.
def kind_of(b: Brew) -> String:
  match b:
    case Brew{k, _}:
      k

def name_of(b: Brew) -> String:
  match b:
    case Brew{_, n}:
      n

def quoted_if(hit: Bool, n: String) -> String:
  match hit:
    case True{}:
      " \"" ++ n ++ "\""
    case False{}:
      ""

def names(+k: String, xs: List<&2, Brew>) -> String:
  match xs:
    case []:
      ""
    case +b <> rest:
      quoted_if(str_eq(k, kind_of(b)), name_of(b)) ++ names(k, rest)

def raw_if(hit: Bool, n: String) -> String:
  match hit:
    case True{}:
      "    " ++ n ++ "\n"
    case False{}:
      ""

def raws(xs: List<&2, Brew>) -> String:
  match xs:
    case []:
      ""
    case +b <> rest:
      raw_if(str_eq("other", kind_of(b)), name_of(b)) ++ raws(rest)

def mas_if(hit: Bool, n: String) -> String:
  match hit:
    case True{}:
      " " ++ n ++ ";"
    case False{}:
      ""

def mas(xs: List<&2, Brew>) -> String:
  match xs:
    case []:
      ""
    case +b <> rest:
      mas_if(str_eq("mas", kind_of(b)), name_of(b)) ++ mas(rest)

def brew_section(+xs: List<&2, Brew>) -> String:
  "  homebrew.taps = [" ++ names("tap", xs) ++ " ];\n" ++
  "  homebrew.masApps = {" ++ mas(xs) ++ " };\n" ++
  "  homebrew.brews = [" ++ names("brew", xs) ++ " ];\n" ++
  "  homebrew.casks = [" ++ names("cask", xs) ++ " ];\n" ++
  "  homebrew.extraConfig = ''\n" ++ raws(xs) ++ "  '';\n"

# The macOS application firewall. Its options exist only while it is on: `socketfilterfw` turns the
# firewall on whenever one of them is set, so "off, with options" cannot be written.
type Firewall is Data:
  FirewallOff{}
  FirewallOn{allowSigned: Bool, allowSignedApp: Bool, blockAllIncoming: Bool, stealth: Bool}

def nix_bool(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

def firewall_nix(f: Firewall) -> String:
  match f:
    case FirewallOff{}:
      "  networking.applicationFirewall.enable = false;\n"
    case FirewallOn{a, b, c, d}:
      "  networking.applicationFirewall.enable = true;\n" ++
      "  networking.applicationFirewall.allowSigned = " ++ nix_bool(a) ++ ";\n" ++
      "  networking.applicationFirewall.allowSignedApp = " ++ nix_bool(b) ++ ";\n" ++
      "  networking.applicationFirewall.blockAllIncoming = " ++ nix_bool(c) ++ ";\n" ++
      "  networking.applicationFirewall.enableStealthMode = " ++ nix_bool(d) ++ ";\n"

def firewall_show(f: Firewall) -> String:
  match f:
    case FirewallOff{}:
      "off"
    case FirewallOn{a, b, c, d}:
      "on (allowSigned " ++ nix_bool(a) ++ ", allowSignedApp " ++ nix_bool(b) ++ ", blockAllIncoming " ++ nix_bool(c) ++ ", stealth " ++ nix_bool(d) ++ ")"

def firewall_change_if(same: Bool, now: String, want: String) -> String:
  match same:
    case True{}:
      ""
    case False{}:
      "change  networking.applicationFirewall: " ++ now ++ " -> " ++ want ++ "\n"

def firewall_change_str(+want: String, +now: String) -> String:
  firewall_change_if(str_eq(want, now), now, want)

# Dry run line for the firewall ("" when unchanged).
def firewall_change(want: Firewall, now: Firewall) -> String:
  firewall_change_str(firewall_show(want), firewall_show(now))

# True when no setting's option starts with `p` (areas V types, like the firewall, stay out of the flat list).
def none_prefixed(+p: String, xs: List<&2, Setting>) -> Bool:
  match xs:
    case []:
      True{}
    case s <> rest:
      Bool.not(String.starts_with(option_of(s), p)) && none_prefixed(p, rest)
