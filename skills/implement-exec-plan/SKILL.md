---
name: implement-exec-plan
description: "Implement an executable plan.md by orchestrating implementer and adversarial-reviewer sub-agents, maintaining the plan as a living document. Use when asked to follow, execute, continue, resume, or implement an exec plan or plan.md, including updating progress, decisions, tests, and commits."
---

# Implement Executable Plan

Drive an Executable Plan (`plan.md`) to completion by orchestrating sub-agents, while keeping the plan accurate enough for another agent to resume from the plan and working tree alone.

## Required Reference

Read `../create-exec-plan/references/ExecPlanSpec.md` (the canonical spec, shared with the create-exec-plan skill) in full before starting. It defines the plan format and the living-document sections you must maintain. If the user points to a different plan specification, follow the explicitly requested source where it differs.

## Your Role: Orchestrator

The main session orchestrates; sub-agents do the implementation and review work. As orchestrator you:

- delegate implementation and quality control to sub-agents via the implement-review-loop skill;
- keep `plan.md` up to date — sub-agents never edit the plan;
- run milestone validation yourself and create the commits;
- resolve ambiguity and make decisions, recording them in the Decision Log.

You may implement a genuinely trivial milestone inline (a config tweak, a doc edit) instead of delegating.

## Workflow

1. Locate and read the plan.
   - Use the path the user supplied; otherwise look for `plan.md` in the current directory, `docs/plans/`, the repository root, and `docs/`.
   - Read the full plan, every document it lists as required reading, and the project standards it references (e.g., `docs/standards/` if named).

2. Resolve Open Questions first.
   - If the plan's `Open Questions` section is non-empty, get answers from the user before implementing, then move the answers into the plan's decided choices.

3. Execute milestones in order. For each milestone:

   a. Mark it in progress in `Progress` with a timestamp.

   b. **Implement and review via sub-agents.** Follow the implement-review-loop skill. The implementer's brief includes the plan path (instruct it to read the plan first), the milestone's goal and acceptance criteria, and relevant constraints and pattern references. Record dropped findings, overrules, and requirement escalations in the Decision Log.

   c. **Validate independently.** Run the milestone's validation commands yourself; do not rely solely on sub-agent reports. The milestone is complete only when validation passes and the acceptance criteria are met. You own the delivered feature: hold the work to a high quality bar, and accept nothing you would not ship yourself. If sub-agents cannot reach that bar after a reasonable number of rounds, take over and implement it yourself — delegation is a means, not the goal.

   d. **Update the plan.** Record progress (with timestamp and commit hash), any surprises with evidence, and any decisions with rationale. Save `plan.md` after every significant update, not just at milestone end.

   e. **Commit.** Commit the milestone unless higher-priority instructions forbid committing. Use Conventional Commits in imperative mood, stage only files intentionally changed for this milestone, and never include AI attribution footers.

4. Handle discoveries and course changes.
   - When reality contradicts the plan, record the evidence in `Surprises & Discoveries`, the course change in `Decision Log`, and revise the affected milestones — the plan must always describe the current truth, not the original guess.

5. Resolve ambiguity autonomously.
   - Do not ask the user for generic next steps. Make defensible decisions from the plan, source documents, and codebase, and record them in the Decision Log. Ask the user only when a true blocker cannot be resolved from local context.

6. Complete the plan.
   - Run the full validation suite required by the plan and repository.
   - Write an `Outcomes & Retrospective` entry comparing the result against the original purpose, noting gaps and follow-up work.
   - Ensure all living sections reflect the final state before reporting completion.
