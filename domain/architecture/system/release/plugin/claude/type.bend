import Base

# What Claude Code adds to a plugin's core in .claude-plugin/plugin.json, after Claude Code's plugin
# manifest reference (code.claude.com/docs/en/plugins-reference) and hooks reference
# (code.claude.com/docs/en/hooks). The schema's rules are in the shapes: a field's input carries only the
# keys its type accepts, and a hook handler is exec form or shell form, never both. Covered: the display
# name, whether it starts enabled, userConfig, and command hooks declared inline. Not yet: commands,
# agents, MCP and LSP servers, channels, output styles, workflows, settings, dependencies and the
# experimental block.

# ---- userConfig: values Claude Code asks for when the plugin is enabled ----
# Text: one string; sensitive ones are masked and kept in the platform's secure store. Choice: one of
# fixed options (never sensitive or multiple). Texts: several strings.
type Input is Data:
  Text{sensitive: Bool, value: Maybe<&2, String>}
  Choice{options: List<&2, String>, value: Maybe<&2, String>}
  Texts{value: List<&2, String>}
  Number{min: Maybe<&2, Nat>, max: Maybe<&2, Nat>, value: Maybe<&2, Nat>}
  Boolean{value: Maybe<&2, Bool>}
  Folder{value: Maybe<&2, String>}
  Path{value: Maybe<&2, String>}

# A field's key is letters, digits and _, not starting with a digit. Hooks read it as
# $CLAUDE_PLUGIN_OPTION_<KEY>.
type Field is Data:
  Field{key: String, title: String, description: String, required: Bool, input: Input}

# ---- hooks ----
type HookEvent is Data:
  SessionStart{}
  Setup{}
  UserPromptSubmit{}
  UserPromptExpansion{}
  PreToolUse{}
  PermissionRequest{}
  PermissionDenied{}
  PostToolUse{}
  PostToolUseFailure{}
  PostToolBatch{}
  Notification{}
  MessageDisplay{}
  SubagentStart{}
  SubagentStop{}
  TaskCreated{}
  TaskCompleted{}
  Stop{}
  StopFailure{}
  TeammateIdle{}
  InstructionsLoaded{}
  ConfigChange{}
  CwdChanged{}
  DirectoryAdded{}
  FileChanged{}
  WorktreeCreate{}
  WorktreeRemove{}
  PreCompact{}
  PostCompact{}
  PreModelSwitch{}
  PostModelSwitch{}
  Elicitation{}
  ElicitationResult{}
  SessionEnd{}

type Shell is Data:
  Bash{}
  PowerShell{}

# Exec form runs the executable with exactly these arguments, no shell; shell form hands the command to
# a shell (the platform's own when none is named).
type Form is Data:
  Exec{command: String, args: List<&2, String>}
  ShellForm{command: String, shell: Maybe<&2, Shell>}

# Blocking waits for the hook; Async runs it in the background; AsyncRewake also wakes Claude when it
# exits with 2.
type Run is Data:
  Blocking{}
  Async{}
  AsyncRewake{}

# A command hook. `when` is a permission rule that filters when it runs; timeout is in seconds.
type Handler is Data:
  Command{form: Form, run: Run, when: Maybe<&2, String>, timeout: Maybe<&2, Nat>, status: Maybe<&2, String>}

# A matcher group: with no matcher, it matches every occurrence of its event.
type Group is Data:
  Group{matcher: Maybe<&2, String>, handlers: List<&2, Handler>}

type Hook is Data:
  Hook{event: HookEvent, groups: List<&2, Group>}

# ---- Claude Code's part ----
type Claude is Data:
  Claude{display: Maybe<&2, String>, enabled: Bool, config: List<&2, Field>, hooks: List<&2, Hook>}
