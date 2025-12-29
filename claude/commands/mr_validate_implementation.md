---
description: Validate implementation vs plan/spec; run lint/tests/coverage; document deviations
---

# Validate Implementation

## Mission
Verify the implementation matches spec.md and plan.md, that acceptance criteria are satisfied, and that quality gates are met.

## Validation principles (enforce)
- Evidence-driven: report exact commands and results.
- Prefer non-interactive runs for CI compatibility.
- Coverage target: >80% for new/modified modules unless repo policy differs.
- If tests fail, you may attempt fixes at most **two times**; then stop and ask the user.

## Pre-validation checklist
1. Verify all open questions from spec.md were addressed during implementation
2. Check plan.md Decision Log for any deferred items that need validation
3. Read project standards (docs/standards/testing.md, code_quality.md) if they exist

## Steps
1) Read `plan.md` + `spec.md`; extract acceptance criteria and phase expectations.

2) Inspect repo changes:
   - List changed files (diff, git status)
   - Verify tests were added/modified for new code
   - Check that fixture scopes match what was planned

3) Run quality tools (as configured by repo):
   - Announce exact lint command, then run it
   - Announce exact test command, then run it
   - Run coverage command(s) and report results

4) Assess test quality:
   - Edge cases covered per spec/plan
   - No "shortcut" tests (missing assertions, brittle tests, etc.)
   - Test naming follows project conventions

5) Check spec compliance:
   - All acceptance criteria from spec.md are met
   - All open questions from spec.md were resolved
   - No scope creep (features not in spec)

6) Deviations handling:
   - If you find deviations from plan/spec, list them clearly
   - Ask the user to confirm acceptability (one question at a time)
   - Update plan.md Decision Log + Progress accordingly

## Output
Write validation report including:
- Scope validated (files, features)
- Commands run + results (key output lines)
- Acceptance criteria checklist (pass/fail for each)
- Coverage summary
- Deviations found + resolution status
- Any required updates to plan.md or docs

Keep chat concise and evidence-driven.
