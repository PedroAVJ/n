import Base
import ../../../effs/io.bend as X
import ../../../plan/type.bend as P
import ./type.bend as Br
import ./ops.bend as BrO

# Homebrew as it is, and what applying the declared entries would change. Only brew bundle's read-only
# commands run: dump writes its temporary Brewfile, check and cleanup (without --force) only report.

def declared_file() -> String:
  "/tmp/v-declared.Brewfile"

def observed_file() -> String:
  "/tmp/v-observed.Brewfile"

# brew bundle exits 1 when something is missing or would be removed, and says what: Base's Process.run
# keeps the output of a failing program.
def bundle(args: List<String>) -> IO(Result<&1, &1, U32 & String, U32 & (String & String)>):
  Process.run("brew", "bundle" <> args, "", 67108864, 600000)

# ---- installs: `brew bundle check --verbose` says "→ Formula x needs to be installed." per entry ----
def text_before(cs: List<&2, Char>, +pat: String) -> String:
  match cs:
    case []:
      ""
    case +c <> +rest:
      Bool.pick(String, String.starts_with(String.from_list(c <> rest), pat), "", String.from_list([c]) ++ text_before(rest, pat))

def missing(ls: List<&2, String>) -> List<&2, P.Step>:
  match ls:
    case []:
      []
    case l <> rest:
      +t = String.trim(l)
      List.append(&2, P.Step,
        Bool.pick(List<&2, P.Step>, String.starts_with(t, "→ "),
          [P.Change{"homebrew", "(absent)", text_before(String.to_list(String.drop(t, 2n)), " needs to be ")}], []),
        missing(rest))

def some_or(+xs: List<&2, P.Step>, +f: String) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, List.is_empty(&2, P.Step, xs),
    [P.Change{"homebrew", "declared entries missing", "see brew bundle check --verbose --file " ++ f}], xs)

def installs(r: Result<&1, &1, U32 & String, U32 & (String & String)>, +f: String) -> List<&2, P.Step>:
  match r:
    case Done{(status, (_, err))}:
      Bool.pick(List<&2, P.Step>, U32.is_eq(status, 0), [], some_or(missing(String.lines(err)), f))
    case Fail{_}:
      [P.Blocked{"homebrew", "brew bundle check could not run"}]

# ---- removals: `brew bundle cleanup` lists them under "Would uninstall casks:", "Would untap:" and so on ----
def label_of(+heading: String) -> String:
  Bool.pick(String, String.eq(heading, "casks"), "Cask",
    Bool.pick(String, String.eq(heading, "formulae"), "Formula", heading))

# The label of the section a line starts, the current one for an entry, or "" outside any section.
def section(+l: String, +label: String) -> String:
  Bool.pick(String, String.starts_with(l, "Would uninstall ") && String.ends_with(l, ":"),
    label_of(String.take(String.drop(l, 16n), Nat.sub(String.length(l), 17n))),
    Bool.pick(String, String.eq(l, "Would untap:"), "Tap",
      Bool.pick(String, String.is_empty(l) || String.starts_with(l, "Would ") || String.starts_with(l, "Run ") || String.starts_with(l, "==>"), "", label)))

def removals(ls: List<&2, String>, +label: String) -> List<&2, P.Step>:
  match ls:
    case []:
      []
    case l <> rest:
      +t = String.trim(l)
      +next = section(t, label)
      List.append(&2, P.Step,
        Bool.pick(List<&2, P.Step>, Bool.not(String.is_empty(label)) && String.eq(next, label) && Bool.not(String.is_empty(t)),
          [P.Change{"homebrew", label ++ " " ++ t, "(absent)"}], []),
        removals(rest, next))

def removed(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> List<&2, P.Step>:
  match r:
    case Done{(_, (out, _))}:
      removals(String.lines(out), "")
    case Fail{_}:
      [P.Blocked{"homebrew", "brew bundle cleanup could not run"}]

# What applying the declared entries would install and remove.
def changes(brews: List<&2, Br.Brew>) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    X.write(declared_file(), BrO.brewfile(brews))
    c : Result<&1, &1, U32 & String, U32 & (String & String)> <- bundle(["check", "--no-upgrade", "--verbose", "--file", declared_file()])
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- bundle(["cleanup", "--file", declared_file()])
    return List.append(&2, P.Step, installs(c, declared_file()), removed(r))

# The Mac's Homebrew entries, as `brew bundle dump` writes them.
def observed() -> IO(List<&2, Br.Brew>):
  do IO<List<&2, Br.Brew>>:
    ok : Bool <- X.succeeds("brew", ["bundle", "dump", "--force", "--file=" ++ observed_file()])
    text : String <- X.read(observed_file())
    return Bool.pick(List<&2, Br.Brew>, ok, BrO.of_brewfile(text), [])
