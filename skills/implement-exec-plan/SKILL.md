---
name: implement-exec-plan
description: "Implement and maintain an executable plan.md as a living document. Use when asked to follow, execute, continue, resume, or implement an exec plan or plan.md, including updating progress, decisions, tests, and commits."
---

# Implement Executable Plan

Follow an Executable Plan (`plan.md`) end to end while keeping it accurate enough for another agent to resume from the
plan alone.

## Required Reference

Read `references/ExecPlanSpec.md` from this skill directory in full before starting implementation. It defines how to
maintain the plan as a living document. If the user points to a different plan specification, read that too and follow
the explicitly requested source where it differs.

## Workflow

1. Read directly mentioned files first.
   - If the user mentions a plan path or related docs, read each file in full before proceeding.
   - Do not rely on partial reads for the plan or source documents.

2. Locate and read the plan.
   - If the user supplied a path, use that plan.
   - Otherwise look for `plan.md` in the current working directory, the repository root, `docs/`, and `.plan/`.
   - Read the full plan before making edits.

3. Read required source documents and standards.
   - If the plan has a `Source Documents` or `Required Reading` section, read every listed document in full.
   - Check for relevant project standards in locations such as `docs/standards/`, `docs/`, or similarly named
     directories. Read style, testing, database, or domain-specific guidance that applies to the plan.

4. Execute milestones in order.
   - Before starting a task, update `Progress` with an in-progress entry and timestamp.
   - Follow the plan's concrete steps unless repository evidence proves a better route is required.
   - When reality differs from the plan, update `Surprises & Discoveries` with evidence and add a `Decision Log` entry
     explaining the course change.
   - Save `plan.md` after every significant progress, discovery, decision, or validation update.

5. Validate before marking work complete.
   - Run the validation commands specified in the plan after each milestone or major task.
   - Run any additional relevant tests required by the repository or affected code path.
   - A task is complete only when tests pass and the plan's acceptance criteria are satisfied.
   - Record validation results in `Progress` or `Outcomes & Retrospective`.

6. Commit focused milestones when allowed.
   - Commit after each milestone or major task unless higher-priority user or system instructions forbid committing.
   - Use Conventional Commits, imperative mood, and a message that explains why the change was needed.
   - Stage only files intentionally changed for the current task.
   - Do not commit unrelated files, untracked plan/spec documents unless already tracked, or AI attribution footers.

7. Resolve ambiguity autonomously.
   - Do not ask the user for generic next steps.
   - Make defensible decisions from the plan, source documents, and codebase, then record them in `Decision Log`.
   - Ask the user only when a true blocker cannot be resolved from local context.

8. Complete the plan.
   - Run the full validation suite required by the plan and repository.
   - Write a comprehensive `Outcomes & Retrospective` entry comparing the result against the original purpose.
   - Note remaining gaps or follow-up work.
   - Ensure `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` all reflect the
     final state before reporting completion.
