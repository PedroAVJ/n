import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ./type.bend as Pl

# A plugin's manifest as the plugin.json Claude Code reads: optional keys are left out when absent.

def version_show(v: Pl.Version) -> String:
  match v:
    case Pl.Version{major, minor, patch}:
      Nat.show(major) ++ "." ++ Nat.show(minor) ++ "." ++ Nat.show(patch)

# ---- JSON building ----
def with.go(kvs: List<&2, Sigma<&2, &2, String, _ => Json.Val>>, m: Map<&2, Json.Val>) -> Map<&2, Json.Val>:
  match kvs:
    case []:
      m
    case (k, v) <> rest:
      with.go(rest, Map.set(&2, Json.Val, m, k, v))

def obj(kvs: List<&2, Sigma<&2, &2, String, _ => Json.Val>>) -> Json.Val:
  Json.Obj{with.go(kvs, Map.new(&2, Json.Val))}

# A key, or nothing when its value is absent.
def opt(+k: String, m: Maybe<&2, Json.Val>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match m:
    case Some{v}:
      [(k, v)]
    case None{}:
      []

def text(m: Maybe<&2, String>) -> Maybe<&2, Json.Val>:
  match m:
    case Some{s}:
      Some{Json.Str{s}}
    case None{}:
      None{}

def number(m: Maybe<&2, Nat>) -> Maybe<&2, Json.Val>:
  match m:
    case Some{n}:
      Some{Json.Num{Nat.show(n)}}
    case None{}:
      None{}

def flag(m: Maybe<&2, Bool>) -> Maybe<&2, Json.Val>:
  match m:
    case Some{b}:
      Some{Json.Flag{b}}
    case None{}:
      None{}

# A key that is true, or nothing: false is every flag's default.
def when_true(+k: String, b: Bool) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match b:
    case True{}:
      [(k, Json.Flag{True{}})]
    case False{}:
      []

def strs(xs: List<&2, String>) -> List<&2, Json.Val>:
  match xs:
    case []:
      []
    case x <> rest:
      Json.Str{x} <> strs(rest)

def texts(xs: List<&2, String>) -> Json.Val:
  Json.Arr{strs(xs)}

def cat(xss: List<&2, List<&2, Sigma<&2, &2, String, _ => Json.Val>>>) -> Json.Val:
  obj(List.concat(&2, Sigma<&2, &2, String, _ => Json.Val>, xss))

# ---- userConfig ----
def kind_keys(k: Pl.Input) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match k:
    case Pl.Text{sensitive, d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"string"})],
        List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, when_true("sensitive", sensitive), opt("default", text(d))))
    case Pl.Choice{os, d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"string"}), ("options", texts(os))], opt("default", text(d)))
    case Pl.Texts{d}:
      [("type", Json.Str{"string"}), ("multiple", Json.Flag{True{}}), ("default", texts(d))]
    case Pl.Number{lo, hi, d}:
      List.concat(&2, Sigma<&2, &2, String, _ => Json.Val>, [[("type", Json.Str{"number"})], opt("min", number(lo)), opt("max", number(hi)), opt("default", number(d))])
    case Pl.Boolean{d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"boolean"})], opt("default", flag(d)))
    case Pl.Folder{d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"directory"})], opt("default", text(d)))
    case Pl.Path{d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"file"})], opt("default", text(d)))

def field(f: Pl.Field) -> Sigma<&2, &2, String, _ => Json.Val>:
  match f:
    case Pl.Field{key, title, description, required, k}:
      (key, cat([[("title", Json.Str{title}), ("description", Json.Str{description})], when_true("required", required), kind_keys(k)]))

