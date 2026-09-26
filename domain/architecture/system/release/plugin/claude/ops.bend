import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ../json.bend as J
import ./type.bend as Pl

# Claude Code's part of a plugin, as the keys it adds to .claude-plugin/plugin.json.

# ---- userConfig ----
def kind_keys(k: Pl.Input) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match k:
    case Pl.Text{sensitive, d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"string"})],
        List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, J.when_true("sensitive", sensitive), J.opt("default", J.text(d))))
    case Pl.Choice{os, d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"string"}), ("options", J.texts(os))], J.opt("default", J.text(d)))
    case Pl.Texts{d}:
      [("type", Json.Str{"string"}), ("multiple", Json.Flag{True{}}), ("default", J.texts(d))]
    case Pl.Number{lo, hi, d}:
      List.concat(&2, Sigma<&2, &2, String, _ => Json.Val>, [[("type", Json.Str{"number"})], J.opt("min", J.number(lo)), J.opt("max", J.number(hi)), J.opt("default", J.number(d))])
    case Pl.Boolean{d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"boolean"})], J.opt("default", J.flag(d)))
    case Pl.Folder{d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"directory"})], J.opt("default", J.text(d)))
    case Pl.Path{d}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("type", Json.Str{"file"})], J.opt("default", J.text(d)))

def field(f: Pl.Field) -> Sigma<&2, &2, String, _ => Json.Val>:
  match f:
    case Pl.Field{key, title, description, required, k}:
      (key, J.cat([[("title", Json.Str{title}), ("description", Json.Str{description})], J.when_true("required", required), kind_keys(k)]))

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
      [("command", Json.Str{command}), ("args", J.texts(args))]
    case Pl.ShellForm{command, sh}:
      List.append(&2, Sigma<&2, &2, String, _ => Json.Val>, [("command", Json.Str{command})], J.opt("shell", shell_name(sh)))

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
      J.cat([[("type", Json.Str{"command"})], form_keys(f), run_keys(r), J.opt("if", J.text(w)), J.opt("timeout", J.number(t)), J.opt("statusMessage", J.text(s))])

def handlers(hs: List<&2, Pl.Handler>) -> List<&2, Json.Val>:
  match hs:
    case []:
      []
    case h <> rest:
      handler(h) <> handlers(rest)

def group(g: Pl.Group) -> Json.Val:
  match g:
    case Pl.Group{m, hs}:
      J.cat([J.opt("matcher", J.text(m)), [("hooks", Json.Arr{handlers(hs)})]])

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

# ---- Claude Code's part of .claude-plugin/plugin.json ----
def config(fs: List<&2, Pl.Field>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match fs:
    case []:
      []
    case f <> rest:
      [("userConfig", J.obj(fields(f <> rest)))]

def hooks_key(hs: List<&2, Pl.Hook>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match hs:
    case []:
      []
    case h <> rest:
      [("hooks", J.obj(hooks(h <> rest)))]

# Enabled is Claude Code's default, so only a plugin that starts disabled says so.
def enabled_key(b: Bool) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match b:
    case True{}:
      []
    case False{}:
      [("defaultEnabled", Json.Flag{False{}})]

def keys(c: Pl.Claude) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match c:
    case Pl.Claude{display, enabled, fs, hs}:
      List.concat(&2, Sigma<&2, &2, String, _ => Json.Val>, [J.opt("displayName", J.text(display)), enabled_key(enabled), config(fs), hooks_key(hs)])
