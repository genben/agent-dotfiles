# Research + Plan + Implement Workflow

Inspired by [HumanLayer](https://github.com/humanlayer/humanlayer) and the talk [No Vibes Allowed: Solving Hard Problems in Complex Codebases](https://www.youtube.com/watch?v=rmvDxxNubIg) by Dex Horthy.

Full article: [Advanced Context Engineering for Coding Agents](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md)

This workflow helps AI agents tackle complex tasks in large codebases through structured phases with human checkpoints.

![Research-Plan-Implement Flow](img/research-plan-implement-flow.png)

## Workflow Commands

| Phase | Command | Description |
|-------|---------|-------------|
| **Research** | [`/hl_research_codebase`](../commands/hl_research_codebase.md) | Explore the codebase using parallel sub-agents, document patterns and findings in `docs/` |
| **Plan** | [`/hl_create_plan`](../commands/hl_create_plan.md) | Create detailed implementation plans through interactive research and iteration |
| **Implement** | [`/hl_implement_plan`](../commands/hl_implement_plan.md) | Execute approved technical plans with verification against success criteria |
| **Report** | [`/hl_report_plan_progress`](../commands/hl_report_plan_progress.md) | Save implementation progress and decisions to the plan document for handoff |
| **Validate** | [`/hl_validate_plan`](../commands/hl_validate_plan.md) | Validate implementation against the plan, verify success criteria, and identify issues |

## Helper Commands

Use handoff commands to create a document with work summary and progress, allowing you to start a new session and continue from where the previous session ended. This is an alternative to the auto-compaction feature in coding agents. It's a best practice to avoid auto-compact because it may lose important knowledge from the session.

| Command | Description |
|---------|-------------|
| [`/hl_create_handoff`](../commands/hl_create_handoff.md) | Create a concise handoff document to transfer work context to another session |
| [`/hl_resume_handoff`](../commands/hl_resume_handoff.md) | Resume work from a handoff document through interactive context analysis |
| [`/hl_describe_pr`](../commands/hl_describe_pr.md) | Generate comprehensive PR descriptions following repository templates, run verification checks |

## Sub-agents for Research

The [`/hl_research_codebase`](../commands/hl_research_codebase.md) command uses sub-agents to parallelize and speed up the research process. These are only available in Claude Code, as Codex doesn't support sub-agents yet.

| Sub-agent | Description |
|-----------|-------------|
| [`codebase-analyzer`](../agents/codebase-analyzer.md) | Analyzes implementation details, traces data flow, and explains how code works with file:line references |
| [`codebase-locator`](../agents/codebase-locator.md) | Locates files and directories relevant to a feature or task; a "super grep/glob" tool |
| [`codebase-pattern-finder`](../agents/codebase-pattern-finder.md) | Finds similar implementations and existing patterns with concrete code examples |
| [`docs-analyzer`](../agents/docs-analyzer.md) | Extracts high-value insights from project documents, filtering noise for actionable information |
| [`docs-locator`](../agents/docs-locator.md) | Discovers relevant documents in the `docs/` directory for historical context |
| [`web-search-researcher`](../agents/web-search-researcher.md) | Researches external documentation and resources from the web (only when explicitly requested) |

## When to Use

- **Complex tasks**: Multiple files, architectural decisions, unfamiliar code
- **Large codebases**: Need to understand existing patterns before making changes
- **Brownfield development**: Working with established code rather than greenfield

For small, well-defined tasks, the Research phase can be skipped. Start directly with Plan or even Implement if the change is trivial.

## Output Artifacts

Each phase produces a specific artifact:

| Phase | Output | Purpose |
|-------|--------|---------|
| Research | `research.md` | Codebase mapping, patterns, integration points |
| Plan | `plan.md` | Design document, phased tasks, success criteria |
| Implement | Code + tests | Working implementation with verification |
| Handoff | `handoff.md` | Session context for resumption |

Artifacts are typically stored in a feature directory under `docs/plans/YYYY-MM-description/`.

## Why is This Important?

A bad line of code is... a bad line of code. But a bad line of a plan could lead to hundreds of bad lines of code. And a bad line of research, a misunderstanding of how the codebase works or where certain functionality is located, could land you with thousands of bad lines of code.

![Error Propagation](img/error-propagation.png)

## Key Principles

From the HumanLayer methodology:

> Research, plan, implement. When working with AI, you should have it research before it plans, and plan before it codes. Failure to follow this discipline results in your AI will take off in a random direction, get itself lost, and waste your context window. If you're modifying existing code, research will help the AI understand existing patterns. Then there should be a handoff from the research step to the plan step. And then the plan should be consulted when implementing.
