---
description: Implement the approved plan phases with TDD and plan.md as source of truth
---

# Implement Plan

## Guiding principles (enforce)
- `plan.md` is the source of truth: tasks/status/phase checkpoints live there.
- Tech stack is deliberate: if implementation requires new deps/tools or stack changes:
  - **STOP** and update `tech-stack.md` first (dated note), then proceed.
- Test-Driven Development for behavior changes:
  - Red (failing test) → Green (minimal code) → Refactor (optional)

## Pre-implementation checklist
Before starting any implementation:
1. Verify all open questions from spec.md are resolved
2. Verify new dependencies are installed (check plan.md Decision Log for install commands)
3. Check for and read project standards documents (see below)

## Project standards discovery
Check if the current project has coding/testing standards and read them:
1. Check for `docs/standards/testing.md` - if exists, read it to understand:
   - Test organization and naming conventions
   - Mocking and fixture patterns
   - Coverage requirements
   - Best practices specific to this project
2. Check for `docs/standards/code_styleguide.md` or `docs/standards/code_quality.md` - if exists, read it to understand:
   - Code formatting and style rules
   - Naming conventions
   - Documentation requirements
   - Linting configuration
3. Apply these standards strictly when writing code and tests

## First actions
1) Read `plan.md` and the targeted phase doc(s).
2) Read project standards documents (testing.md, code_styleguide.md) if they exist.
3) Identify the **next not-started task** in sequential order.
4) Before coding, edit `plan.md`:
   - mark that task `[ ] → [~]`
   - add a timestamp

## Per-task execution protocol (non-negotiable)
For the active task:
1) **Red (tests first)**
   - Add/modify unit tests to express acceptance criteria.
   - Run the smallest relevant test command.
   - Confirm tests fail (explicitly note "Red confirmed" in `plan.md` Progress if helpful).
2) **Green (minimal implementation)**
   - Implement the minimum code to pass tests.
   - Re-run tests; confirm pass.
3) **Refactor (optional)**
   - Clean up code/tests without changing behavior.
   - Re-run tests.
4) **Quality gates**
   - Run linters/formatters on modified scope (avoid mass reformatting existing files).
   - Check/estimate coverage using repo tooling; target >80% for new/changed modules.
5) **Update plan**
   - Update the task line in `plan.md` from `[~] → [x]` and append timestamp.

## Handling blocked tasks
If a task cannot be completed:
1. Document the blocker clearly in plan.md Surprises & Discoveries
2. Mark the task with `[!]` (blocked) instead of `[~]`
3. Ask the user for guidance before proceeding to the next task
4. Do NOT skip blocked tasks silently

## Phase completion checkpoint protocol
When finishing the final task in a phase:
1) Announce phase completion + start verification protocol.
2) Determine phase scope by locating previous phase checkpoint in `plan.md`.
3) List changed files since checkpoint.
4) Verify code files have corresponding tests; add missing tests following repo conventions.
5) Announce the exact test command, then run it.
6) If tests fail:
   - attempt to propose/fix at most **two times**,
   - if still failing, **STOP** and ask the user for guidance.
7) Propose a detailed manual verification plan (commands + expected outcomes) and ask the user:
   "Does this meet your expectations? yes/no + feedback"

## Living plan requirements (mandatory)
Maintain in `plan.md`:
- Progress (checkbox list with timestamps)
- Decision Log (why decisions were made)
- Surprises & Discoveries (evidence snippets, test output ideal)
- Outcomes & Retrospective (at major completion)

## User updates
- Only update the user when starting a new major task/phase, or when surprises force a plan change.
- Each update: 1-2 sentences, include concrete outcome.

End by telling the user what to run to verify (tests/lint/coverage).
