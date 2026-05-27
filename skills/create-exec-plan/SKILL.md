---
name: create-exec-plan
description: "Create self-contained executable plan.md documents from requirements, tickets, specs, or feature requests. Use when asked to create, draft, design, or review an exec plan, execution plan, plan.md, or implementation plan before coding."
---

# Create Executable Plan

Create an Executable Plan (`plan.md`) that a novice coding agent can follow to deliver a working, observable
change from the user's requirements.

## Required Reference

Read `references/ExecPlanSpec.md` from this skill directory in full before writing the plan. Follow its skeleton and
requirements exactly. If the repository also has a plan specification, read both and prefer the user's explicitly
requested source when they conflict.

## Workflow

1. Read directly mentioned files first.
   - If the user mentions tickets, docs, specs, JSON, or related files, read each file in full before proceeding.
   - Extract requirements, constraints, acceptance criteria, and source-document context before drafting anything.

2. Gather enough requirements.
   - If the user has not provided requirements, ask what they want to do and probe for purpose, expected behavior,
     acceptance criteria, constraints, and any required source documents.
   - If requirements are present, summarize the key goals and ask only critical clarifying questions. Prefer numbered
     questions with lettered options when that makes the tradeoffs clearer.

3. Research the repository.
   - Explore relevant files, modules, tests, and existing patterns before writing the plan.
   - Identify affected ownership boundaries, conventions, dependencies, and validation commands.
   - Keep notes focused on information the future implementer needs to succeed without prior context.

4. Draft the plan incrementally.
   - Use the `ExecPlanSpec.md` skeleton and keep the plan self-contained, novice-guiding, and outcome-focused.
   - Present the plan to the user in 200-300 word chunks for approval.
   - After each chunk, ask exactly: `Does this look right so far? (yes/no + corrections)`
   - Stop completely after asking. Do not draft the next section until the user explicitly approves.
   - If the user requests corrections, apply them, show only the changed portion, and ask again.

5. Prefer intent over exact implementation code.
   - Use pseudocode for algorithms and behavior.
   - Include exact code only for critical interfaces, signatures, tiny examples, or commands where precision matters.
   - Include a `Source Documents (Required Reading)` section near the top when the user supplied spec files or docs.

6. Save the approved plan.
   - After all chunks are approved, assemble the full plan as `plan.md`.
   - Save it beside the primary referenced source file when there is one; otherwise save it at the repository root.
   - If several source files from different directories are equally primary, choose the repository root and note why.

7. Stop after plan creation.
   - Tell the user where the plan was saved and summarize the key milestones.
   - Do not implement the plan.
   - End with this instruction adapted to the actual path: `The plan has been saved to [path]. Please review the
     complete document. When you're ready to implement, use $implement-exec-plan.`

## Plan Quality Checklist

- Explain the user's purpose and observable behavior first.
- Define repository context with exact paths and plain-language terms.
- Include milestones, concrete steps, validation, acceptance, idempotence, recovery, artifacts, and dependencies.
- Initialize `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` sections.
- State exact commands from the correct working directory and describe expected results.
- Make the plan safe to resume from only the `plan.md` file and current working tree.
