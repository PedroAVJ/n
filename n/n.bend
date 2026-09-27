import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ./check.bend as C
import ./effects.bend as E
import ./editor.bend as Ed
import ./type.bend as T
import ../domain/architecture/system/release/plugin/type.bend as Pl
import ../domain/architecture/system/release/plugin/ops.bend as PlO
import ../domain/architecture/system/release/plugin/claude/type.bend as Cl
import ../domain/architecture/system/release/plugin/codex/type.bend as Cx

# N: a type checker for prompts. As a Claude Code hook it reads each prompt before the agent does: Jev
# (Near's check) screens each phrase, and Claude runs N4's type error and lint check on what Jev flags,
# giving each finding its one reading or its candidate readings. The agent settles those first. A
# prompt with nothing to settle passes silently, and so does any failure.
#   n hook [item]        the UserPromptSubmit hook: the hook's JSON on stdin, its answer on stdout; the
#                        OpenRouter key from the plugin's option, $OPENROUTER_API_KEY, or Keychain item
#   n dryrun [item]      the same input: what the hook would send to Jev, without sending it
#   n plugin <dir>       build the Claude Code plugin into <dir>, run from the repository's root
#   bend n/n.bend -o n   build n

def model() -> String:
  "typesafe/jev-1.13"

def version() -> Pl.Version:
  Pl.Version{0n, 6n, 0n}

# ---- the hook ----
# Jev screens every phrase; Claude runs N4's checker on what Jev flagged and gives each finding its one
# reading or its candidate readings. Without a key or an answer from Jev, Claude checks the whole
# prompt; without an answer from Claude, Jev's marks are what the agent is told.
def said(silent: Bool, +out: String) -> IO(Unit):
  match silent:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.print(out)

def found(+prompt: String, +fs: List<&2, C.Finding>) -> IO(Unit):
  said(List.is_empty(&2, C.Finding, fs), C.hook_output(prompt, fs))

def unchecked(+ms: List<&2, C.Mark>) -> IO(Unit):
  said(List.is_empty(&2, C.Mark, ms), C.jev_output(ms))

def claude_said(+out: String, +prompt: String, +ms: List<&2, C.Mark>) -> IO(Unit):
  Bool.pick(IO(Unit), String.is_empty(out), unchecked(ms), found(prompt, C.findings(C.text(C.at(Json.parse(out), "result")), prompt)))

def flagged(ms: List<&2, C.Mark>) -> List<&2, C.Phrase>:
  match ms:
    case []:
      []
    case C.Mark{p, _} <> rest:
      p <> flagged(rest)

def by_claude(+conversation: String, +prompt: String, +ms: List<&2, C.Mark>) -> IO(Unit):
  do IO<Unit>:
    +out : String <- E.claude(C.checker_prompt(conversation, prompt, flagged(ms)))
    claude_said(out, prompt, ms)

# Jev answered: nothing flagged is a clean prompt. Jev did not answer: Claude checks everything.
def screened(+response: String, +conversation: String, +prompt: String, +ps: List<&2, C.Phrase>) -> IO(Unit):
  +ms = C.marks(response, ps)
  Bool.pick(IO(Unit), String.is_empty(response), by_claude(conversation, prompt, []),
    Bool.pick(IO(Unit), List.is_empty(&2, C.Mark, ms), IO.pure(Unit, Unit{}), by_claude(conversation, prompt, ms)))

def url(+u: String) -> String:
  Bool.pick(String, String.is_empty(u), E.decisions_url(), u)

def by_jev(no_key: Bool, +k: String, +conversation: String, +prompt: String, +ps: List<&2, C.Phrase>) -> IO(Unit):
  match no_key:
    case True{}:
      by_claude(conversation, prompt, [])
    case False{}:
      do IO<Unit>:
        u : String <- E.env("N_CHECK_URL")
        +response : String <- E.ask(url(u), k, Json.encode(C.request(model(), conversation, prompt, ps)))
        screened(response, conversation, prompt, ps)

