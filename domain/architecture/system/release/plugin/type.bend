import Base
import ./claude/type.bend as Cl
import ./codex/type.bend as Cx

# A plugin for Claude Code and Codex, from one folder. Its core is an Agent Plugins 1.0 manifest
# (agent-plugins.org/schemas/1.0.0/plugin.schema.json), the root plugin.json that Codex reads, with Codex's
# own settings under extensions."com.openai". Claude Code reads .claude-plugin/plugin.json, which repeats
# the core and adds Claude Code's settings. Hooks are no part of the standard: each client declares its own.

# The version: semver, shown as major.minor.patch.
type Version is Data:
  Version{major: Nat, minor: Nat, patch: Nat}

type Author is Data:
  Author{name: String, email: Maybe<&2, String>, url: Maybe<&2, String>}

# name: 1 to 64 of a-z, 0-9, . and -, starting and ending with a letter or digit, with no -- or ..
type Core is Data:
  Core{name: String, version: Version, description: String, author: Author, homepage: Maybe<&2, String>,
    repository: Maybe<&2, String>, license: Maybe<&2, String>, keywords: List<&2, String>}

type Package is Data:
  Package{core: Core, claude: Cl.Claude, codex: Cx.Codex}
