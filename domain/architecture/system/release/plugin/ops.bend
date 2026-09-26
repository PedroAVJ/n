import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ./json.bend as J
import ./type.bend as Pl
import ./claude/ops.bend as ClO
import ./codex/ops.bend as CxO

# A plugin's two manifests: the root plugin.json (Agent Plugins 1.0, which Codex reads) and
# .claude-plugin/plugin.json (which Claude Code reads).

def schema() -> String:
  "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"

def version_show(v: Pl.Version) -> String:
  match v:
    case Pl.Version{major, minor, patch}:
      Nat.show(major) ++ "." ++ Nat.show(minor) ++ "." ++ Nat.show(patch)

def author(a: Pl.Author) -> Json.Val:
  match a:
    case Pl.Author{name, email, url}:
      J.cat([[("name", Json.Str{name})], J.opt("email", J.text(email)), J.opt("url", J.text(url))])

def keywords(xs: List<&2, String>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match xs:
    case []:
      []
    case x <> rest:
      [("keywords", J.texts(x <> rest))]

def core_keys(c: Pl.Core) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match c:
    case Pl.Core{name, v, description, a, homepage, repository, license, ks}:
      List.concat(&2, Sigma<&2, &2, String, _ => Json.Val>, [
        [("name", Json.Str{name}), ("version", Json.Str{version_show(v)}), ("description", Json.Str{description}), ("author", author(a))],
        J.opt("homepage", J.text(homepage)), J.opt("repository", J.text(repository)), J.opt("license", J.text(license)), keywords(ks)])

# Codex's extension, or nothing when Codex adds nothing.
def extensions(kvs: List<&2, Sigma<&2, &2, String, _ => Json.Val>>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match kvs:
    case []:
      []
    case kv <> rest:
      [("extensions", J.obj([("com.openai", J.obj(kv <> rest))]))]

# The root plugin.json's text.
def agent(p: Pl.Package) -> String:
  match p:
    case Pl.Package{c, _, cx}:
      Json.encode(J.cat([[("$schema", Json.Str{schema()})], core_keys(c), extensions(CxO.keys(cx))])) ++ "\n"

# .claude-plugin/plugin.json's text.
def claude(p: Pl.Package) -> String:
  match p:
    case Pl.Package{c, cl, _}:
      Json.encode(J.cat([core_keys(c), ClO.keys(cl)])) ++ "\n"

def name_of(p: Pl.Package) -> String:
  match p:
    case Pl.Package{Pl.Core{n, _, _, _, _, _, _, _}, _, _}:
      n

# ---- the standard's rule for a name ----
def name_char(+c: Char) -> Bool:
  Char.is_lower(c) || Char.is_digit(c) || Char.is_eq(c, '.') || Char.is_eq(c, '-')

def edge_char(+c: Char) -> Bool:
  Char.is_lower(c) || Char.is_digit(c)

def repeats(cs: List<&2, Char>, +prev: Char) -> Bool:
  match cs:
    case []:
      False{}
    case +c <> rest:
      ((Char.is_eq(c, '-') || Char.is_eq(c, '.')) && Char.is_eq(c, prev)) || repeats(rest, c)

def all_name_chars(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case +c <> rest:
      name_char(c) && all_name_chars(rest)

def first_ok(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      False{}
    case +c <> _:
      edge_char(c)

# 1 to 64 of a-z, 0-9, . and -, starting and ending with a letter or digit, with no -- or ..
def name_ok(+n: String) -> Bool:
  Nat.is_ge(String.length(n), 1n) && Nat.is_le(String.length(n), 64n) && all_name_chars(String.to_list(n)) &&
  first_ok(String.to_list(n)) && first_ok(String.to_list(String.reverse(n))) && Bool.not(repeats(String.to_list(n), ' '))
