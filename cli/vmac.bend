import Base
import ../lib/effs/io.bend as X
import ../lib/vstr.bend as S
import bend-net-url@0.4.0.0/url.bend as Url

# The Mac's nix-darwin-labeled state outside `system.defaults` scalars, read for `v import`.
# Each reader answers setting lines for mac.now.bend; values are Nix expressions (T.KNix) unless scalar.

def nix_line(name: String, v: String) -> String:
  S.setting_line(name, "KNix", v)

def bool_line(name: String, b: Bool) -> String:
  S.setting_line(name, "KBool", S.pick(b, "true", "false"))

def str_line(name: String, v: String) -> String:
  S.setting_line(name, "KStr", S.nix_esc_chars(String.to_list(v)))

def int_line(name: String, v: String) -> String:
  S.setting_line(name, "KInt", v)

def nonempty_line(+v: String, l: String) -> List<&2, String>:
  S.line_if(Bool.not(String.is_empty(v)), l)

def lines_of(+s: String) -> List<&2, String>:
  S.nonempty(String.lines(String.trim(s)))

# ---- numbers ----
def digit_nat(c: Char) -> Nat:
  U32.to_nat(U32.sub(Char.to_u32(c), 48))

def nat_go(cs: List<&2, Char>, acc: Nat) -> Nat:
  match cs:
    case []:
      acc
    case c <> rest:
      nat_go(rest, Nat.add(Nat.mul(acc, 10n), digit_nat(c)))

def nat_of(s: String) -> Nat:
  nat_go(String.to_list(S.digits(s)), 0n)

# ---- URLs as paths: "file:///Applications/Google%20Chrome.app/" -> "/Applications/Google Chrome.app" ----
# Percent-decoding is bend-net-url's (UTF-8 aware); a malformed URL is kept as it is.
def decoded_or(m: Maybe<&2, String>, raw: String) -> String:
  match m:
    case None{}:
      raw
    case Some{v}:
      v

def pct_decode(+s: String) -> String:
  decoded_or(Url.pct.decode(s), s)

def drop_prefix(+s: String, +p: String) -> String:
  S.pick(String.starts_with(s, p), String.drop(s, String.length(p)), s)

def drop_slash(+s: String) -> String:
  S.pick(String.ends_with(s, "/") && Nat.is_gt(String.length(s), 1n), String.take(s, Nat.sub(String.length(s), 1n)), s)

def url_path(+u: String) -> String:
  pct_decode(drop_slash(drop_prefix(u, "file://")))

# ---- Dock tiles: system.defaults.dock.persistent-apps / persistent-others ----
def dock() -> String:
  "\"$HOME/Library/Preferences/com.apple.dock.plist\""

def tile_cmd(+key: String, +i: Nat) -> String:
  "P=" ++ dock() ++ "; K=" ++ key ++ "." ++ Nat.show(i) ++
  "; t=$(plutil -extract $K.tile-type raw $P 2>/dev/null) || exit 1" ++
  "; printf '%s|%s|%s|%s|%s' \"$t\" \"$(plutil -extract $K.tile-data.file-data._CFURLString raw $P 2>/dev/null)\"" ++
  " \"$(plutil -extract $K.tile-data.arrangement raw $P 2>/dev/null)\" \"$(plutil -extract $K.tile-data.displayas raw $P 2>/dev/null)\" \"$(plutil -extract $K.tile-data.showas raw $P 2>/dev/null)\""

def arrangement(+n: String) -> String:
  S.pick(String.eq(n, "2"), "date-added", S.pick(String.eq(n, "3"), "date-modified", S.pick(String.eq(n, "4"), "date-created", S.pick(String.eq(n, "5"), "kind", "name"))))

def displayas(+n: String) -> String:
  S.pick(String.eq(n, "1"), "folder", "stack")

def showas(+n: String) -> String:
  S.pick(String.eq(n, "1"), "fan", S.pick(String.eq(n, "2"), "grid", S.pick(String.eq(n, "3"), "list", "automatic")))

