# Executable Plan Workflow

A simplified two-step workflow inspired by [OpenAI's Codex Execution Plans](https://cookbook.openai.com/articles/codex_exec_plans) and Aaron Friel's talk [Shipping with Codex](https://www.youtube.com/watch?v=Gr41tYOzE20&t=770s).

This workflow combines research and planning into a single phase, producing a self-contained plan that any agent can follow to deliver a working feature.

## Workflow Commands

| Command | Description |
|---------|-------------|
| [`/ep_create_exec_plan`](../commands/ep_create_exec_plan.md) | Analyze user-provided spec, research codebase, and create executable plan (`plan.md`) |
| [`/ep_implement_exec_plan`](../commands/ep_implement_exec_plan.md) | Implement the plan autonomously, maintaining it as a living document |

## Workflow Steps

```
[spec.md] → /ep_create_exec_plan → /ep_implement_exec_plan
```

1. **Create Spec** (recommended): Use `/mr_create_spec` to create a specification document first
2. **Create Plan**: Research the codebase and create an executable plan in one shot
3. **Implement**: Execute the plan autonomously, updating it as work proceeds

## Output Artifacts

| Phase | Output | Purpose |
|-------|--------|---------|
| Spec (optional) | `spec.md` | Requirements, acceptance criteria, edge cases |
| Plan | `plan.md` + milestone files | Self-contained plan with progress tracking |
| Implement | Code + tests | Working implementation with verification |

The plan serves as both the design document and the session resumption point.

## Key Features

### Self-Contained Plans

Each plan contains everything needed for a novice agent to succeed:
- Purpose and context
- Concrete steps with exact commands
- Validation and acceptance criteria
- Progress tracking with timestamps and git commits

### Living Document

The plan is maintained throughout implementation:
- **Progress**: Checkbox list updated at every stopping point
- **Surprises & Discoveries**: Unexpected findings with evidence
- **Decision Log**: All decisions with rationale
- **Outcomes & Retrospective**: Results at milestones and completion

This enables session resumption - if the session ends, another agent can pick up from the plan.

### Autonomous Implementation

The implementation command encourages the agent to:
- Proceed to the next milestone without prompting for "next steps"
- Resolve ambiguities autonomously (documenting in Decision Log)
- Commit frequently after each milestone
- Only ask the user when truly blocked

### Milestone Offloading

To keep the main plan lean, large code snippets and detailed milestone content are offloaded to separate files (one per milestone/phase).

## When to Use

This workflow was designed for **Codex**, which has different characteristics than Claude Code:

| Aspect | Codex | Claude Code |
|--------|-------|-------------|
| **Context window** | 400K tokens | 200K tokens |
| **Speed** | Slower | Faster |
| **Work style** | Autonomous (hours of work) | Interactive |
| **Token consumption** | More efficient | Higher consumption |

**Why Codex favors autonomous workflows:**
- Codex can work autonomously for hours without user intervention
- Larger context window allows holding more codebase context
- Slower speed makes interactive back-and-forth less practical
- Meticulous, thorough codebase research

**Why Claude Code prefers interactive workflows:**
- Faster responses enable real-time collaboration
- Smaller context window fills up faster
- Auto-compact can degrade work quality when it kicks in
- Interactive mode leverages Claude Code's speed advantage

**Use this workflow when:**
- Working with Codex (designed for its autonomous nature)
- Expecting long-running tasks without user intervention

**With Claude Code:**
- Works fine, but re-read the plan if auto-compact kicks in
- Consider the HumanLayer or Spec-Driven workflows for better interactive experience
- Monitor context usage closely and restart sessions as needed

## Specification Modifications

The [`ExecPlanSpec.md`](../templates/ExecPlanSpec.md) template is a modified version of the [original OpenAI specification](../_archive/templates/ExecPlans.md).

Key differences from the original:

| Aspect | Original | Modified | Motivation |
|--------|----------|----------|------------|
| **External references** | "Do not point to external blogs or docs" | Can reference external sources with summary | Keep the plan document lean |
| **Self-contained** | Strictly self-contained, embed everything | References acceptable with descriptions | Keep the plan document lean |
| **Formatting** | Single fenced code block, no nested fences | Removed formatting restrictions | Original seems like a workaround for web UI limitations |
| **Large code snippets** | Inline in plan | Outsourced to external files (one per milestone) | Keep the plan document lean |
| **Progress tracking** | Timestamps only | Timestamps + git commit hashes | Easier code review |
| **Terminology** | Uses "ExecPlan" throughout | Clarifies "Spec" (this doc) vs "Plan" (output) | Remove confusion in terms |

## Tips

- **Create a spec first**: Use `/mr_create_spec` before creating the executable plan for better results
- **Review the plan**: Check the generated `plan.md` before running implement
- **Re-read on compact**: If using Claude Code and context compacts, ask the agent to re-read the plan
- **Commit frequently**: The implementation command commits after each milestone for easy rollback
