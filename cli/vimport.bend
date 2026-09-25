import Base
import ../lib/effs/io.bend as X
import ../lib/vstr.bend as S
import ../lib/mac.types.bend as T
import ./project.bend as P
import ./vmac.bend as V

# `v import`: read the Mac into mac.now.bend (and, the first time, mac.bend) in the project.


# ---- escaping (in vstr.bend) ----
def esc(s: String) -> String:
  S.esc(s)

def drop_if(yes: Bool, s: String) -> String:
  match yes:
    case True{}:
      String.drop(s, 1n)
    case False{}:
      s

def unquote_end(+s: String) -> String:
  String.reverse(drop_if(String.starts_with(String.reverse(s), "\""), String.reverse(s)))

def unquote(+s: String) -> String:
  unquote_end(drop_if(String.starts_with(s, "\""), s))


def pick(c: Bool, a: String, b: String) -> String:
  S.pick(c, a, b)

# ---- which options, and how to read them ----
def kind_of2(+t: String) -> String:
  pick(String.eq(t, "boolean"), "KBool",
  pick(String.starts_with(t, "floating point"), "KFloat",
  pick(String.starts_with(t, "signed integer") || String.starts_with(t, "(positive integer") || String.starts_with(t, "one of 0") || String.starts_with(t, "one of 1") || String.starts_with(t, "value 1"), "KInt",
  pick(String.eq(t, "string") || String.eq(t, "absolute path") || String.starts_with(t, "one of \"") || String.starts_with(t, "value \""), "KStr", ""))))

def kind_of(+t: String) -> String:
  pick(String.starts_with(t, "null or "), kind_of2(String.drop(t, 8n)), "")

def rest_of(name: String) -> String:
  String.drop(name, 16n)

def group_of(+name: String) -> String:
  pick(String.starts_with(rest_of(name), "\""), S.nth(String.split(rest_of(name), '"'), 1n), S.nth(String.split(rest_of(name), '.'), 0n))

def key_of(+name: String) -> String:
  unquote(pick(String.starts_with(rest_of(name), "\""),
    String.drop(String.join(List.drop(&2, String, String.split(rest_of(name), '"'), 2n), "\""), 1n),
    String.join(List.drop(&2, String, String.split(rest_of(name), '.'), 1n), ".")))

# `defaults` arguments that read a group's domain; "" for groups not imported.
def domain(+g: String) -> String:
  pick(String.eq(g, ".GlobalPreferences") || String.eq(g, "NSGlobalDomain"), "read -g",
  pick(String.eq(g, "LaunchServices"), "read com.apple.LaunchServices",
  pick(String.eq(g, "menuExtraClock"), "read com.apple.menuextra.clock",
  pick(String.eq(g, "dock"), "read com.apple.dock",
  pick(String.eq(g, "finder"), "read com.apple.finder",
  pick(String.eq(g, "hitoolbox"), "read com.apple.HIToolbox",
  pick(String.eq(g, "iCal"), "read com.apple.iCal",
  pick(String.eq(g, "magicmouse"), "read com.apple.AppleMultitouchMouse",
  pick(String.eq(g, "screencapture"), "read com.apple.screencapture",
  pick(String.eq(g, "screensaver"), "read com.apple.screensaver",
  pick(String.eq(g, "spaces"), "read com.apple.spaces",
  pick(String.eq(g, "trackpad"), "read com.apple.AppleMultitouchTrackpad",
  pick(String.eq(g, "universalaccess"), "read com.apple.universalaccess",
  pick(String.eq(g, "ActivityMonitor"), "read com.apple.ActivityMonitor",
  pick(String.eq(g, "WindowManager"), "read com.apple.WindowManager",
  pick(String.eq(g, "controlcenter"), "-currentHost read com.apple.controlcenter",
  pick(String.eq(g, "loginwindow"), "read /Library/Preferences/com.apple.loginwindow",
  pick(String.eq(g, "smb"), "read /Library/Preferences/SystemConfiguration/com.apple.smb.server",
  pick(String.eq(g, "SoftwareUpdate"), "read /Library/Preferences/com.apple.SoftwareUpdate", "")))))))))))))))))))

# "read X" -> "export X", "-currentHost read X" -> "-currentHost export X".
def export_of(+d: String) -> String:
  pick(String.starts_with(d, "read "), "export " ++ String.drop(d, 5n), "-currentHost export " ++ String.drop(d, 18n))

# ---- values ----
def nix_esc_chars(cs: List<&2, Char>) -> String:
  S.nix_esc_chars(cs)

