import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ./check.bend as C

# N's effects: the hook's input, the conversation so far, the OpenRouter key, and the calls to Jev and
# Claude.
# Every failure answers "" so that a broken check never stands between the person and their prompt.

# ---- standard input ----
def stdin_read(r: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  match r:
    case (f, Done{t}):
      do IO<String>:
        File.close(f)
        return t
    case (f, Fail{_}):
      do IO<String>:
        File.close(f)
        return ""

def stdin_opened(r: Result<&1, &1, U32 & String, File>) -> IO(String):
  match r:
    case Done{f}:
      do IO<String>:
        got : File & Result<&1, &1, U32 & String, String> <- File.read(f, 4194304)
        stdin_read(got)
    case Fail{_}:
      IO.pure(String, "")

def stdin() -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, File> <- File.open("/dev/stdin", "r")
    stdin_opened(r)

# ---- running a program: its standard output when it exits 0, else "" ----
def out_of(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> String:
  match r:
    case Done{(+status, (out, _))}:
      Bool.pick(String, U32.is_eq(status, 0), out, "")
    case Fail{_}:
      ""

def run(program: String, args: List<String>, input: String, +timeout_ms: U32) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run(program, args, input, 8388608, timeout_ms)
    return out_of(r)

def env(name: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
    return Result.default(&1, &1, U32 & String, String, r, "")

# ---- the conversation so far, from the transcript Claude Code keeps ----
# A text block: Claude Code's "text", Codex's "input_text" and "output_text".
def part(+v: Json.Val) -> String:
  +t = C.text(Json.get(v, "type"))
  Bool.pick(String, String.eq(t, "text") || String.eq(t, "input_text") || String.eq(t, "output_text"), C.text(Json.get(v, "text")), "")

def parts(vs: List<&2, Json.Val>) -> String:
  match vs:
    case []:
      ""
    case v <> rest:
      part(v) ++ parts(rest)

# A message's text: its content when it is a string, else its text blocks. Tool calls and their
# results have none.
def content(m: Maybe<&2, Json.Val>) -> String:
  match m:
    case Some{Json.Str{s}}:
      s
    case Some{Json.Arr{vs}}:
      parts(vs)
    case _:
      ""

# What the user or the assistant said. Context the agent injects as the user's (Codex's environment and
# instructions, in tags) is not what the user said.
def said(+role: String, +t: String) -> String:
  Bool.pick(String, (String.eq(role, "user") || String.eq(role, "assistant")) && Bool.not(String.is_empty(String.trim(t))) &&
    Bool.not(String.starts_with(String.trim(t), "<")) && Bool.not(String.starts_with(String.trim(t), "# AGENTS.md")),
    role ++ ": " ++ String.take(String.trim(t), 1500n), "")

# A transcript line: Claude Code's {type, message{content}}, or Codex's {type: "response_item",
# payload{type: "message", role, content}}.
def entry(+line: String) -> String:
  +v = Json.parse(line)
  +payload = C.at(v, "payload")
  Bool.pick(String, String.eq(C.text(C.at(v, "type")), "response_item"),
    said(C.text(C.at(payload, "role")), content(C.at(payload, "content"))),
    said(C.text(C.at(v, "type")), content(C.at(C.at(v, "message"), "content"))))

def entries(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      +e = entry(l)
      +r = entries(rest)
      Bool.pick(List<&2, String>, String.is_empty(e), r, e <> r)

def drop_partial(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case _ <> rest:
      rest

# The last messages of the conversation, oldest first. The transcript's tail starts mid-line, so its
# first line is dropped.
def conversation(+path: String) -> IO(String):
  do IO<String>:
    tail : String <- run("tail", ["-c", "60000", path], "", 3000)
    +said : List<&2, String> = entries(drop_partial(String.lines(tail)))
    return String.join(List.drop(&2, String, said, Nat.sub(List.length(&2, String, said), 8n)), "\n\n")

# ---- the OpenRouter key: the plugin's openrouter_api_key option, which Claude Code asks for when the
# plugin is enabled, keeps in the platform's secure store, and hands to the hook ----
def key_option() -> String:
  "openrouter_api_key"

# The key, first found of: the plugin's option (Claude Code), $OPENROUTER_API_KEY, and the Keychain item
# the hook's configuration names (none when it names none).
def key_or(+option: String, +variable: String) -> String:
  Bool.pick(String, String.is_empty(String.trim(option)), String.trim(variable), String.trim(option))

def keychain(missing: Bool, +found: String, +item: String) -> IO(String):
  match missing:
    case False{}:
      IO.pure(String, found)
    case True{}:
      Bool.pick(IO(String), String.is_empty(item), IO.pure(String, ""),
        do IO<String>:
          k : String <- run("security", ["find-generic-password", "-s", item, "-w"], "", 5000)
          return String.trim(k))

def key(+item: String) -> IO(String):
  do IO<String>:
    k : String <- env("CLAUDE_PLUGIN_OPTION_OPENROUTER_API_KEY")
    v : String <- env("OPENROUTER_API_KEY")
    +found : String = key_or(k, v)
    keychain(String.is_empty(found), found, item)

# ---- asking Jev ----
def esc.go(cs: List<&2, Char>) -> List<&2, Char>:
  match cs:
    case []:
      []
    case +c <> rest:
      +r = esc.go(rest)
      Bool.pick(List<&2, Char>, Char.is_eq(c, '\\') || Char.is_eq(c, '"'), '\\' <> c <> r, c <> r)

# A string for curl's config syntax: backslashes and quotes escaped.
def esc(s: String) -> String:
  String.from_list(esc.go(String.to_list(s)))

def decisions_url() -> String:
  "https://openrouter.ai/api/alpha/decisions"

# The key and the body go to curl on its standard input, so neither shows up in the process list.
def curl_config(+url: String, +k: String, +body: String) -> String:
  "url = \"" ++ esc(url) ++ "\"\n" ++
  "header = \"Content-Type: application/json\"\n" ++
  "header = \"Authorization: Bearer " ++ esc(k) ++ "\"\n" ++
  "data-binary = \"" ++ esc(body) ++ "\"\n"

def ask(+url: String, +k: String, +body: String) -> IO(String):
  run("curl", ["-sS", "--fail", "--max-time", "12", "--config", "-"], curl_config(url, k, body), 14000)

# ---- building the plugin ----
def succeeded(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> Bool:
  match r:
    case Done{(+status, _)}:
      U32.is_eq(status, 0)
    case Fail{_}:
      False{}

def succeeds(program: String, args: List<String>, +timeout_ms: U32) -> IO(Bool):
  do IO<Bool>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run(program, args, "", 8388608, timeout_ms)
    return succeeded(r)

def written(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case (f, _):
      File.close(f)

def write_opened(r: Result<&1, &1, U32 & String, File>, text: String) -> IO(Unit):
  match r:
    case Done{f}:
      do IO<Unit>:
        w : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, text)
        written(w)
    case Fail{_}:
      IO.die(Unit, 1, "cannot write a file")

def write(path: String, text: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
    write_opened(r, text)

# ---- asking Claude: N4's checker, on the person's own Claude Code subscription ----
# Hooks are off inside it, and N_HOOK marks it, so N never checks its own checker's prompt.
def claude(+prompt: String) -> IO(String):
  run("env", ["-u", "CLAUDECODE", "N_HOOK=1", "claude", "-p", "--output-format", "json", "--no-session-persistence",
    "--permission-mode", "dontAsk", "--settings", "{\"disableAllHooks\":true}"], prompt, 90000)
