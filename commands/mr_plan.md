---
description: Create plan.md (SDD + phases) and plan_phase_N.md docs from spec.md + research.md
---

# Create Implementation Plan

## Guiding principles to incorporate into the plan
- `plan.md` must start with a **Summary** section (2-3 paragraphs explaining why/what/phases overview)
- `plan.md` must include a **References** section linking to idea.md, spec.md and research.md with descriptions
- Phase doc references must use relative markdown links: `[plan_phase_N.md](plan_phase_N.md)` not file paths
- For any new fixtures/components, explicitly state the **scope** (session, module, function, etc.)
- For any configuration file changes, include the **exact syntax/format** to use
- For any new dependencies, include the **exact command** to add them (e.g., `uv add --dev package-name`)
- Include a global "Edge Cases" section in `plan.md` and per-phase "Edge Cases to Address" sections in each phase doc
- `plan.md` is the source of truth for tasks/status and phase checkpoints
- If the design requires changes to the tech stack or new production dependencies:
  - document it and ensure `tech-stack.md` is updated **before** implementation begins (if such file exists in the project dir)
- Each phase must include tests (no deferring testing to later phases)
- Never commit to git; the user handles commits
- Avoid placing test modules under fixture directories unless explicitly requested

## Mission
Produce:
- `plan.md` containing a **Software Design Document (SDD)** at the top (high-level design, not line-by-line code)
- A phased execution plan with acceptance criteria and tests per phase
- `plan_phase_<N>.md` detailed task breakdown per phase

## Pre-planning checklist
Before drafting the SDD, verify:
1. All open questions from spec.md are resolved (or ask the user to resolve them now)
2. New dependencies identified in research.md are documented as explicit tasks
3. CI/CD constraints from research.md are incorporated into the design
4. Existing patterns that DON'T apply are called out with alternatives

## Plan structure requirements
The `plan.md` must include (in order):
1. **Summary** - 2-3 paragraphs: why this work, what it delivers, phase overview
2. **References** - structured into 4 subsections:
   - **0.1 Specification (Always Read)**: spec.md — read before any implementation
   - **0.2 Phase Plans (Read Relevant Phase)**: plan_phase_N.md files
   - **0.3 Research (Read to Understand Codebase)**: research.md — existing patterns, component mapping
   - **0.4 Source Document (Read if Requested)**: idea.md — original problem analysis, source from which spec was produced
3. **SDD** - architecture, interfaces, algorithms
4. **Phase Breakdown** - with relative markdown links to phase docs
5. **Living Sections** - progress, decision log, surprises (with maintainer instructions, see below)

## Required process (interactive)
1) Read `spec.md` + `research.md`.
2) Draft the SDD:
   - architecture, data flow, file-level design
   - interfaces/signatures + types (with explicit scopes for fixtures/components)
   - pseudo-code for key algorithms
   - testing architecture (what tests, where, how)
   - note any tech stack impacts (and the `tech-stack.md` gate)
3) Propose a **high-level phase breakdown first** (Phase 1..N):
   - Phase Breakdown format in `plan.md`: use `### Phase N. <Name> (<status>)` headers and include goal, acceptance criteria, and plan doc link only (omit detailed test lists)
   - each phase is verifiable
   - each phase includes acceptance criteria + tests
   - phases should be decomposable into sequential tasks tracked in `plan.md`
   - Confirm each phase with the user before moving to the next phase details.
4) Present the design to the user in ~200-300 word sections, asking after each:
   "Does this look right so far? (yes/no + corrections)"
   - After asking the question, STOP and wait for the user response before continuing.
   - Do not draft the next section or write files until the user answers.
5) Phase approval workflow:
   - Present a phase summary and ask for approval/corrections.
   - If approved, write the phase plan file and notify the user with the specific path.
   - STOP and wait for the user to review the detailed phase doc and give the green-light before moving to the next phase.
6) After user approves phases:
   - Keep `plan.md` in sync with phase docs (SDD, testing architecture, edge cases, and phase summaries).
   - Do not draft later phase docs until the user confirms the prior phase.
   - write/update `plan.md` (next to `spec.md`)
   - write each `plan_phase_<N>.md`
   - ensure `plan.md` references each phase doc using relative markdown links

## Configuration and dependency conventions
- When a configuration file needs changes, show the exact syntax (e.g., INI variable substitution, TOML sections)
- When a new dependency is needed, specify the exact install command
- When creating fixtures, always specify scope (session/module/function) with rationale
- When referencing other plan docs, use relative markdown links: `[plan_phase_1.md](plan_phase_1.md)`

## Task tracking convention (must be planned)
In `plan.md` Progress/tasks:
- Use `[ ]` not started, `[~]` in progress, `[x]` done
- Tasks are executed sequentially unless the user explicitly approves parallelization.
- Completion lines should include timestamp + commit SHA when available.
- Phase task lists in each phase doc must use `[ ]` checkboxes for each task.

## Living Sections instructions
The Living Sections in `plan.md` must include the maintainer instructions from the template (`~/.claude/templates/plan_template.md`). These instructions guide future contributors on how to maintain the Decision Log, Progress, Surprises & Discoveries, and Outcomes sections. Do not remove these instructions from the final plan.

## Templates (required)
Use these templates as the starting structures:
- `~/.claude/templates/plan_template.md` -> for `plan.md`
- `~/.claude/templates/plan_phase_template.md` -> for each `plan_phase_<N>.md`

If a template file is missing, notify the user and stop. Only proceed after the user provides the template inline or creates the template file.

## Output shaping
- In chat: short updates + 200-300 word design chunks with confirmation prompts.
- In docs: structured headings, crisp bullets, signatures/pseudocode allowed, no full code.

Stop once docs are written and the user approves the plan direction.

---

**User's input:** $ARGUMENTS