def app_tile(+t: String, +p: String) -> String:
  S.pick(String.eq(t, "spacer-tile"), "{ spacer = { small = false; }; }",
  S.pick(String.eq(t, "small-spacer-tile"), "{ spacer = { small = true; }; }",
  S.pick(String.eq(t, "directory-tile"), "{ folder = " ++ S.nix_str(p) ++ "; }",
  S.pick(String.ends_with(p, ".app"), "{ app = " ++ S.nix_str(p) ++ "; }", "{ file = " ++ S.nix_str(p) ++ "; }"))))

def other_tile(+t: String, +p: String, +f: List<&2, String>) -> String:
  S.pick(String.eq(t, "directory-tile"),
    "{ folder = { path = " ++ S.nix_str(p) ++ "; arrangement = \"" ++ arrangement(S.nth(f, 2n)) ++ "\"; displayas = \"" ++ displayas(S.nth(f, 3n)) ++ "\"; showas = \"" ++ showas(S.nth(f, 4n)) ++ "\"; }; }",
    "{ file = " ++ S.nix_str(p) ++ "; }")

def tile_nix(+key: String, +f: List<&2, String>) -> String:
  S.pick(String.eq(key, "persistent-apps"), app_tile(S.nth(f, 0n), url_path(S.nth(f, 1n))), other_tile(S.nth(f, 0n), url_path(S.nth(f, 1n)), f))

def tiles(n: Nat, +key: String, +i: Nat) -> IO(List<&2, String>):
  match n:
    case 0n:
      IO.pure(List<&2, String>, [])
    case 1n+m:
      do IO<List<&2, String>>:
        t : String <- X.sh(tile_cmd(key, i))
        rest : List<&2, String> <- tiles(m, key, 1n+i)
        return (" " ++ tile_nix(key, String.split(t, '|'))) <> rest

