import Base
import bend-kit-files@0.1.0.0/files.bend as Fs
import ../../../effs/io.bend as X
import ../../../plan/type.bend as P
import ./type.bend as St
import ./ops.bend as StO

# The Mac's settings as they are, read with read-only programs (defaults export, pmset -g, scutil --get,
# socketfilterfw --get*, plutil -extract, networksetup -get*, hidutil --get, nvram, readlink, stat, dscl,
# shasum), and what applying the declared ones would change. Nothing is written.

# ---- system.defaults: each domain's plist exported once, its options read from the XML ----
def read_domains(ds: List<&2, String>, +xs: List<&2, St.Setting>) -> IO(List<&2, St.Setting>):
  match ds:
    case []:
      IO.pure(List<&2, St.Setting>, [])
    case +d <> rest:
      do IO<List<&2, St.Setting>>:
        xml : String <- X.run("defaults", StO.export_args(d))
        more : List<&2, St.Setting> <- read_domains(rest, xs)
        return List.append(&2, St.Setting, StO.read_domain(xs, d, StO.text_lines(xml)), more)

# The observed values of the options (their values are ignored) that live in a defaults domain.
def defaults_now(+xs: List<&2, St.Setting>) -> IO(List<&2, St.Setting>):
  read_domains(StO.domains(xs), xs)

# ---- power and names ----
def power() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    pm : String <- X.run("pmset", ["-g", "custom"])
    return StO.power_settings(pm)

# power.restartAfterFreeze is left out: only `systemsetup` reports it, and only to an administrator.
def power_button() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    pm : String <- X.run("pmset", ["-g"])
    return StO.button_setting(pm)

def name(+option: String, +key: String) -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    +v : String <- X.run("scutil", ["--get", key])
    return StO.when_filled(v, StO.str_setting(option, String.trim(v)))

def names() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    a : List<&2, St.Setting> <- name("networking.computerName", "ComputerName")
    b : List<&2, St.Setting> <- name("networking.localHostName", "LocalHostName")
    c : List<&2, St.Setting> <- name("networking.hostName", "HostName")
    return List.concat(&2, St.Setting, [a, b, c])

# ---- the firewall ----
def socketfilterfw(+flag: String) -> IO(String):
  X.run("/usr/libexec/ApplicationFirewall/socketfilterfw", [flag])

def firewall_now() -> IO(St.Firewall):
  do IO<St.Firewall>:
    a : String <- socketfilterfw("--getglobalstate")
    b : String <- socketfilterfw("--getallowsigned")
    c : String <- socketfilterfw("--getblockall")
    d : String <- socketfilterfw("--getstealthmode")
    return StO.firewall_of(a ++ b ++ c ++ d)

# ---- Dock tiles ----
def field(+plist: String, +tile: String, +f: String) -> IO(String):
  do IO<String>:
    out : String <- X.run("plutil", ["-extract", tile ++ "." ++ f, "raw", plist])
    return String.trim(out)

def tiles(n: Nat, +plist: String, +key: String, +i: Nat) -> IO(List<&2, String>):
  match n:
    case 0n:
      IO.pure(List<&2, String>, [])
    case 1n+m:
      do IO<List<&2, String>>:
        +tile : String = key ++ "." ++ Nat.show(i)
        t : String <- field(plist, tile, "tile-type")
        u : String <- field(plist, tile, "tile-data.file-data._CFURLString")
        a : String <- field(plist, tile, "tile-data.arrangement")
        d : String <- field(plist, tile, "tile-data.displayas")
        s : String <- field(plist, tile, "tile-data.showas")
        rest : List<&2, String> <- tiles(m, plist, key, 1n+i)
        return StO.tile_nix(key, t, u, a, d, s) <> rest

# `plutil -extract <array> raw` answers the array's length.
def dock_list(+plist: String, +key: String) -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    +n : String <- X.run("plutil", ["-extract", key, "raw", plist])
    ts : List<&2, String> <- tiles(StO.nat_of(n), plist, key, 0n)
    return StO.dock_setting(key, n, ts)

# ---- network ----
def per_service(ss: List<&2, String>, +get: String) -> IO(List<&2, String>):
  match ss:
    case []:
      IO.pure(List<&2, String>, [])
    case s <> rest:
      do IO<List<&2, String>>:
        out : String <- X.run("networksetup", [get, s])
        more : List<&2, String> <- per_service(rest, get)
        return StO.per_service(out) <> more

def network() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    out : String <- X.run("networksetup", ["-listallnetworkservices"])
    +ss : List<&2, String> = StO.services(out)
    dns : List<&2, String> <- per_service(ss, "-getdnsservers")
    search : List<&2, String> <- per_service(ss, "-getsearchdomains")
    return [StO.nix_setting("networking.knownNetworkServices", StO.nix_list(ss)),
            StO.nix_setting("networking.dns", StO.same_for_all("DNS servers", dns)),
            StO.nix_setting("networking.search", StO.same_for_all("search domains", search))]

