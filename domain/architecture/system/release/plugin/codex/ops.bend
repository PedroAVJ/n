import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ../json.bend as J
import ./type.bend as Cx

# Codex's part of a plugin, as the object under extensions."com.openai" in the root plugin.json.

def event_name(e: Cx.HookEvent) -> String:
  match e:
    case Cx.SessionStart{}:
      "SessionStart"
    case Cx.SessionEnd{}:
      "SessionEnd"
    case Cx.PreToolUse{}:
      "PreToolUse"
    case Cx.PostToolUse{}:
      "PostToolUse"
    case Cx.PermissionRequest{}:
      "PermissionRequest"
    case Cx.PreCompact{}:
      "PreCompact"
    case Cx.PostCompact{}:
      "PostCompact"
    case Cx.UserPromptSubmit{}:
      "UserPromptSubmit"
    case Cx.SubagentStart{}:
      "SubagentStart"
    case Cx.SubagentStop{}:
      "SubagentStop"
    case Cx.Stop{}:
      "Stop"
    case Cx.Interrupt{}:
      "Interrupt"

def handler(h: Cx.Handler) -> Json.Val:
  match h:
    case Cx.Command{command, windows, timeout, status, background, limit}:
      J.cat([[("type", Json.Str{"command"}), ("command", Json.Str{command})], J.opt("commandWindows", J.text(windows)),
        J.opt("timeout", J.number(timeout)), J.opt("statusMessage", J.text(status)), J.when_true("async", background),
        J.opt("additionalContextLimit", J.number(limit))])

def handlers(hs: List<&2, Cx.Handler>) -> List<&2, Json.Val>:
  match hs:
    case []:
      []
    case h <> rest:
      handler(h) <> handlers(rest)

def group(g: Cx.Group) -> Json.Val:
  match g:
    case Cx.Group{m, hs}:
      J.cat([J.opt("matcher", J.text(m)), [("hooks", Json.Arr{handlers(hs)})]])

def groups(gs: List<&2, Cx.Group>) -> List<&2, Json.Val>:
  match gs:
    case []:
      []
    case g <> rest:
      group(g) <> groups(rest)

def hooks(hs: List<&2, Cx.Hook>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match hs:
    case []:
      []
    case Cx.Hook{e, gs} <> rest:
      (event_name(e), Json.Arr{groups(gs)}) <> hooks(rest)

def hooks_key(hs: List<&2, Cx.Hook>) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match hs:
    case []:
      []
    case h <> rest:
      [("hooks", J.obj(hooks(h <> rest)))]

def keys(c: Cx.Codex) -> List<&2, Sigma<&2, &2, String, _ => Json.Val>>:
  match c:
    case Cx.Codex{hs}:
      hooks_key(hs)
