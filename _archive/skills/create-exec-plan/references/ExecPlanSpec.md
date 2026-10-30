# Executable Plan Specification

This document defines the requirements for an Executable Plan ("ExecPlan"), a design document that a capable coding agent can follow to deliver a working, observable change.

Terminology:

- Executable Plan Specification (ExecPlanSpec.md): this document — the rules for writing and maintaining a plan.
- Executable Plan, or simply Plan (`plan.md`): a structured plan of work produced from the user's requirements according to this specification. It carries the requirements, milestones, and the running record of progress and decisions.

## Audience and Core Principle

Write for a capable coding agent (or engineer) who has the current working tree and this single plan file — and no memory of the conversation in which the plan was created. The reader can list, read, and search files, run the project, run tests, and spawn sub-agents. They do not need code tutoring, glossaries for common technical terms, or expected command transcripts.

**The plan documents the desired outcome, not the concrete steps to get there.** The implementer decides how to write the code; the plan tells them what must be true when they are done and why it matters.

The plan must be self-contained in exactly the things that cannot be re-derived from the repository:

- the requirements and their intent — why the work matters, ideally as user stories ("As a tenant admin, I can ... so that ..."),
- constraints and non-goals,
- decisions already made, with rationale,
- acceptance criteria for each milestone and for the change as a whole.

The plan must NOT contain what the implementer can produce or discover better at implementation time:

- pre-written code: snippets, diffs, function bodies, or class/interface definitions to paste in,
- prescriptive edit-by-edit sequences ("in file X, add line Y after line Z"),
- re-explanations of code that already exists in the repository.

References beat inclusions. Instead of pasting code or re-describing a subsystem, point at it: name an existing file that demonstrates the pattern to follow, a module that owns the behavior being changed, or a standards document that applies — each with one line saying why it is relevant. External URLs are acceptable with a short note on what is there; extract into the plan only the specific facts the implementer cannot get from the repository.

## Non-Negotiable Requirements

- Every Plan is a living document. It must be revised as progress is made, discoveries occur, and decisions are finalized, and every revision must keep it sufficient for a fresh agent to resume from the plan and working tree alone.
- Every Plan must target a demonstrably working behavior, not merely code changes that "meet a definition". Acceptance criteria are phrased as observable behavior, never as internal attributes ("after starting the server, `GET /health` returns HTTP 200" — not "a HealthCheck class exists").
- Every milestone must be independently implementable, testable, and acceptable. Testing and validation happen at the end of each milestone, never deferred to the final one.
- Every Plan resolves ambiguity itself. Requirements-level decisions are made in the plan (with rationale in the Decision Log) or listed in Open Questions for the user — never silently delegated to the implementer. Implementation-level choices belong to the implementer.
- Use repository-relative paths everywhere. Never machine-specific absolute paths (home directories, worktrees, temp dirs).

## Milestones

Split complex work into milestones that each deliver a verifiable increment. Each milestone states:

- **Goal** — a short paragraph: what exists at the end of this milestone that did not exist before, and how it moves the overall purpose forward.
- **Acceptance criteria** — a checklist of observable behaviors, including the scenarios and edge cases that tests must cover, described in prose (not as a list of test names or function signatures — the implementer decides how to organize the tests). Cover both positive and negative cases where the behavior is conditional.
- **Validation** — the exact commands to run (with working directory, when not the repo root) that prove the criteria are met.

Sizing guidance: a milestone should be one coherent review unit — small enough for a single implementer pass and an adversarial review, large enough to be independently demonstrable. Prefer additive changes that keep the suite green throughout; when a change is risky (migrations, destructive operations, wide refactors), the milestone must state the safety approach (backup, rollback path, or parallel implementation retired in a later milestone).

When requirements carry significant unknowns, it is encouraged to make the first milestone a spike or prototype that de-risks the decision — clearly labeled as such, with criteria for promoting or discarding it.

## Living Sections

Every Plan maintains these four sections. They are not optional, and keeping them current is part of implementing the plan:

- **Progress** — checkbox list of granular work items with timestamps and commit hashes. Every stopping point is recorded here, splitting partially done items into done/remaining so the actual state is always readable.
- **Surprises & Discoveries** — unexpected behavior, bugs, or insights found during implementation, each with concise evidence (test output is ideal). This is high-value context for every later agent; record surprises when they happen, not at the end.
- **Decision Log** — every requirements-level or course-changing decision, with rationale and date. It must be unambiguous why the plan changed, so a later reader never re-litigates a settled question.
- **Outcomes & Retrospective** — at completion (or abandonment): what was achieved versus the original purpose, what remains, lessons learned.

## Skeleton of a Good Executable Plan

```md
# <Short, action-oriented title>

This Executable Plan is a living document maintained according to the Executable Plan
Specification (see the create-exec-plan skill). The sections Progress, Surprises &
Discoveries, Decision Log, and Outcomes & Retrospective must be kept up to date.

## Purpose / Big Picture

Why this work matters and what someone can do after it that they could not before.
User stories where they fit. How to see the result working.

## Non-Goals

What this plan deliberately does not cover, so implementers do not drift into it.

## Context and Orientation

The current state relevant to this task: key modules and files by repository-relative
path, the patterns to follow (named example files), applicable standards documents,
and the validation commands used in this repository. Orientation, not a tutorial —
enough for the implementer to know where to look, not a re-explanation of the code.

## Constraints and Decided Choices

Hard constraints (compatibility, security, performance) and design decisions already
made with the user, each with a one-line rationale. Anything still open goes to
Open Questions instead.

## Milestones

### Milestone 1: <name>

Goal: ...

Acceptance criteria:
- [ ] <observable behavior>
- [ ] <scenario or edge case tests must cover, in prose>

Validation: <exact commands>

### Milestone 2: <name>
...

## Open Questions

Questions only the user can answer. Must be resolved (moved into Decided Choices or
Non-Goals) before implementation starts; empty is the goal state.

## Progress

- [x] (2026-01-15 13:00) Example completed step (commit: HASH).
- [ ] Example remaining step.

## Surprises & Discoveries

- Observation: ...
  Evidence: ...

## Decision Log

- Decision: ...
  Rationale: ...
  Date: ...

## Outcomes & Retrospective

(at completion)
```

The bar: a fresh, stateless agent reading the Plan top to bottom — with the working tree but no conversation history — knows what to build, what "done" means for each milestone, which questions are settled and why, and can prove the result works. OUTCOME-FOCUSED, SELF-CONTAINED IN REQUIREMENTS AND DECISIONS, VERIFIABLE AT EVERY MILESTONE.