# ---- security ----
# Whether nix-darwin manages a file: it links it to /etc/static.
def nix_link(+path: String) -> IO(Bool):
  do IO<Bool>:
    t : String <- X.run("readlink", [path])
    return StO.is_nix_link(t)

def security() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    +pam : String <- X.read("/etc/pam.d/sudo_local")
    pam_nix : Bool <- nix_link("/etc/pam.d/sudo_local")
    +sudo : String <- X.read("/etc/sudoers.d/10-nix-darwin-extra-config")
    pki : Bool <- nix_link("/etc/ssl/certs/ca-certificates.crt")
    return [StO.bool_setting("security.pam.services.sudo_local.enable", pam_nix),
            StO.bool_setting("security.pam.services.sudo_local.touchIdAuth", String.contains(pam, "pam_tid.so")),
            StO.bool_setting("security.pam.services.sudo_local.watchIdAuth", String.contains(pam, "pam_watchid")),
            StO.bool_setting("security.pam.services.sudo_local.reattach", String.contains(pam, "pam_reattach")),
            StO.bool_setting("security.sudo.keepTerminfo", String.contains(sudo, "TERMINFO_DIRS")),
            StO.str_setting("security.sudo.extraConfig", StO.sudo_extra(sudo)),
            StO.bool_setting("security.pki.installCACerts", pki)]

def keyboard() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    km : String <- X.run("hidutil", ["property", "--get", "UserKeyMapping"])
    return StO.keyboard_settings(km)

# ---- startup chime, time zone, primary user, Nix, shells, fonts, SSH ----
def names_of(r: Result<&1, &1, U32 & String, List<&2, String>>) -> List<&2, String>:
  match r:
    case Done{ns}:
      ns
    case Fail{_}:
      []

def system() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    +mute : String <- X.run("nvram", ["StartupMute"])
    tz : String <- X.run("readlink", ["/etc/localtime"])
    user : String <- X.run("stat", ["-f", "%Su", "/dev/console"])
    nix : Bool <- nix_link("/etc/nix/nix.conf")
    shells : String <- X.read("/etc/shells")
    fonts : Result<&1, &1, U32 & String, List<&2, String>> <- Fs.list_dir("/Library/Fonts/Nix Fonts")
    zsh : Bool <- nix_link("/etc/zshrc")
    bash : Bool <- nix_link("/etc/bashrc")
    fish : Bool <- nix_link("/etc/fish/config.fish")
    ssh : Bool <- X.succeeds("launchctl", ["print", "system/com.openssh.sshd"])
    return List.append(&2, St.Setting, StO.chime_setting(mute),
           [StO.str_setting("time.timeZone", StO.time_zone(tz)),
            StO.str_setting("system.primaryUser", String.trim(user)),
            StO.bool_setting("nix.enable", nix),
            StO.nix_setting("environment.shells", StO.nix_list(StO.extra_shells(shells))),
            StO.fonts_setting(names_of(fonts)),
            StO.bool_setting("programs.zsh.enable", zsh),
            StO.bool_setting("programs.bash.enable", bash),
            StO.bool_setting("programs.fish.enable", fish),
            StO.bool_setting("services.openssh.enable", ssh)])

# ---- users and groups ----
def dscl(+record: String, +attr: String) -> IO(String):
  do IO<String>:
    out : String <- X.run("dscl", [".", "-read", record, attr])
    return StO.dscl_value(attr, out)

def user_list(ns: List<&2, String>) -> IO(List<&2, St.Setting>):
  match ns:
    case []:
      IO.pure(List<&2, St.Setting>, [])
    case +n <> rest:
      do IO<List<&2, St.Setting>>:
        uid : String <- dscl("/Users/" ++ n, "UniqueID")
        gid : String <- dscl("/Users/" ++ n, "PrimaryGroupID")
        dir : String <- dscl("/Users/" ++ n, "NFSHomeDirectory")
        real : String <- dscl("/Users/" ++ n, "RealName")
        shell : String <- dscl("/Users/" ++ n, "UserShell")
        hidden : String <- dscl("/Users/" ++ n, "IsHidden")
        more : List<&2, St.Setting> <- user_list(rest)
        return List.append(&2, St.Setting, StO.user_settings(n, uid, gid, dir, real, shell, hidden), more)

def group_list(ns: List<&2, String>) -> IO(List<&2, St.Setting>):
  match ns:
    case []:
      IO.pure(List<&2, St.Setting>, [])
    case +n <> rest:
      do IO<List<&2, St.Setting>>:
        gid : String <- dscl("/Groups/" ++ n, "PrimaryGroupID")
        real : String <- dscl("/Groups/" ++ n, "RealName")
        members : String <- dscl("/Groups/" ++ n, "GroupMembership")
        more : List<&2, St.Setting> <- group_list(rest)
        return List.append(&2, St.Setting, StO.group_settings(n, gid, real, members), more)

