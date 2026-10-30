---
name: create-exec-plan
description: "Create a self-contained executable plan.md for complex, multi-milestone work. Use when the user explicitly asks to create, draft, or review an exec plan, execution plan, or plan.md, or when the work is complex enough to justify milestone-based planning with sub-agent orchestration. Not for simple one-off implementation tasks, even when the user says 'plan' or 'implement'."
---

# Create Executable Plan

Create an Executable Plan (`plan.md`) that documents the desired outcome, milestones, and acceptance criteria well enough that a fresh agent can implement the work from the plan and working tree alone.

## When to Use — and When Not To

Use this skill only for complex work: multiple milestones, several subsystems touched, significant unknowns, or an explicit user request for an exec plan.

Do not use it for simple one-off tasks, even if the user says "plan" or "implement" — a task one agent can finish in a single sitting does not need an ExecPlan. If invoked for such a task, say the work is too small to justify an exec plan and offer to just do it.

## Required Reference

Read `references/ExecPlanSpec.md` from this skill directory in full before writing the plan. It defines what belongs in a plan (outcomes, acceptance criteria, decisions) and what does not (pre-written code, step-by-step edit sequences). If the repository also has its own plan specification, read both and prefer the user's explicitly requested source when they conflict.

## Workflow

1. Read directly mentioned files first.
   - If the user mentions tickets, docs, specs, or related files, read each in full before proceeding.
   - Extract requirements, constraints, acceptance criteria, and context before drafting anything.

2. Clarify requirements upfront, in one batch.
   - If requirements are missing or ambiguous at the level of *what to build* (purpose, expected behavior, scope boundaries, constraints), ask all clarifying questions now, in a single round. Prefer numbered questions with lettered options when that makes tradeoffs clearer.
   - Do not ask about implementation details the implementer can decide later.
   - If the requirements are already clear, skip the questions.

3. Research the repository.
   - Identify affected modules, ownership boundaries, existing patterns worth referencing, applicable standards docs, and validation commands.
   - When several distinct areas are involved, fan out parallel research sub-agents (Explore agents) and consolidate their findings; research only what the plan needs to reference, not everything.

4. Write the complete plan in one pass.
   - Follow the ExecPlanSpec skeleton. No incremental chunk-by-chunk approval — produce the full document so the user can review it in one read.
   - Describe outcomes and acceptance criteria, not code. Reference existing files as patterns instead of pasting snippets.
   - Split the work into milestones that are each independently implementable and verifiable, with validation commands per milestone.
   - Put anything only the user can decide into `Open Questions`; everything else, decide in the plan and record the rationale.

5. Save the plan.
   - If the repository has a `docs/plans/` directory, save to `docs/plans/<branch-name>/plan.md` (create the subdirectory). Otherwise save `plan.md` at the repository root.
   - Use repository-relative paths throughout the plan; never machine-specific absolute paths.

6. Stop after plan creation.
   - Report where the plan was saved, summarize the milestones, and list any Open Questions that need answers.
   - Do not implement the plan.
   - End with: `The plan has been saved to [path]. Please review the complete document. When you're ready to implement, use the implement-exec-plan skill.`

## Plan Quality Checklist

- Purpose and user stories come first; acceptance criteria are observable behavior, not internal attributes.
- Every milestone is independently testable with its own validation commands; testing is never deferred to the last milestone.
- Non-Goals are stated; Open Questions is empty or explicitly awaiting the user.
- No pre-written code or edit-by-edit instructions; existing patterns and docs are referenced by path with a line on why they matter.
- The living sections (`Progress`, `Surprises & Discoveries`, `Decision Log`, `Outcomes & Retrospective`) are initialized.
- A fresh agent could implement from only the plan and the working tree.