def checked(skip: Bool, +path: String, +prompt: String, +item: String) -> IO(Unit):
  match skip:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      do IO<Unit>:
        +k : String <- E.key(item)
        +conversation : String <- E.conversation(path)
        by_jev(String.is_empty(k), k, conversation, prompt, C.phrases(prompt))

# Slash commands, empty prompts and N's own checker are not checked.
def skipped(+prompt: String, +inside: String) -> Bool:
  String.is_empty(String.trim(prompt)) || String.starts_with(String.trim(prompt), "/") || Bool.not(String.is_empty(inside))

def hook(+item: String) -> IO(Unit):
  do IO<Unit>:
    input : String <- E.stdin()
    inside : String <- E.env("N_HOOK")
    +v : Maybe<&2, Json.Val> = Json.parse(input)
    +prompt : String = C.text(C.at(v, "prompt"))
    checked(skipped(prompt, inside), C.text(C.at(v, "transcript_path")), prompt, item)

# ---- the dry run ----
def shown(ps: List<&2, C.Phrase>) -> String:
  match ps:
    case []:
      ""
    case C.Phrase{T.Span{start, end}, t} <> rest:
      "\n  [" ++ Nat.show(start) ++ ", " ++ Nat.show(end) ++ ") \"" ++ t ++ "\"" ++ shown(rest)

def key_source(+k: String) -> String:
  Bool.pick(String, String.is_empty(k), "missing (Claude Code: the plugin's " ++ E.key_option() ++ " option; Codex: $OPENROUTER_API_KEY), so Claude checks every whole prompt",
    "set")

def dryrun(+item: String) -> IO(Unit):
  do IO<Unit>:
    input : String <- E.stdin()
    +v : Maybe<&2, Json.Val> = Json.parse(input)
    +prompt : String = C.text(C.at(v, "prompt"))
    +ps : List<&2, C.Phrase> = C.phrases(prompt)
    +conversation : String <- E.conversation(C.text(C.at(v, "transcript_path")))
    k : String <- E.key(item)
    u : String <- E.env("N_CHECK_URL")
    IO.print("N dry run")
    inside : String <- E.env("N_HOOK")
    IO.print("Skipped: " ++ Bool.show(skipped(prompt, inside)))
    IO.print("Phrases: " ++ Nat.show(List.length(&2, C.Phrase, ps)) ++ shown(ps))
    IO.print("Conversation: " ++ Nat.show(String.length(conversation)) ++ " characters")
    IO.print("Key: " ++ key_source(k))
    IO.print("Would POST to " ++ url(u) ++ ":")
    IO.print(Json.encode(C.request(model(), conversation, prompt, ps)))
    IO.print("Then, for what Jev flags (or everything, without Jev), would ask Claude:")
    IO.print(C.checker_prompt(conversation, prompt, []))
    IO.print("Nothing was sent.")

# ---- Near's composer: Jev's screen, then the deep check on the person's own Claude ----
#   n editor [port]   N's editor, served by Bend (see editor.bend)
#   n screen [item]   {text, conversation} on stdin: Jev's marks, and the checker prompt for Claude
#   n read            {text, answer} on stdin: the marks in Claude's answer
def jev_screen(no_key: Bool, +k: String, +conversation: String, +text: String) -> IO(Unit):
  match no_key:
    case True{}:
      IO.print(C.screened("none", [], C.checker_prompt(conversation, text, [])))
    case False{}:
      do IO<Unit>:
        u : String <- E.env("N_CHECK_URL")
        +ps : List<&2, C.Phrase> = C.phrases(text)
        response : String <- E.ask(url(u), k, Json.encode(C.request(model(), conversation, text, ps)))
        +ms : List<&2, C.Mark> = C.marks(response, ps)
        IO.print(C.screened("Jev", C.jev_marks(text, ms), C.checker_prompt(conversation, text, flagged(ms))))

def screen(+item: String) -> IO(Unit):
  do IO<Unit>:
    input : String <- E.stdin()
    +v : Maybe<&2, Json.Val> = Json.parse(input)
    +k : String <- E.key(item)
    jev_screen(String.is_empty(k), k, C.text(C.at(v, "conversation")), C.text(C.at(v, "text")))