def fields(fs: List<&2, Pl.Field>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match fs:
    case []:
      []
    case f <> rest:
      field(f) <> fields(rest)

# ---- hooks ----
def event_name(e: Pl.HookEvent) -> String:
  match e:
    case Pl.SessionStart{}:
      "SessionStart"
    case Pl.Setup{}:
      "Setup"
    case Pl.UserPromptSubmit{}:
      "UserPromptSubmit"
    case Pl.UserPromptExpansion{}:
      "UserPromptExpansion"
    case Pl.PreToolUse{}:
      "PreToolUse"
    case Pl.PermissionRequest{}:
      "PermissionRequest"
    case Pl.PermissionDenied{}:
      "PermissionDenied"
    case Pl.PostToolUse{}:
      "PostToolUse"
    case Pl.PostToolUseFailure{}:
      "PostToolUseFailure"
    case Pl.PostToolBatch{}:
      "PostToolBatch"
    case Pl.Notification{}:
      "Notification"
    case Pl.MessageDisplay{}:
      "MessageDisplay"
    case Pl.SubagentStart{}:
      "SubagentStart"
    case Pl.SubagentStop{}:
      "SubagentStop"
    case Pl.TaskCreated{}:
      "TaskCreated"
    case Pl.TaskCompleted{}:
      "TaskCompleted"
    case Pl.Stop{}:
      "Stop"
    case Pl.StopFailure{}:
      "StopFailure"
    case Pl.TeammateIdle{}:
      "TeammateIdle"
    case Pl.InstructionsLoaded{}:
      "InstructionsLoaded"
    case Pl.ConfigChange{}:
      "ConfigChange"
    case Pl.CwdChanged{}:
      "CwdChanged"
    case Pl.DirectoryAdded{}:
      "DirectoryAdded"
    case Pl.FileChanged{}:
      "FileChanged"
    case Pl.WorktreeCreate{}:
      "WorktreeCreate"
    case Pl.WorktreeRemove{}:
      "WorktreeRemove"
    case Pl.PreCompact{}:
      "PreCompact"
    case Pl.PostCompact{}:
      "PostCompact"
    case Pl.PreModelSwitch{}:
      "PreModelSwitch"
    case Pl.PostModelSwitch{}:
      "PostModelSwitch"
    case Pl.Elicitation{}:
      "Elicitation"
    case Pl.ElicitationResult{}:
      "ElicitationResult"
    case Pl.SessionEnd{}:
      "SessionEnd"

def shell_name(m: Maybe<&2, Pl.Shell>) -> Maybe<&2, Json.Val>:
  match m:
    case Some{Pl.Bash{}}:
      Some{Json.Str{"bash"}}
    case Some{Pl.PowerShell{}}:
      Some{Json.Str{"powershell"}}
    case None{}:
      None{}

def form_keys(f: Pl.Form) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match f:
    case Pl.Exec{command, args}:
      [("command", Json.Str{command}), ("args", texts(args))]
    case Pl.ShellForm{command, sh}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("command", Json.Str{command})], opt("shell", shell_name(sh)))

def run_keys(r: Pl.Run) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match r:
    case Pl.Blocking{}:
      []
    case Pl.Async{}:
      [("async", Json.Flag{True{}})]
    case Pl.AsyncRewake{}:
      [("asyncRewake", Json.Flag{True{}})]

def handler(h: Pl.Handler) -> Json.Val:
  match h:
    case Pl.Command{f, r, w, t, s}:
      cat([[("type", Json.Str{"command"})], form_keys(f), run_keys(r), opt("if", text(w)), opt("timeout", number(t)), opt("statusMessage", text(s))])

def handlers(hs: List<&2, Pl.Handler>) -> List<&2, Json.Val>:
  match hs:
    case []:
      []
    case h <> rest:
      handler(h) <> handlers(rest)

def group(g: Pl.Group) -> Json.Val:
  match g:
    case Pl.Group{m, hs}:
      cat([opt("matcher", text(m)), [("hooks", Json.Arr{handlers(hs)})]])

def groups(gs: List<&2, Pl.Group>) -> List<&2, Json.Val>:
  match gs:
    case []:
      []
    case g <> rest:
      group(g) <> groups(rest)

def hooks(hs: List<&2, Pl.Hook>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match hs:
    case []:
      []
    case Pl.Hook{e, gs} <> rest:
      (event_name(e), Json.Arr{groups(gs)}) <> hooks(rest)

# ---- the manifest ----
def author(a: Pl.Author) -> Json.Val:
  match a:
    case Pl.Author{name, email, url}:
      cat([[("name", Json.Str{name})], opt("email", text(email)), opt("url", text(url))])

def keywords(xs: List<&2, String>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match xs:
    case []:
      []
    case x <> rest:
      [("keywords", texts(x <> rest))]

def config(fs: List<&2, Pl.Field>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match fs:
    case []:
      []
    case f <> rest:
      [("userConfig", obj(fields(f <> rest)))]

def hooks_key(hs: List<&2, Pl.Hook>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match hs:
    case []:
      []
    case h <> rest:
      [("hooks", obj(hooks(h <> rest)))]

# Enabled is Claude Code's default, so only a plugin that starts disabled says so.
def enabled_key(b: Bool) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match b:
    case True{}:
      []
    case False{}:
      [("defaultEnabled", Json.Flag{False{}})]

def json(m: Pl.Manifest) -> Json.Val:
  match m:
    case Pl.Manifest{name, display, v, description, a, homepage, repository, license, ks, enabled, fs, hs}:
      cat([
        [("name", Json.Str{name})], opt("displayName", text(display)),
        [("version", Json.Str{version_show(v)}), ("description", Json.Str{description}), ("author", author(a))],
        opt("homepage", text(homepage)), opt("repository", text(repository)), opt("license", text(license)),
        keywords(ks), enabled_key(enabled), config(fs), hooks_key(hs)])

# plugin.json's text.
def render(m: Pl.Manifest) -> String:
  Json.encode(json(m)) ++ "\n"
