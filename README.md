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

Inspired by [HumanLayer](https://github.com/humanlayer/humanlayer) and the talk [No Vibes Allowed: Solving Hard Problems in Complex Codebases](https://www.youtube.com/watch?v=rmvDxxNubIg) by Dex Horthy.

Full article: [Advanced Context Engineering for Coding Agents](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md)

This workflow helps AI agents tackle complex tasks in large codebases through structured phases with human checkpoints.

![Research-Plan-Implement Flow](docs/img/research-plan-implement-flow.png)

#### Workflow Commands

| Phase | Command | Description |
|-------|---------|-------------|
| **Research** | [`/hl_research_codebase`](commands/hl_research_codebase.md) | Explore the codebase using parallel sub-agents, document patterns and findings in `docs/` |
| **Plan** | [`/hl_create_plan`](commands/hl_create_plan.md) | Create detailed implementation plans through interactive research and iteration |
| **Implement** | [`/hl_implement_plan`](commands/hl_implement_plan.md) | Execute approved technical plans with verification against success criteria |
| **Report** | [`/hl_report_plan_progress`](commands/hl_report_plan_progress.md) | Save implementation progress and decisions to the plan document for handoff |
| **Validate** | [`/hl_validate_plan`](commands/hl_validate_plan.md) | Validate implementation against the plan, verify success criteria, and identify issues |

#### Helper Commands

Use handoff commands to create a document with work summary and progress, allowing you to start a new session and continue from where the previous session ended. This is an alternative to the auto-compaction feature in coding agents. It's a best practice to avoid auto-compact because it may lose important knowledge from the session.

| Command | Description |
|---------|-------------|
| [`/hl_create_handoff`](commands/hl_create_handoff.md) | Create a concise handoff document to transfer work context to another session |
| [`/hl_resume_handoff`](commands/hl_resume_handoff.md) | Resume work from a handoff document through interactive context analysis |
| [`/hl_describe_pr`](commands/hl_describe_pr.md) | Generate comprehensive PR descriptions following repository templates, run verification checks |

#### Sub-agents for Research

The [`/hl_research_codebase`](commands/hl_research_codebase.md) command uses sub-agents to parallelize and speed up the research process. These are only available in Claude Code, as Codex doesn't support sub-agents yet.

| Sub-agent | Description |
|-----------|-------------|
| [`codebase-analyzer`](agents/codebase-analyzer.md) | Analyzes implementation details, traces data flow, and explains how code works with file:line references |
| [`codebase-locator`](agents/codebase-locator.md) | Locates files and directories relevant to a feature or task; a "super grep/glob" tool |
| [`codebase-pattern-finder`](agents/codebase-pattern-finder.md) | Finds similar implementations and existing patterns with concrete code examples |
| [`docs-analyzer`](agents/docs-analyzer.md) | Extracts high-value insights from project documents, filtering noise for actionable information |
| [`docs-locator`](agents/docs-locator.md) | Discovers relevant documents in the `docs/` directory for historical context |
| [`web-search-researcher`](agents/web-search-researcher.md) | Researches external documentation and resources from the web (only when explicitly requested) |

#### When to Use

- **Complex tasks**: Multiple files, architectural decisions, unfamiliar code
- **Large codebases**: Need to understand existing patterns before making changes
- **Brownfield development**: Working with established code rather than greenfield

For small, well-defined tasks, the Research phase can be skipped. Start directly with Plan or even Implement if the change is trivial.

#### Why is This Important?

A bad line of code is… a bad line of code. But a bad line of a plan could lead to hundreds of bad lines of code. And a bad line of research, a misunderstanding of how the codebase works or where certain functionality is located, could land you with thousands of bad lines of code.

![Error Propagation](docs/img/error-propagation.png)

#### Key Principles

From the HumanLayer methodology:

> Research, plan, implement. When working with AI, you should have it research before it plans, and plan before it codes. Failure to follow this discipline results in your AI will take off in a random direction, get itself lost, and waste your context window. If you're modifying existing code, research will help the AI understand existing patterns. Then there should be a handoff from the research step to the plan step. And then the plan should be consulted when implementing.

## License

MIT