def normalize1(+k: String, +v: String) -> String:
  pick(String.eq(k, "KBool"), pick(String.eq(v, "1"), "true", pick(String.eq(v, "0"), "false", "")),
  pick(String.eq(k, "KFloat"), pick(String.contains(v, "."), v, v ++ ".0"),
  pick(String.eq(k, "KStr"), nix_esc_chars(String.to_list(v)), v)))

def normalize(+k: String, +v: String) -> String:
  pick(String.is_empty(v), "", normalize1(k, v))

def one_if(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n


def nat_more(+raw: String) -> Nat:
  Nat.add(one_if(String.eq(raw, "1")), Nat.add(Nat.mul(2n, one_if(String.eq(raw, "2"))), Nat.add(Nat.mul(3n, one_if(String.eq(raw, "3"))), Nat.add(Nat.mul(4n, one_if(String.eq(raw, "4"))), Nat.add(Nat.mul(5n, one_if(String.eq(raw, "5"))), Nat.add(Nat.mul(6n, one_if(String.eq(raw, "6"))), Nat.add(Nat.mul(7n, one_if(String.eq(raw, "7"))), Nat.mul(99n, one_if(String.is_empty(raw))))))))))


def index_label(+raw: String, labels: List<&2, String>) -> String:
  S.nth(labels, nat_more(raw))


def finder_label(+c: String) -> String:
  pick(String.eq(c, "PfCm"), "Computer", pick(String.eq(c, "PfVo"), "OS volume", pick(String.eq(c, "PfHm"), "Home", pick(String.eq(c, "PfDe"), "Desktop",
  pick(String.eq(c, "PfDo"), "Documents", pick(String.eq(c, "PfAF"), "Recents", pick(String.eq(c, "PfID"), "iCloud Drive", pick(String.eq(c, "PfLo"), "Other", ""))))))))

# Options whose stored value is a code for a label (nix-darwin maps label -> code with `apply`).
def value_for(+g: String, +key: String, +k: String, +raw: String) -> String:
  pick(String.eq(g, "hitoolbox") && String.eq(key, "AppleFnUsageType"), index_label(raw, ["Do Nothing", "Change Input Source", "Show Emoji & Symbols", "Start Dictation"]),
  pick(String.eq(g, "iCal") && String.eq(key, "first day of week"), index_label(raw, ["System Setting", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]),
  pick(String.eq(g, "finder") && String.eq(key, "NewWindowTarget"), finder_label(raw),
  pick(String.eq(g, "controlcenter"), pick(String.eq(raw, "18"), "true", pick(String.eq(raw, "24"), "false", "")),
  normalize(k, raw)))))

def setting_line(name: String, k: String, v: String) -> String:
  S.setting_line(name, k, v)

def line_if(keep: Bool, l: String) -> List<&2, String>:
  S.line_if(keep, l)

# ---- reading the Mac ----
def read_value(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Done{v}:
      String.trim(v)
    case Fail{_}:
      ""

# One option line "name<TAB>type" -> its setting line, if the Mac has a value for it.
def option_read(+name: String, +k: String, +g: String) -> IO(List<&2, String>):
      do IO<List<&2, String>>:
        out : String <- X.sh(S.export_key(export_of(domain(g)), key_of(name)))
        +v : String = value_for(g, key_of(name), k, S.plist_scalar(out))
        return line_if(Bool.not(String.is_empty(v)), setting_line(name, k, v))

def option_skip(skip: Bool, +name: String, +k: String, +g: String) -> IO(List<&2, String>):
  match skip:
    case True{}:
      IO.pure(List<&2, String>, [])
    case False{}:
      option_read(name, k, g)

def option_setting(+name: String, +k: String, +g: String) -> IO(List<&2, String>):
  option_skip(String.is_empty(k) || String.is_empty(domain(g)), name, k, g)

def option_line(+l: String) -> IO(List<&2, String>):
  option_setting(S.nth(String.split(l, '\t'), 0n), kind_of(S.nth(String.split(l, '\t'), 1n)), group_of(S.nth(String.split(l, '\t'), 0n)))

def option_lines(ls: List<&2, String>) -> IO(List<&2, String>):
  match ls:
    case []:
      IO.pure(List<&2, String>, [])
    case l <> rest:
      do IO<List<&2, String>>:
        a : List<&2, String> <- option_line(l)
        b : List<&2, String> <- option_lines(rest)
        return S.append(a, b)

# ---- power, names, firewall ----
def pm_hit(+w: List<&2, String>, +key: String) -> String:
  pick(Nat.is_eq(S.count(w), 2n) && String.eq(S.nth(w, 0n), key), S.nth(w, 1n), "")

def first_of(+a: String, b: String) -> String:
  pick(String.is_empty(a), b, a)


def pm_get(ls: List<&2, String>, +key: String) -> String:
  match ls:
    case []:
      ""
    case l <> rest:
      first_of(pm_hit(S.words(l), key), pm_get(rest, key))

def minutes(+v: String) -> String:
  pick(String.eq(v, "0"), "\"never\"", v)

def bool_of(+v: String) -> String:
  pick(String.eq(v, "1"), "true", "false")

def power_lines(+pm: String) -> List<&2, String>:
  S.append(line_if(Bool.not(String.is_empty(pm_get(String.lines(pm), "sleep"))), setting_line("power.sleep.computer", "KInt", minutes(pm_get(String.lines(pm), "sleep")))),
  S.append(line_if(Bool.not(String.is_empty(pm_get(String.lines(pm), "displaysleep"))), setting_line("power.sleep.display", "KInt", minutes(pm_get(String.lines(pm), "displaysleep")))),
  S.append(line_if(Bool.not(String.is_empty(pm_get(String.lines(pm), "disksleep"))), setting_line("power.sleep.harddisk", "KInt", minutes(pm_get(String.lines(pm), "disksleep")))),
  S.append(line_if(Bool.not(String.is_empty(pm_get(String.lines(pm), "autorestart"))), setting_line("power.restartAfterPowerFailure", "KBool", bool_of(pm_get(String.lines(pm), "autorestart")))),
           line_if(Bool.not(String.is_empty(pm_get(String.lines(pm), "womp"))), setting_line("networking.wakeOnLan.enable", "KBool", bool_of(pm_get(String.lines(pm), "womp"))))))))

def name_line(opt: String, r: Result<&1, &1, U32 & String, String>) -> List<&2, String>:
  match r:
    case Done{v}:
      [setting_line(opt, "KStr", nix_esc_chars(String.to_list(String.trim(v))))]
    case Fail{_}:
      []

def names() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    a : Result<&1, &1, U32 & String, String> <- X.Proc.run("scutil --get ComputerName 2>/dev/null")
    b : Result<&1, &1, U32 & String, String> <- X.Proc.run("scutil --get LocalHostName 2>/dev/null")
    c : Result<&1, &1, U32 & String, String> <- X.Proc.run("scutil --get HostName 2>/dev/null")
    return S.append(name_line("networking.computerName", a), S.append(name_line("networking.localHostName", b), name_line("networking.hostName", c)))

# ---- Homebrew ----
def count_prefix(ls: List<&2, String>, +p: String) -> Nat:
  match ls:
    case []:
      0n
    case l <> rest:
      Nat.add(one_if(String.starts_with(l, p)), count_prefix(rest, p))

# `mas "Numbers", id: 409203825` -> `"Numbers" = 409203825`; a name the Brewfile repeats gets its id added.
def mas_attr(+n: String, +id: String, +all: List<&2, String>) -> String:
  S.nix_str(pick(Nat.is_gt(count_prefix(all, "mas \"" ++ n ++ "\","), 1n), n ++ " (" ++ id ++ ")", n)) ++ " = " ++ id

def brew_pick(+k: String, +n: String, +l: String, +all: List<&2, String>) -> List<&2, String>:
  line_if(Bool.not(String.is_empty(k)),
    pick(String.eq(k, "tap") || String.eq(k, "brew") || String.eq(k, "cask"),
      "    T.Brew{\"" ++ k ++ "\", \"" ++ esc(n) ++ "\"}",
    pick(String.eq(k, "mas"),
      "    T.Brew{\"mas\", \"" ++ esc(mas_attr(n, S.last(S.words(l)), all)) ++ "\"}",
      "    T.Brew{\"other\", \"" ++ esc(l) ++ "\"}")))

def brew_entry(+l: String, +all: List<&2, String>) -> List<&2, String>:
  brew_pick(pick(String.starts_with(String.trim(l), "#"), "", S.nth(S.words(l), 0n)), S.nth(String.split(l, '"'), 1n), l, all)

def brew_entries(ls: List<&2, String>, +all: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      S.append(brew_entry(l, all), brew_entries(rest, all))

# ---- the files ----
def mac_text(+vlib: String, title: String, settings: List<&2, String>, fw: String, brew: List<&2, String>) -> String:
  "import Base\nimport " ++ vlib ++ "/mac.types.bend as T\n\n# " ++ title ++ "\n\ndef settings() -> List<&2, T.Setting>:\n  [\n" ++
  String.join(settings, ",\n") ++ "\n  ]\n\n# The application firewall (T.Firewall: its options exist only while it is on).\ndef firewall() -> T.Firewall:\n  " ++ fw ++
  "\n\ndef brew() -> List<&2, T.Brew>:\n  [\n" ++ String.join(brew, ",\n") ++ "\n  ]\n"

# ---- keeping mac.bend: declared settings stay; options seen for the first time are added as observed ----
def before_go(cs: List<&2, Char>, +pat: String) -> String:
  match cs:
    case []:
      ""
    case +c <> +rest:
      pick(String.starts_with(String.from_list(c <> rest), pat), "", String.from_list([c]) ++ before_go(rest, pat))

# A setting line's option part, which names it.
def head_of(l: String) -> String:
  before_go(String.to_list(l), "\", T.K")

def heads(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      head_of(l) <> heads(rest)

def no_comma(+l: String) -> String:
  pick(String.ends_with(l, ","), String.take(l, Nat.sub(String.length(l), 1n)), l)

def entries(ls: List<&2, String>, +prefix: String) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      S.append(line_if(String.starts_with(l, prefix), no_comma(l)), entries(rest, prefix))

def unseen(obs: List<&2, String>, +known: List<&2, String>) -> List<&2, String>:
  match obs:
    case []:
      []
    case +l <> rest:
      S.append(line_if(Bool.not(T.has(head_of(l), known)), l), unseen(rest, known))

# The declared firewall: the line after its def ("" if mac.bend has none yet).
def after_line(ls: List<&2, String>, +marker: String, prev: Bool) -> String:
  match ls:
    case []:
      ""
    case +l <> rest:
      pick(prev, String.trim(l), after_line(rest, marker, String.eq(l, marker)))

def declared_title() -> String:
  "The Mac as it should be. Edit this; `v dryrun` shows what would change."

def write_declared(missing: Bool, +vlib: String, +settings: List<&2, String>, +fw: String, +brew: List<&2, String>) -> IO(Unit):
  match missing:
    case True{}:
      do IO<Unit>:
        X.write_file("mac.bend", mac_text(vlib, declared_title(), settings, fw, brew))
        IO.print("wrote mac.bend (declared) from the Mac")
    case False{}:
      do IO<Unit>:
        text : String <- X.sh("cat mac.bend")
        +ls : List<&2, String> = String.lines(text)
        +declared : List<&2, String> = entries(ls, "    T.Setting{")
        +added : List<&2, String> = unseen(settings, heads(declared))
        +dfw : String = after_line(ls, "def firewall() -> T.Firewall:", False{})
        X.write_file("mac.bend", mac_text(vlib, declared_title(), S.append(declared, added), pick(String.is_empty(dfw), fw, dfw), entries(ls, "    T.Brew{")))
        IO.print("mac.bend: " ++ Nat.show(S.count(added)) ++ " options declared for the first time (as observed)")

def import_mac() -> IO(Unit):
  do IO<Unit>:
    +f : P.Facts <- P.read_facts()
    P.when(Bool.not(P.has_target(f, "nix-darwin")), IO.die(Unit, 1, "import reads a Mac for a nix-darwin target; this project declares none"))
    opts : String <- X.sh("cat nix/options.tsv")
    prefs : List<&2, String> <- option_lines(String.lines(opts))
    pm : String <- X.sh("pmset -g custom")
    nm : List<&2, String> <- names()
    +fw : String <- V.firewall()
    rest : List<&2, String> <- V.read_all(P.labels_of(f))
    bf : String <- X.sh("brew bundle dump --force --file=/tmp/v-Brewfile >/dev/null 2>&1; cat /tmp/v-Brewfile")
    +settings : List<&2, String> = S.append(prefs, S.append(power_lines(pm), S.append(nm, rest)))
    +bls : List<&2, String> = String.lines(bf)
    +brew : List<&2, String> = brew_entries(bls, bls)
    X.write_file("mac.now.bend", mac_text(P.vlib_of(f), "The Mac as it is, read by `v import`. Generated; do not edit.", settings, fw, brew))
    exists : Bool <- X.ok("test -f mac.bend")
    write_declared(Bool.not(exists), P.vlib_of(f), settings, fw, brew)
    IO.print("import: " ++ Nat.show(S.count(settings)) ++ " settings, " ++ Nat.show(S.count(brew)) ++ " Homebrew entries")
