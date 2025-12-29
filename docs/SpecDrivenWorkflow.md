# Spec-Driven Workflow

A variation of the Research + Plan + Implement workflow that starts with a specification phase. This workflow ensures requirements are clear and complete before any code research or implementation begins.

## Workflow Commands

| Phase | Command | Description |
|-------|---------|-------------|
| **Spec** | [`/mr_create_spec`](../commands/mr_create_spec.md) | Interview the user to identify requirements, edge cases, and unclear areas; produce `spec.md` |
| **Research** | [`/mr_research_codebase`](../commands/mr_research_codebase.md) | Explore the codebase relevant to the spec, document patterns and components in `research.md` |
| **Plan** | [`/mr_plan`](../commands/mr_plan.md) | Create `plan.md` (Software Design Document + phases) and `plan_phase_N.md` files |
| **Implement** | [`/mr_implement_plan`](../commands/mr_implement_plan.md) | Implement the plan using TDD with `plan.md` as source of truth |
| **Validate** | [`/mr_validate_implementation`](../commands/mr_validate_implementation.md) | Validate implementation against spec/plan; run tests and coverage; document deviations |

## Flow Variations

Depending on task complexity, you can choose different paths through the workflow:

### Full Flow: Spec + Research + Plan + Implement

Use for complex features in large or unfamiliar codebases.

```
/mr_create_spec → /mr_research_codebase → /mr_plan → /mr_implement_plan
```

1. Create detailed specification with all requirements and edge cases
2. Research codebase to understand existing patterns and integration points
3. Create phased implementation plan with acceptance criteria
4. Implement following TDD with plan as source of truth

### Short Flow: Spec + Plan Mode + Implement

Use for medium complexity features where the codebase is somewhat familiar.

```
/mr_create_spec → [Plan Mode] → /mr_implement_plan
```

1. Create specification document
2. Use Claude Code's built-in Plan Mode (Shift+Tab) which performs codebase research automatically
3. Implement from the generated plan

Note: Codex doesn't have a dedicated plan mode, but typically starts with codebase research on its own.

### Straight Flow: Spec + Implement

Use for simple, well-defined features or when working in a familiar codebase.

```
/mr_create_spec → /mr_implement_plan
```

1. Create a thorough specification document
2. Implement directly from the spec (skipping explicit research and planning phases)

## Why Start with a Spec?

The specification phase adds value by:

- **Identifying unclear requirements** before any code is written
- **Discovering edge cases** through structured interviewing
- **Documenting non-functional requirements** (performance, security, reliability)
- **Establishing acceptance criteria** that are measurable and testable
- **Preserving context** from the original request including all links and references

A well-written spec serves as:
- Input to the research phase (keywords and entities to search for)
- Foundation for the implementation plan
- Acceptance criteria for validation
- Documentation for future reference

## Output Artifacts

Each phase produces a specific artifact:

| Phase | Output | Purpose |
|-------|--------|---------|
| Spec | `spec.md` | Requirements, acceptance criteria, edge cases |
| Research | `research.md` | Codebase mapping, patterns, integration points |
| Plan | `plan.md` + `plan_phase_N.md` | Design document, phased tasks, test strategy |
| Implement | Code + tests | Working implementation with verification |
| Validate | Validation report | Acceptance criteria checklist, coverage, deviations |

All artifacts are typically stored together in a feature directory under `docs/plans/`.
