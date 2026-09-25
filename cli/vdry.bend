import Base
import ../lib/effs/io.bend as X
import ../lib/vstr.bend as S
import ./project.bend as P
import ./vimport.bend as I
import ./vmac.bend as V

# `v dryrun`: what applying the declared Mac (bend/mac.bend) would change, without changing anything.

def pick(c: Bool, a: String, b: String) -> String:
  I.pick(c, a, b)

# ---- preferences nix-darwin would write ----
# The write line's domain and key: "... write DOMAIN KEY '<?xml" or "... write DOMAIN 'KEY WITH SPACES' '<?xml".
def quoted_key(+parts: List<&2, String>) -> Bool:
  Bool.not(String.starts_with(S.nth(parts, 1n), "<?xml"))

def domain_of(+parts: List<&2, String>) -> String:
  pick(quoted_key(parts), S.last(S.words(S.nth(parts, 0n))), S.nth(S.words(S.nth(parts, 0n)), Nat.sub(S.count(S.words(S.nth(parts, 0n))), 2n)))

def key_of(+parts: List<&2, String>) -> String:
  pick(quoted_key(parts), S.nth(parts, 1n), S.last(S.words(S.nth(parts, 0n))))

def is_write(+l: String) -> Bool:
  String.contains(l, "defaults write ") || String.contains(l, "defaults -currentHost write ")

# "0.500000" -> "0.5", "0.000000" -> "0": numbers compare by value, not spelling.
def pick_chars(c: Bool, a: List<&2, Char>, b: List<&2, Char>) -> List<&2, Char>:
  match c:
    case True{}:
      a
    case False{}:
      b

def dz(cs: List<&2, Char>) -> List<&2, Char>:
  match cs:
    case []:
      []
    case +c <> +rest:
      pick_chars(Char.is_eq(c, '0'), dz(rest), c <> rest)

def drop_zeros(s: String) -> String:
  String.from_list(dz(String.to_list(s)))

def trim_dot(+s: String) -> String:
  I.pick(String.ends_with(s, "."), String.take(s, Nat.sub(String.length(s), 1n)), s)


def trim_num(+s: String) -> String:
  I.pick(String.contains(s, "."), trim_dot(String.reverse(drop_zeros(String.reverse(s)))), s)

def same(+now: String, +want: String) -> Bool:
  String.eq(now, want) || String.eq(trim_num(now), trim_num(want))

def unset_or(+v: String) -> String:
  I.pick(String.is_empty(v), "(unset)", v)

def report(ok: Bool, dom: String, key: String, now: String, want: String) -> IO(Nat):
  match ok:
    case True{}:
      IO.pure(Nat, 0n)
    case False{}:
      do IO<Nat>:
        IO.print("change   " ++ dom ++ " " ++ key ++ ": " ++ now ++ " -> " ++ want)
        return 1n


def compare(+host: String, +dom: String, +key: String, +want: String) -> IO(Nat):
  do IO<Nat>:
    out : String <- X.sh(S.export_key(host ++ "export " ++ dom, key))
    +now : String = unset_or(S.plist_scalar(out))
    report(same(now, want), dom, key, now, want)

def check_scalar(+l: String, rest: List<&2, String>) -> IO(Nat):
  compare(pick(String.contains(l, "-currentHost"), "-currentHost ", ""), domain_of(String.split(l, '\'')), key_of(String.split(l, '\'')), S.plist_scalar(String.trim(S.nth(rest, 2n))))

# Arrays nix-darwin writes are Dock tiles: compare the paths they point at, in order.
def stop_at(stop: Bool, xs: List<&2, String>) -> List<&2, String>:
  match stop:
    case True{}:
      []
    case False{}:
      xs

def xml_string(+l: String) -> String:
  S.nth(String.split(S.nth(String.split(l, '>'), 1n), '<'), 0n)

def written_paths(ls: List<&2, String>, prev: Bool) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      stop_at(String.contains(l, "</plist>"), S.append(S.line_if(prev, V.url_path(xml_string(l))), written_paths(rest, String.contains(l, "_CFURLString</key>"))))