def users() -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    us : String <- X.run("dscl", [".", "-list", "/Users", "UniqueID"])
    gs : String <- X.run("dscl", [".", "-list", "/Groups", "PrimaryGroupID"])
    a : List<&2, St.Setting> <- user_list(StO.accounts(us))
    b : List<&2, St.Setting> <- group_list(StO.accounts(gs))
    return List.concat(&2, St.Setting, [[StO.nix_setting("users.knownUsers", "[ ]"), StO.nix_setting("users.knownGroups", "[ ]")], a, b])

# ---- launchd files, read only: each is named by its content hash, but not copied into the system's
# nix/launch/ (the old import did), so a declaration that uses one must copy it there itself ----
def regular(k: Fs.FileType) -> Bool:
  match k:
    case Fs.Regular{}:
      True{}
    case _:
      False{}

def is_file(r: Result<&1, &1, U32 & String, Fs.Info>) -> Bool:
  match r:
    case Done{i}:
      match i:
        case Fs.Info{k, _, _}:
          regular(k)
    case Fail{_}:
      False{}

def launch_files(fs: List<&2, String>, +opt: String, +dir: String, +labels: List<&2, String>) -> IO(List<&2, St.Setting>):
  match fs:
    case []:
      IO.pure(List<&2, St.Setting>, [])
    case +f <> rest:
      do IO<List<&2, St.Setting>>:
        info : Result<&1, &1, U32 & String, Fs.Info> <- Fs.stat(dir ++ "/" ++ f)
        +keep : Bool = is_file(info) && StO.launch_kept(f, labels)
        sum : String <- Bool.pick(IO(String), keep, X.run("shasum", ["-a", "256", dir ++ "/" ++ f]), IO.pure(String, ""))
        more : List<&2, St.Setting> <- launch_files(rest, opt, dir, labels)
        return List.append(&2, St.Setting, Bool.pick(List<&2, St.Setting>, keep, [StO.launch_setting(opt, f, sum)], []), more)

def launch_dir(+opt: String, +dir: String, +labels: List<&2, String>) -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    r : Result<&1, &1, U32 & String, List<&2, String>> <- Fs.list_dir(dir)
    launch_files(names_of(r), opt, dir, labels)

# `labels`: the system's own launchd jobs (nix-darwin writes them; they are not the Mac's settings).
def launch(+labels: List<&2, String>) -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    h : String <- X.home()
    a : List<&2, St.Setting> <- launch_dir("environment.launchDaemons", "/Library/LaunchDaemons", labels)
    b : List<&2, St.Setting> <- launch_dir("environment.launchAgents", "/Library/LaunchAgents", labels)
    c : List<&2, St.Setting> <- launch_dir("environment.userLaunchAgents", h ++ "/Library/LaunchAgents", labels)
    return List.concat(&2, St.Setting, [a, b, c])

# ---- all of it ----
# The Mac's values for the options `xs` (their values are ignored) and everything nix-darwin sets outside
# system.defaults.
def observed_from(+xs: List<&2, St.Setting>, +labels: List<&2, String>) -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    prefs : List<&2, St.Setting> <- defaults_now(xs)
    pw : List<&2, St.Setting> <- power()
    nm : List<&2, St.Setting> <- names()
    +h : String <- X.home()
    apps : List<&2, St.Setting> <- dock_list(h ++ "/Library/Preferences/com.apple.dock.plist", "persistent-apps")
    others : List<&2, St.Setting> <- dock_list(h ++ "/Library/Preferences/com.apple.dock.plist", "persistent-others")
    net : List<&2, St.Setting> <- network()
    btn : List<&2, St.Setting> <- power_button()
    sec : List<&2, St.Setting> <- security()
    kb : List<&2, St.Setting> <- keyboard()
    sys : List<&2, St.Setting> <- system()
    us : List<&2, St.Setting> <- users()
    ld : List<&2, St.Setting> <- launch(labels)
    return List.concat(&2, St.Setting, [prefs, pw, nm, apps, others, net, btn, sec, kb, sys, us, ld])

# The Mac's settings: every nix-darwin option in `options_tsv` (nix-darwin's option list, "option<TAB>type")
# that it has a value for, and the rest, less the system's own launchd jobs `labels`.
def observed(+options_tsv: String, +labels: List<&2, String>) -> IO(List<&2, St.Setting>):
  do IO<List<&2, St.Setting>>:
    tsv : String <- X.read(options_tsv)
    observed_from(StO.options(tsv), labels)

# What applying the declared settings and firewall would change: each declared setting whose observed
# value differs ("(unset)" when the Mac has none), and the firewall.
def changes(+settings: List<&2, St.Setting>, fw: St.Firewall) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    now : List<&2, St.Setting> <- observed_from(settings, [])
    f : St.Firewall <- firewall_now()
    return List.append(&2, P.Step, StO.firewall_change(fw, f), StO.diff(settings, now))
