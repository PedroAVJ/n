import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ./check.bend as C
import ./effects.bend as E
import ./type.bend as T

# N: a type checker for prompts. As a Claude Code hook it reads each prompt before the agent does, asks
# Jev which phrases have more than one reading given the conversation, and hands the agent those
# phrases to settle first. A prompt with nothing to settle passes silently, and so does any failure.
#   n hook               the UserPromptSubmit hook: the hook's JSON on stdin, its answer on stdout
#   n dryrun             the same input: what the hook would send to Jev, without sending it
#   n plugin <dir>       build the Claude Code plugin into <dir>, run from the repository's root
#   bend n/n.bend -o n   build n

def model() -> String:
  "typesafe/jev-1.13"

def version() -> String:
  "0.2.0"

# ---- the hook ----
def told(ms: List<&2, C.Mark>) -> IO(Unit):
  match ms:
    case []:
      IO.pure(Unit, Unit{})
    case m <> rest:
      IO.print(C.hook_output(m <> rest))

def url(+u: String) -> String:
  Bool.pick(String, String.is_empty(u), E.decisions_url(), u)

def asked(missing: Bool, +k: String, +path: String, +prompt: String, +ps: List<&2, C.Phrase>) -> IO(Unit):
  match missing:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      do IO<Unit>:
        conversation : String <- E.conversation(path)
        u : String <- E.env("N_CHECK_URL")
        response : String <- E.ask(url(u), k, Json.encode(C.request(model(), conversation, prompt, ps)))
        told(C.marks(response, ps))

def checked(skip: Bool, +path: String, +prompt: String) -> IO(Unit):
  match skip:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      do IO<Unit>:
        +k : String <- E.key()
        asked(String.is_empty(k), k, path, prompt, C.phrases(prompt))

# Slash commands and empty prompts are not checked.
def skipped(+prompt: String) -> Bool:
  String.is_empty(String.trim(prompt)) || String.starts_with(String.trim(prompt), "/")

def hook() -> IO(Unit):
  do IO<Unit>:
    input : String <- E.stdin()
    +v : Maybe<&2, Json.Val> = Json.parse(input)
    +prompt : String = C.text(C.at(v, "prompt"))
    checked(skipped(prompt), C.text(C.at(v, "transcript_path")), prompt)

# ---- the dry run ----
def shown(ps: List<&2, C.Phrase>) -> String:
  match ps:
    case []:
      ""
    case C.Phrase{T.Span{start, end}, t} <> rest:
      "\n  [" ++ Nat.show(start) ++ ", " ++ Nat.show(end) ++ ") \"" ++ t ++ "\"" ++ shown(rest)

def key_source(+env: String, +k: String) -> String:
  Bool.pick(String, Bool.not(String.is_empty(String.trim(env))), "found in $OPENROUTER_API_KEY",
    Bool.pick(String, Bool.not(String.is_empty(k)), "found in the Keychain (" ++ E.keychain_service() ++ ")",
      "missing: live checks would pass every prompt silently until $OPENROUTER_API_KEY or the Keychain item " ++ E.keychain_service() ++ " exists"))

def dryrun() -> IO(Unit):
  do IO<Unit>:
    input : String <- E.stdin()
    +v : Maybe<&2, Json.Val> = Json.parse(input)
    +prompt : String = C.text(C.at(v, "prompt"))
    +ps : List<&2, C.Phrase> = C.phrases(prompt)
    +conversation : String <- E.conversation(C.text(C.at(v, "transcript_path")))
    env : String <- E.env("OPENROUTER_API_KEY")
    k : String <- E.key()
    u : String <- E.env("N_CHECK_URL")
    IO.print("N dry run")
    IO.print("Skipped: " ++ Bool.show(skipped(prompt)))
    IO.print("Phrases: " ++ Nat.show(List.length(&2, C.Phrase, ps)) ++ shown(ps))
    IO.print("Conversation: " ++ Nat.show(String.length(conversation)) ++ " characters")
    IO.print("Key: " ++ key_source(env, k))
    IO.print("Would POST to " ++ url(u) ++ ":")
    IO.print(Json.encode(C.request(model(), conversation, prompt, ps)))
    IO.print("Nothing was sent.")

# ---- the plugin ----
def manifest() -> String:
  Json.encode(C.obj([
    ("name", C.str("n")),
    ("version", C.str(version())),
    ("description", C.str("N checks each prompt for phrases with more than one reading, and has Claude settle them before it acts.")),
    ("author", C.obj([("name", C.str("Pedro Antonio Villanueva Juarez"))])),
    ("repository", C.str("https://github.com/PedroAVJ/n")),
    ("license", C.str("MIT"))]))

def hooks() -> String:
  Json.encode(C.obj([
    ("description", C.str("N checks the prompt before Claude reads it.")),
    ("hooks", C.obj([
      ("UserPromptSubmit", Json.Arr{[C.obj([
        ("hooks", Json.Arr{[C.obj([
          ("type", C.str("command")),
          ("command", C.str("\"${CLAUDE_PLUGIN_ROOT}/bin/n\" hook")),
          ("timeout", Json.Num{"20"})])]})])]})]))]))

def built(ok: Bool, +dir: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("Built the N plugin in " ++ dir)
    case False{}:
      IO.die(Unit, 1, "bend could not build " ++ dir ++ "/bin/n; run from the repository's root")

def plugin(+dir: String) -> IO(Unit):
  do IO<Unit>:
    +home : String <- E.env("HOME")
    _ : Bool <- E.succeeds("mkdir", ["-p", dir ++ "/.claude-plugin", dir ++ "/hooks", dir ++ "/bin"], 5000)
    E.write(dir ++ "/.claude-plugin/plugin.json", manifest() ++ "\n")
    E.write(dir ++ "/hooks/hooks.json", hooks() ++ "\n")
    ok : Bool <- E.succeeds(home ++ "/.bend/bin/bend", ["n/n.bend", "-o", dir ++ "/bin/n"], 600000)
    built(ok, dir)

# ---- the command line ----
def command(+c: String, +arg: String) -> IO(Unit):
  Bool.pick(IO(Unit), String.eq(c, "dryrun"), dryrun(),
    Bool.pick(IO(Unit), String.eq(c, "plugin") && Bool.not(String.is_empty(arg)), plugin(arg),
      Bool.pick(IO(Unit), String.eq(c, "hook") || String.is_empty(c), hook(),
        IO.print("usage: n hook | n dryrun | n plugin <dir>"))))

def dispatch(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case []:
      command("", "")
    case c <> rest:
      match rest:
        case []:
          command(c, "")
        case a <> _:
          command(c, a)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    dispatch(args)
