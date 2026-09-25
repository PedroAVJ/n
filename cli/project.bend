import Base
import ../lib/effs/io.bend as X
import ../lib/vstr.bend as S

# The project `v` runs in: the current folder. Its own Bend programs (facts, plan, flake, laws...)
# are compiled and run from there.

# Compile one of the project's Bend programs to a native binary, then run it; answers its output.
def run_bend(+file: String) -> IO(String):
  X.sh("$HOME/.bend/bin/bend " ++ file ++ " -o /tmp/v-" ++ file ++ ".bin >/dev/null 2>&1 && /tmp/v-" ++ file ++ ".bin")

# Type-check a Bend file (the laws); nothing is run.
def check_bend(file: String) -> IO(String):
  X.sh("$HOME/.bend/bin/bend " ++ file ++ " 2>&1 || true")

# ---- the project's facts (facts.bend): where V's library is, its targets, services and packages ----
type Facts is Data:
  Facts{vlib: String, targets: List<&2, String>, labels: List<&2, String>, ports: List<&2, String>, packages: List<&2, String>, sources: List<&2, String>}

def fact_values(+k: String, ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      S.append(S.line_if(String.starts_with(l, k ++ " "), String.drop(l, Nat.add(String.length(k), 1n))), fact_values(k, rest))

def read_facts() -> IO(Facts):
  do IO<Facts>:
    out : String <- run_bend("facts.bend")
    +ls : List<&2, String> = String.lines(out)
    return Facts{S.nth(fact_values("vlib", ls), 0n), fact_values("target", ls), fact_values("label", ls), fact_values("port", ls), fact_values("package", ls), fact_values("source", ls)}

def vlib_of(f: Facts) -> String:
  match f:
    case Facts{v, _, _, _, _, _}:
      v

def targets_of(f: Facts) -> List<&2, String>:
  match f:
    case Facts{_, t, _, _, _, _}:
      t

def labels_of(f: Facts) -> List<&2, String>:
  match f:
    case Facts{_, _, l, _, _, _}:
      l

def ports_of(f: Facts) -> List<&2, String>:
  match f:
    case Facts{_, _, _, p, _, _}:
      p

def packages_of(f: Facts) -> List<&2, String>:
  match f:
    case Facts{_, _, _, _, p, _}:
      p

def sources_of(f: Facts) -> List<&2, String>:
  match f:
    case Facts{_, _, _, _, _, sources}:
      sources

def target_hit(+name: String, ts: List<&2, String>) -> Bool:
  match ts:
    case []:
      False{}
    case +t <> rest:
      String.eq(S.nth(S.words(t), 0n), name) || target_hit(name, rest)

# Whether the project declares a target ("nix-darwin", "tailscale-serve", "bend-hub").
def has_target(+f: Facts, +name: String) -> Bool:
  target_hit(name, targets_of(f))

def host_in(+name: String, ts: List<&2, String>) -> String:
  match ts:
    case []:
      ""
    case +t <> rest:
      S.pick(String.eq(S.nth(S.words(t), 0n), name), S.nth(S.words(t), 1n), host_in(name, rest))

# The nix-darwin flake host ("" without a nix-darwin target).
def flake_host(+f: Facts) -> String:
  host_in("nix-darwin", targets_of(f))

def github_repo(+f: Facts) -> String:
  host_in("github", targets_of(f))

def target_arg(+name: String, +index: Nat, ts: List<&2, String>) -> String:
  match ts:
    case []:
      ""
    case +t <> rest:
      S.pick(String.eq(S.nth(S.words(t), 0n), name), S.nth(S.words(t), index), target_arg(name, index, rest))

def github_visibility(+f: Facts) -> String:
  target_arg("github", 2n, targets_of(f))

def azure_organization(+f: Facts) -> String:
  target_arg("azure", 1n, targets_of(f))

def azure_project(+f: Facts) -> String:
  target_arg("azure", 2n, targets_of(f))

def when(c: Bool, act: IO(Unit)) -> IO(Unit):
  match c:
    case True{}:
      act
    case False{}:
      IO.pure(Unit, Unit{})
