# agent-dotfiles

Custom configurations for AI coding agents (Claude Code, Codex). This repository contains slash commands, skills, templates, and other customizations that extend agent capabilities.

## Supported Agents

| Agent | Config Location | Status |
|-------|-----------------|--------|
| Claude Code | `~/.claude/` | Full support |
| Codex | `~/.codex/` | Partial (no sub-agents) |

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/agent-dotfiles.git
cd agent-dotfiles

# Install for Claude Code
./install.sh claude

# Install for Codex
./install.sh codex

# Non-interactive mode (for automation)
./install.sh claude -n
```

The install script creates symlinks from this repository to the agent's config directory. This allows you to version control your customizations and easily sync them across machines.

## Uninstallation

```bash
./uninstall.sh claude
./uninstall.sh codex
```

Only symlinks pointing to this repository are removed. Existing directories are left unchanged.

## Directory Structure

| Directory | Description | Claude Code | Codex |
|-----------|-------------|-------------|-------|
| `commands/` | Custom slash commands | `~/.claude/commands/` | `~/.codex/prompts/` |
| `agents/` | Sub-agent definitions | `~/.claude/agents/` | Not supported |
| `skills/` | Skill definitions | `~/.claude/skills/` | `~/.codex/skills/` |
| `templates/` | Reusable templates | `~/.claude/templates/` | `~/.codex/templates/` |
| `scripts/` | Helper scripts | `~/.claude/scripts/` | `~/.codex/scripts/` |

## Usage

After installation, custom commands are available in your agent session:

```
# In Claude Code
/mr_create_spec    # Create a specification document
/mr_plan           # Create an implementation plan
/mr_implement_plan # Implement the plan

# In Codex (commands are called "prompts")
/prompts:mr_create_spec
```

To invoke a skill, ask the agent to use it: "use circleci skill to check build status".

## License

MIT
