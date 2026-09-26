import Base

# What Codex adds to a plugin's core under extensions."com.openai" in the root plugin.json, after OpenAI's
# plugin guide (developers.openai.com/plugins/build/plugins) and Codex's hooks reference
# (learn.chatgpt.com/docs/hooks). Covered: command hooks declared inline. Not yet: apps (MCP server
# mappings), the interface block, and mcp_tool hooks.

type HookEvent is Data:
  SessionStart{}
  SessionEnd{}
  PreToolUse{}
  PostToolUse{}
  PermissionRequest{}
  PreCompact{}
  PostCompact{}
  UserPromptSubmit{}
  SubagentStart{}
  SubagentStop{}
  Stop{}
  Interrupt{}

# A command hook, run through the shell. `windows` replaces the command on Windows; timeout is in seconds;
# `limit` caps, in tokens, the context the hook may add (2500 when absent).
type Handler is Data:
  Command{command: String, windows: Maybe<&2, String>, timeout: Maybe<&2, Nat>, status: Maybe<&2, String>,
    background: Bool, limit: Maybe<&2, Nat>}

# A matcher group: with no matcher, it matches every occurrence of its event.
type Group is Data:
  Group{matcher: Maybe<&2, String>, handlers: List<&2, Handler>}

type Hook is Data:
  Hook{event: HookEvent, groups: List<&2, Group>}

type Codex is Data:
  Codex{hooks: List<&2, Hook>}
