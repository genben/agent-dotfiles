# Archived Commands

The following commands, agents, scripts, and templates have been archived in `_archive/`. They are not installed by the installer. If needed, they can be migrated to skills.

## Workflows

### Research + Plan + Implement (HumanLayer)

A structured workflow for tackling complex tasks in large codebases, inspired by [HumanLayer](https://github.com/humanlayer/humanlayer). See [HumanLayerWorkflow.md](HumanLayerWorkflow.md).

| Command | Description |
|---------|-------------|
| `/hl_research_codebase` | Research the codebase using parallel sub-agents |
| `/hl_create_plan` | Create detailed implementation plans |
| `/hl_implement_plan` | Execute plans with verification |
| `/hl_create_handoff` | Create handoff document for session transfer |
| `/hl_resume_handoff` | Resume work from a handoff document |
| `/hl_report_plan_progress` | Save progress to the plan document |
| `/hl_validate_plan` | Validate implementation against the plan |

### Spec-Driven Workflow

A variation that starts with a specification phase to clarify requirements before research. See [SpecDrivenWorkflow.md](SpecDrivenWorkflow.md).

| Command | Description |
|---------|-------------|
| `/mr_create_spec` | Interview user to identify requirements and edge cases; produce `spec.md` |
| `/mr_research_codebase` | Research codebase relevant to the spec; produce `research.md` |
| `/mr_plan` | Create `plan.md` and `plan_phase_N.md` from spec + research |
| `/mr_implement_plan` | Implement using TDD with plan as source of truth |
| `/mr_validate_implementation` | Validate implementation against spec/plan; run tests and coverage |

**Flow variations** (depending on task complexity):
- **Full**: Spec → Research → Plan → Implement
- **Short**: Spec → Plan Mode (Shift+Tab in Claude Code) → Implement
- **Straight**: Spec → Implement (for simple, well-defined features)

### Executable Plan Workflow

A simplified two-step workflow combining research and planning into one phase. Inspired by [OpenAI Codex Execution Plans](https://cookbook.openai.com/articles/codex_exec_plans) and Aaron Friel's talk [Shipping with Codex](https://www.youtube.com/watch?v=Gr41tYOzE20&t=770s). See [ExecutablePlanWorkflow.md](ExecutablePlanWorkflow.md).

| Command | Description |
|---------|-------------|
| `/ep_create_exec_plan` | Analyze spec, research codebase, and create executable plan |
| `/ep_implement_exec_plan` | Implement autonomously, maintaining the plan as a living document |

## Helper Commands

| Command | Description |
|---------|-------------|
| `/mr_commit` | Create git commits with user approval (no Claude attribution) |
| `/mr_handoff` | Create handoff document for session transfer |
| `/mr_resume_handoff` | Resume work from a handoff document |
| `/mr_describe_pr` | Generate PR descriptions from repository templates |
| `/mr_extract_learnings` | Extract learnings from current session |
| `/mr_learnings_from_commits` | Extract learnings from commit history |

## Sub-Agents

| Agent | Description |
|-------|-------------|
| `codebase-analyzer` | Analyzes codebase implementation details |
| `codebase-locator` | Locates files and components relevant to a task |
| `codebase-pattern-finder` | Finds similar implementations and usage patterns |
| `docs-analyzer` | Deep dive research on documentation topics |
| `docs-locator` | Discovers relevant documents in docs/ directory |
| `web-search-researcher` | Researches questions using web search |

## Templates

| Template | Description |
|----------|-------------|
| `spec_template.md` | Specification document template |
| `research_template.md` | Research document template |
| `plan_template.md` | Implementation plan template |
| `plan_phase_template.md` | Plan phase template |
| `ExecPlans.md` | Executable plan template |
| `ExecPlanSpec.md` | Executable plan spec template |

## Scripts

| Script | Description |
|--------|-------------|
| `spec_metadata.sh` | Helper for spec metadata extraction |