def paths(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case l <> rest:
      V.url_path(String.trim(l)) <> paths(rest)

def check_array(+dom: String, +key: String, rest: List<&2, String>) -> IO(Nat):
  do IO<Nat>:
    now : String <- X.sh("defaults read " ++ dom ++ " '" ++ key ++ "' 2>/dev/null | grep '\"_CFURLString\" =' | sed -E 's/.*= \"?([^\";]*)\"?;.*/\\1/'")
    +a : String = String.join(paths(V.lines_of(now)), ", ")
    +b : String = String.join(written_paths(rest, False{}), ", ")
    report(String.eq(a, b), dom, key, "[" ++ a ++ "]", "[" ++ b ++ "]")

def check_kind(arr: Bool, +l: String, rest: List<&2, String>) -> IO(Nat):
  match arr:
    case True{}:
      check_array(domain_of(String.split(l, '\'')), key_of(String.split(l, '\'')), rest)
    case False{}:
      check_scalar(l, rest)

def check_write(+l: String, +rest: List<&2, String>) -> IO(Nat):
  check_kind(String.starts_with(String.trim(S.nth(rest, 2n)), "<array>"), l, rest)

def one_if(b: Bool) -> Nat:
  I.one_if(b)


def add_pair(n: Nat, d: Nat, r: Nat & Nat) -> Nat & Nat:
  match r:
    case (a, b):
      (Nat.add(n, a), Nat.add(d, b))


def write_if(yes: Bool, +l: String, +rest: List<&2, String>) -> IO(Nat):
  match yes:
    case True{}:
      check_write(l, rest)
    case False{}:
      IO.pure(Nat, 0n)

def writes(ls: List<&2, String>) -> IO(Nat & Nat):
  match ls:
    case []:
      IO.pure(Nat & Nat, (0n, 0n))
    case +l <> +rest:
      do IO<Nat & Nat>:
        d : Nat <- write_if(is_write(l), l, rest)
        r : Nat & Nat <- writes(rest)
        return add_pair(one_if(is_write(l)), d, r)


# ---- Homebrew, checked by Homebrew against nix-darwin's own Brewfile ----
def pick_idx(q: Bool) -> Nat:
  match q:
    case True{}:
      1n
    case False{}:
      0n


def brewfile_clean(+w: String) -> String:
  S.nth(String.split(S.last(String.split(w, '=')), '\''), pick_idx(String.starts_with(S.last(String.split(w, '=')), "'")))


def brewfile_in(ws: List<&2, String>) -> String:
  match ws:
    case []:
      ""
    case +w <> rest:
      I.first_of(pick(String.contains(w, "-Brewfile"), brewfile_clean(w), ""), brewfile_in(rest))

def interesting(+l: String) -> Bool:
  Bool.not(String.is_empty(l)) && Bool.not(String.starts_with(l, "Would")) && Bool.not(String.contains(l, "/Caches/")) && Bool.not(String.contains(l, "/Cellar/")) && Bool.not(String.contains(l, "/vendor/")) && Bool.not(String.contains(l, "tmp/")) && Bool.not(String.contains(l, "empty directory")) && Bool.not(String.starts_with(l, "Run `"))

def removals(ls: List<&2, String>) -> String:
  match ls:
    case []:
      ""
    case +l <> rest:
      pick(interesting(String.trim(l)), "remove   " ++ String.trim(l) ++ "\n", "") ++ removals(rest)

def brew_check(+bf: String) -> IO(Unit):
  do IO<Unit>:
    ok : Bool <- X.ok("brew bundle check --no-upgrade --file " ++ bf ++ " >/dev/null 2>&1")
    IO.print(pick(ok, "", "install  (Homebrew: declared entries missing; brew bundle check --verbose --file " ++ bf ++ ")"))
    cl : String <- X.sh("brew bundle cleanup --file " ++ bf ++ " 2>&1")
    IO.print(removals(String.lines(cl)))

def drop_marker(ls: List<&2, String>) -> String:
  match ls:
    case []:
      ""
    case +l <> rest:
      pick(String.contains(l, "(end of dry run)") || String.is_empty(String.trim(l)), "", l ++ "\n") ++ drop_marker(rest)

def summary(r: Nat & Nat) -> String:
  match r:
    case (n, d):
      "dry run: " ++ Nat.show(n) ++ " preferences checked, " ++ Nat.show(d) ++ " would change"

def dryrun() -> IO(Unit):
  do IO<Unit>:
    I.import_mac()
    +f : P.Facts <- P.read_facts()
    diff : String <- P.run_bend("mac.dryrun.bend")
    IO.print(drop_marker(String.lines(diff)))
    flake : String <- P.run_bend("flake.bend")
    X.write_file("nix/flake.nix", flake)
    mac : String <- P.run_bend("mac.gen.bend")
    X.write_file("nix/mac.nix", mac)
    staged : Bool <- X.ok("git add nix")
    sys : String <- X.sh("/nix/var/nix/profiles/default/bin/nix build \"$(pwd)/nix#darwinConfigurations." ++ P.flake_host(f) ++ ".system\" --no-link --print-out-paths 2>/dev/null")
    act : String <- X.sh("cat " ++ String.trim(sys) ++ "/activate")
    +lines : List<&2, String> = String.lines(act)
    brew_check(brewfile_in(S.words(String.join(lines, " "))))
    r : Nat & Nat <- writes(lines)
    IO.print(summary(r))