def dock_list(+key: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +n : String <- X.sh("plutil -extract " ++ key ++ " raw " ++ dock() ++ " 2>/dev/null")
    ts : List<&2, String> <- tiles(nat_of(n), key, 0n)
    return S.line_if(Bool.not(String.is_empty(String.trim(n))), nix_line("system.defaults.dock." ++ key, "[" ++ String.concat(ts) ++ " ]"))

# ---- firewall, network, power ----
# ---- the firewall, as a T.Firewall expression (its options exist only while it is on) ----
def bend_bool(b: Bool) -> String:
  S.pick(b, "True{}", "False{}")

def firewall_expr(on: Bool, +f: String) -> String:
  match on:
    case True{}:
      "T.FirewallOn{" ++ bend_bool(String.contains(f, "built-in signed software ENABLED")) ++ ", " ++
      bend_bool(String.contains(f, "downloaded signed software ENABLED")) ++ ", " ++
      bend_bool(String.contains(f, "block all state set to enabled")) ++ ", " ++
      bend_bool(String.contains(f, "stealth mode is on")) ++ "}"
    case False{}:
      "T.FirewallOff{}"

def firewall() -> IO(String):
  do IO<String>:
    +f : String <- X.sh("F=/usr/libexec/ApplicationFirewall/socketfilterfw; $F --getglobalstate; $F --getallowsigned; $F --getblockall; $F --getstealthmode")
    return firewall_expr(String.contains(f, "Firewall is enabled"), f)

# nix-darwin gives every known service the same DNS servers and search domains; a Mac where they differ cannot be declared.
def same_for_all(+what: String, +outs: List<&2, String>) -> String:
  S.pick(Nat.is_gt(S.count(outs), 1n), "throw \"V: " ++ what ++ " differ per network service\"", S.nix_list(S.words(S.nth(outs, 0n))))

def per_service(+get: String) -> String:
  "networksetup -listallnetworkservices | tail -n +2 | grep -v '^\\*' | while read -r s; do networksetup " ++ get ++ " \"$s\" | grep -v \"aren't any\" | tr '\\n' ' '; echo; done | sort -u"

def network() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    svcs : String <- X.sh("networksetup -listallnetworkservices | tail -n +2 | grep -v '^\\*'")
    dns : String <- X.sh(per_service("-getdnsservers"))
    search : String <- X.sh(per_service("-getsearchdomains"))
    return [nix_line("networking.knownNetworkServices", S.nix_list(lines_of(svcs))),
            nix_line("networking.dns", same_for_all("DNS servers", String.lines(String.trim(dns)))),
            nix_line("networking.search", same_for_all("search domains", String.lines(String.trim(search))))]

def power() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +b : String <- X.sh("pmset -g | grep 'Sleep On Power Button' | awk '{print $NF}'")
    # power.restartAfterFreeze is left out: only `systemsetup` reports it, and only to an administrator.
    return nonempty_line(String.trim(b), bool_line("power.sleep.allowSleepByPowerButton", String.eq(String.trim(b), "1")))

# ---- security ----
def is_nix_link(path: String) -> IO(Bool):
  X.ok("readlink " ++ path ++ " | grep -q '^/etc/static/'")

def sudo_extra(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      S.append(S.line_if(Bool.not(String.is_empty(String.trim(l)) || String.starts_with(l, "#") || String.contains(l, "env_keep+=TERMINFO")), l), sudo_extra(rest))

def security() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +pam : String <- X.sh("cat /etc/pam.d/sudo_local 2>/dev/null")
    pam_nix : Bool <- is_nix_link("/etc/pam.d/sudo_local")
    +sudo : String <- X.sh("cat /etc/sudoers.d/10-nix-darwin-extra-config 2>/dev/null")
    pki : Bool <- is_nix_link("/etc/ssl/certs/ca-certificates.crt")
    return [bool_line("security.pam.services.sudo_local.enable", pam_nix),
            bool_line("security.pam.services.sudo_local.touchIdAuth", String.contains(pam, "pam_tid.so")),
            bool_line("security.pam.services.sudo_local.watchIdAuth", String.contains(pam, "pam_watchid")),
            bool_line("security.pam.services.sudo_local.reattach", String.contains(pam, "pam_reattach")),
            bool_line("security.sudo.keepTerminfo", String.contains(sudo, "TERMINFO_DIRS")),
            str_line("security.sudo.extraConfig", String.join(sudo_extra(String.lines(sudo)), "\n")),
            bool_line("security.pki.installCACerts", pki)]

# ---- keyboard: hidutil's UserKeyMapping ----
def after_word(+w: String, ws: List<&2, String>) -> List<&2, String>:
  match ws:
    case []:
      []
    case +x <> +rest:
      S.append(S.line_if(String.eq(x, w), S.digits(S.nth(rest, 1n))), after_word(w, rest))

def pairs(src: List<&2, String>, dst: List<&2, String>) -> String:
  match src:
    case []:
      ""
    case s <> srest:
      match dst:
        case []:
          ""
        case d <> drest:
          " { HIDKeyboardModifierMappingSrc = " ++ s ++ "; HIDKeyboardModifierMappingDst = " ++ d ++ "; }" ++ pairs(srest, drest)

def keyboard() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +km : String <- X.sh("hidutil property --get UserKeyMapping")
    +none : Bool = String.eq(String.trim(km), "(null)") || String.eq(String.trim(km), "(\n)")
    return [bool_line("system.keyboard.enableKeyMapping", Bool.not(none)),
            nix_line("system.keyboard.userKeyMapping", "[" ++ pairs(after_word("HIDKeyboardModifierMappingSrc", S.words(String.join(String.lines(km), " "))), after_word("HIDKeyboardModifierMappingDst", S.words(String.join(String.lines(km), " ")))) ++ " ]"),
            bool_line("system.keyboard.remapCapsLockToControl", False{}),
            bool_line("system.keyboard.remapCapsLockToEscape", False{}),
            bool_line("system.keyboard.swapCapsLockAndEscape", False{}),
            bool_line("system.keyboard.swapLeftCommandAndLeftAlt", False{}),
            bool_line("system.keyboard.swapLeftCtrlAndFn", False{}),
            bool_line("system.keyboard.swapRightCommandAndRightOption", False{}),
            bool_line("system.keyboard.nonUS.remapTilde", False{})]

# ---- startup chime, time zone, primary user, Nix, shells, fonts, SSH ----
def system() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +mute : String <- X.sh("nvram StartupMute 2>/dev/null | awk '{print $2}'")
    +tz : String <- X.sh("readlink /etc/localtime | sed 's|.*/zoneinfo/||'")
    user : String <- X.sh("stat -f %Su /dev/console")
    nix : Bool <- is_nix_link("/etc/nix/nix.conf")
    shells : String <- X.sh("grep -v '^#' /etc/shells | grep -v -x -e /bin/bash -e /bin/csh -e /bin/dash -e /bin/ksh -e /bin/sh -e /bin/tcsh -e /bin/zsh")
    +fonts : String <- X.sh("ls '/Library/Fonts/Nix Fonts' 2>/dev/null")
    zsh : Bool <- is_nix_link("/etc/zshrc")
    bash : Bool <- is_nix_link("/etc/bashrc")
    fish : Bool <- is_nix_link("/etc/fish/config.fish")
    ssh : Bool <- X.ok("launchctl print system/com.openssh.sshd >/dev/null 2>&1")
    return S.append(nonempty_line(String.trim(mute), bool_line("system.startup.chime", Bool.not(String.eq(String.trim(mute), "%01")))),
           [str_line("time.timeZone", String.trim(tz)),
            str_line("system.primaryUser", String.trim(user)),
            bool_line("nix.enable", nix),
            nix_line("environment.shells", S.nix_list(lines_of(shells))),
            nix_line("fonts.packages", S.pick(String.is_empty(String.trim(fonts)), "[ ]", "throw \"V: /Library/Fonts/Nix Fonts has fonts from no declared package\"")),
            bool_line("programs.zsh.enable", zsh),
            bool_line("programs.bash.enable", bash),
            bool_line("programs.fish.enable", fish),
            bool_line("services.openssh.enable", ssh)])

# ---- users and groups (uid/gid >= 500, not system accounts) ----
def dscl_get(+kind: String, +name: String, +attr: String) -> IO(String):
  do IO<String>:
    +v : String <- X.sh("dscl . -read '/" ++ kind ++ "/" ++ name ++ "' " ++ attr ++ " 2>/dev/null | sed -e '1s/^" ++ attr ++ "://' | tr '\\n' ' '")
    return String.trim(v)

def user_lines(names: List<&2, String>) -> IO(List<&2, String>):
  match names:
    case []:
      IO.pure(List<&2, String>, [])
    case +n <> rest:
      do IO<List<&2, String>>:
        uid : String <- dscl_get("Users", n, "UniqueID")
        gid : String <- dscl_get("Users", n, "PrimaryGroupID")
        dir : String <- dscl_get("Users", n, "NFSHomeDirectory")
        real : String <- dscl_get("Users", n, "RealName")
        shell : String <- dscl_get("Users", n, "UserShell")
        +hidden : String <- dscl_get("Users", n, "IsHidden")
        more : List<&2, String> <- user_lines(rest)
        +u : String = "users.users.\"" ++ n ++ "\"."
        return S.append([int_line(u ++ "uid", uid), int_line(u ++ "gid", gid), str_line(u ++ "home", dir), str_line(u ++ "description", real),
                         nix_line(u ++ "shell", shell), bool_line(u ++ "isHidden", String.eq(hidden, "1"))], more)

def group_lines(names: List<&2, String>) -> IO(List<&2, String>):
  match names:
    case []:
      IO.pure(List<&2, String>, [])
    case +n <> rest:
      do IO<List<&2, String>>:
        gid : String <- dscl_get("Groups", n, "PrimaryGroupID")
        real : String <- dscl_get("Groups", n, "RealName")
        members : String <- dscl_get("Groups", n, "GroupMembership")
        more : List<&2, String> <- group_lines(rest)
        +g : String = "users.groups.\"" ++ n ++ "\"."
        return S.append([int_line(g ++ "gid", gid), str_line(g ++ "description", real), nix_line(g ++ "members", S.nix_list(S.words(members)))], more)

def users() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    us : String <- X.sh("dscl . -list /Users UniqueID | awk '$2>=500 && $1 !~ /^_/ {print $1}'")
    gs : String <- X.sh("dscl . -list /Groups PrimaryGroupID | awk '$2>=500 && $1 !~ /^_/ {print $1}'")
    a : List<&2, String> <- user_lines(lines_of(us))
    b : List<&2, String> <- group_lines(lines_of(gs))
    return S.append([nix_line("users.knownUsers", "[ ]"), nix_line("users.knownGroups", "[ ]")], S.append(a, b))

# ---- launchd files other than nix-darwin's own (org.nixos.*), the project's services and Determinate Nix's (nix.enable = false) ----
# Each is kept in nix/launch/ under its content hash, so a changed file on the Mac shows up as a change.
def launch_file(+opt: String, +dir: String, +f: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +h : String <- X.sh("shasum -a 256 \"" ++ dir ++ "/" ++ f ++ "\" | cut -c1-12")
    cp : Bool <- X.ok("mkdir -p nix/launch && cp \"" ++ dir ++ "/" ++ f ++ "\" nix/launch/" ++ String.trim(h) ++ "-" ++ f)
    return [nix_line(opt ++ ".\"" ++ f ++ "\".source", "./launch/" ++ String.trim(h) ++ "-" ++ f)]

def launch_files(+opt: String, +dir: String, fs: List<&2, String>) -> IO(List<&2, String>):
  match fs:
    case []:
      IO.pure(List<&2, String>, [])
    case +f <> rest:
      do IO<List<&2, String>>:
        a : List<&2, String> <- launch_file(opt, dir, f)
        b : List<&2, String> <- launch_files(opt, dir, rest)
        return S.append(a, b)

def plists(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> rest:
      " " ++ x ++ ".plist" ++ plists(rest)

def launch_dir(+opt: String, +dir: String, +labels: List<&2, String>) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    fs : String <- X.sh("cd \"" ++ dir ++ "\" && for f in *; do [ -f \"$f\" ] || continue; case \" " ++ plists(labels) ++ " \" in *\" $f \"*) continue;; esac; case \"$f\" in org.nixos.*|systems.determinate.*) ;; *) echo \"$f\";; esac; done")
    launch_files(opt, dir, lines_of(fs))

def launch(+labels: List<&2, String>) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    a : List<&2, String> <- launch_dir("environment.launchDaemons", "/Library/LaunchDaemons", labels)
    b : List<&2, String> <- launch_dir("environment.launchAgents", "/Library/LaunchAgents", labels)
    c : List<&2, String> <- launch_dir("environment.userLaunchAgents", "$HOME/Library/LaunchAgents", labels)
    return S.append(a, S.append(b, c))

# ---- all of it ----
# `labels`: the project's own launchd jobs (nix-darwin writes them; they are not imported).
def read_all(+labels: List<&2, String>) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    apps : List<&2, String> <- dock_list("persistent-apps")
    others : List<&2, String> <- dock_list("persistent-others")
    net : List<&2, String> <- network()
    pw : List<&2, String> <- power()
    sec : List<&2, String> <- security()
    kb : List<&2, String> <- keyboard()
    sys : List<&2, String> <- system()
    us : List<&2, String> <- users()
    ld : List<&2, String> <- launch(labels)
    return S.append(apps, S.append(others, S.append(net, S.append(pw, S.append(sec, S.append(kb, S.append(sys, S.append(us, ld))))))))
