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

## Available Workflows

### 1. Research + Plan + Implement Workflow

A structured workflow for tackling complex tasks in large codebases, inspired by [HumanLayer](https://github.com/humanlayer/humanlayer). See [full documentation](docs/HumanLayerWorkflow.md).

**Main workflow:**

| Command | Description |
|---------|-------------|
| `/hl_research_codebase` | Research the codebase using parallel sub-agents |
| `/hl_create_plan` | Create detailed implementation plans |
| `/hl_implement_plan` | Execute plans with verification |

**Handoff:**

| Command | Description |
|---------|-------------|
| `/hl_create_handoff` | Create handoff document for session transfer |
| `/hl_resume_handoff` | Resume work from a handoff document |

**Other commands:**

| Command | Description |
|---------|-------------|
| `/hl_report_plan_progress` | Save progress to the plan document |
| `/hl_validate_plan` | Validate implementation against the plan |
| `/hl_describe_pr` | Generate PR descriptions from templates |

### 2. Spec-Driven Workflow

A variation that starts with a specification phase to clarify requirements before research. See [full documentation](docs/SpecDrivenWorkflow.md).

| Command | Description |
|---------|-------------|
| `/mr_create_spec` | Interview user to identify requirements and edge cases; produce `spec.md` |
| `/mr_research_codebase` | Research codebase relevant to the spec; produce `research.md` |
| `/mr_plan` | Create `plan.md` and `plan_phase_N.md` from spec + research |
| `/mr_implement_plan` | Implement using TDD with plan as source of truth |

**Flow variations** (depending on task complexity):
- **Full**: Spec → Research → Plan → Implement
- **Short**: Spec → Plan Mode (Shift+Tab in Claude Code) → Implement
- **Straight**: Spec → Implement (for simple, well-defined features)

## License

MIT