# N's checker prompt for {text, conversation} on stdin, for a caller that asks Claude itself: a chat message
# read against its chat when there is one, else a whole document.
def prompt() -> IO(Unit):
  do IO<Unit>:
    input : String <- E.stdin()
    +v : Maybe<&2, Json.Val> = Json.parse(input)
    +conversation : String = C.text(C.at(v, "conversation"))
    +text : String = C.text(C.at(v, "text"))
    IO.print(Bool.pick(String, String.is_empty(conversation), C.document_prompt(text), C.message_prompt(conversation, text)))

def read() -> IO(Unit):
  do IO<Unit>:
    input : String <- E.stdin()
    +v : Maybe<&2, Json.Val> = Json.parse(input)
    +text : String = C.text(C.at(v, "text"))
    IO.print(C.review("Claude", C.finding_marks(C.findings(C.text(C.at(v, "answer")), text))))

# ---- the plugin ----
# N for Claude Code and Codex, from one folder: both run the same bin/n on each prompt.
def package() -> Pl.Package:
  Pl.Package{
    Pl.Core{"n", version(),
      "N checks each prompt for phrases with more than one reading, and has the agent settle them before it acts.",
      Pl.Author{"Pedro Antonio Villanueva Juarez", None{}, Some{"https://github.com/PedroAVJ"}},
      None{}, Some{"https://github.com/PedroAVJ/n"}, Some{"MIT"}, ["type checker", "prompts", "ambiguity"]},
    Cl.Claude{None{}, True{},
      [Cl.Field{E.key_option(), "OpenRouter API key", "The key N uses to ask Jev, through OpenRouter, which phrases of a prompt are unclear.", True{},
        Cl.Text{True{}, None{}}}],
      [Cl.Hook{Cl.UserPromptSubmit{}, [Cl.Group{None{}, [
        Cl.Command{Cl.Exec{"${CLAUDE_PLUGIN_ROOT}/bin/n", ["hook"]}, Cl.Blocking{}, None{}, Some{120n}, Some{"N is checking the prompt"}}]}]}]},
    Cx.Codex{[Cx.Hook{Cx.UserPromptSubmit{}, [Cx.Group{None{}, [
      Cx.Command{"\"$PLUGIN_ROOT/bin/n\" hook", None{}, Some{120n}, Some{"N is checking the prompt"}, False{}, None{}}]}]}]}}

def built(ok: Bool, +dir: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("Built the N plugin in " ++ dir)
    case False{}:
      IO.die(Unit, 1, "bend could not build " ++ dir ++ "/bin/n; run from the repository's root")

def plugin(+dir: String) -> IO(Unit):
  do IO<Unit>:
    +home : String <- E.env("HOME")
    _ : Bool <- E.succeeds("mkdir", ["-p", dir ++ "/.claude-plugin", dir ++ "/bin"], 5000)
    E.write(dir ++ "/plugin.json", PlO.agent(package()))
    E.write(dir ++ "/.claude-plugin/plugin.json", PlO.claude(package()))
    ok : Bool <- E.succeeds(home ++ "/.bend/bin/bend", ["n/n.bend", "-o", dir ++ "/bin/n"], 600000)
    built(ok, dir)

# ---- the command line ----
def command(+c: String, +arg: String) -> IO(Unit):
  Bool.pick(IO(Unit), String.eq(c, "editor"), Ed.run(Maybe.default(&2, U32, U32.read(arg), 4610)),
  Bool.pick(IO(Unit), String.eq(c, "screen"), screen(arg),
  Bool.pick(IO(Unit), String.eq(c, "read"), read(),
  Bool.pick(IO(Unit), String.eq(c, "prompt"), prompt(),
  Bool.pick(IO(Unit), String.eq(c, "dryrun"), dryrun(arg),
    Bool.pick(IO(Unit), String.eq(c, "plugin") && Bool.not(String.is_empty(arg)), plugin(arg),
      Bool.pick(IO(Unit), String.eq(c, "hook") || String.is_empty(c), hook(arg),
        IO.print("usage: n editor [port] | n screen [keychain item] | n prompt | n read | n hook [keychain item] | n dryrun [keychain item] | n plugin <dir>"))))))))

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
