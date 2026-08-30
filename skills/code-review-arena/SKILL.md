---
name: code-review-arena
description: Review a PR, a diff, or uncommitted changes with multiple independent reviewers on different harnesses and models, cross-judge the merged findings, and arbitrate the final verdict as the orchestrator. Use when asked to run a review arena, arena-review a PR, branch, or working tree, or review with multiple models or reviewers.
---

# Code review arena

Review one target with independent reviewers on different harnesses and models, merge their findings, cross-judge them, and arbitrate the verdict yourself. The deliverable is a validated findings report with routing, not fixes; nobody edits the code under review during the arena.

## Roster

| Id prefix | Harness | Model | Effort | Launch per |
|---|---|---|---|---|
| `claude-opus-N` | claude | opus (`--model opus`) | xhigh | review-with-claude |
| `codex-N` | codex | gpt-5.6 sol | xhigh | review-with-codex |
| `cursor-N` | cursor | kimi-k3 | max | review-with-cursor |
| `claude-fable-N` | claude | fable-5 | high | review-with-claude |

- Use Fable model only when user explicitely requested it. Otherwise, run only 3 reviewers (opus, codex, cursor).

- Pass effort explicitly, since a missing flag silently means default: `claude --effort xhigh`, `codex -c model_reasoning_effort=xhigh`, cursor in the model id.
- For claude reviewers pass the `opus` alias, never a bare id: `--model opus` resolves to the 1M-context build (`claude-opus-5[1m]`), while `--model opus-5` or `--model claude-opus-5` pins the 200k variant.
- One cmux workspace for the review, one tab per reviewer (`orchestrate-agents-in-cmux` skill). Outside cmux, use each skill's headless background form.

## Frame

Before any reviewer launches:

- Resolve the target: whatever the user named (a PR, a branch or diff range, uncommitted changes). Unspecified: the current branch's open PR (`gh pr view`); when there is none, ask the user what to review.
- Express the target as the diff the briefs name (`gh pr diff {n}`, `git diff {base}...{branch}`, or `git diff HEAD` for uncommitted work) and gather intent evidence: PR description, commit messages, linked issues, sibling code.
- Pick the tier. Standard (default): all four reviewers get the same general brief. Deep (large features, or when the user asks): each reviewer also gets one specialty lens derived from what the diff touches (security for auth or input handling, architecture for new module boundaries, data integrity for migrations or concurrency, else maintainability, test adequacy, observability). Every brief carries the shared core either way, so deep never lowers the correctness floor.
- Write per-reviewer brief files and report paths in a scratch directory outside the repo; briefs name absolute paths.

## Brief core

Follow review-with-codex for brief mechanics: the diff, the allowed checks, the no-edits rule, the production-path bar, the findings format. Every arena brief adds the intent-mismatch mandate:

> Report any mismatch between what the code does and what its author evidently intended (sibling idioms, docstrings, naming, commit history, domain semantics), even outside the task's scope. Do not fix it and do not drop it. Tag the finding `intent-mismatch` and cite the intent evidence.

Blind rule: no reviewer sees another's findings until its own report is written; briefs never mention other reviewers.

## Collect and merge

Supervise per the `orchestrate-agents-in-cmux` skill; verify from report files, never from screens or prose. When every report exists:

- Merge findings that share a root cause and keep every originating id (`found-by: claude-opus-2, cursor-5`). Convergence raises confidence, but reject nothing for being unique; a unique catch is why the third harness is there.
- Drop nothing yet. The merged doc is the cross-judge input.

## Cross-judge

Write each validation assignment to an addendum file, then send only its absolute path into the still-open reviewer session. Each addendum tells the reviewer to follow the validate-findings skill (installed under `~/.agents/skills`, readable by every harness):

- The codex session validates the claude and cursor findings.
- The claude opus-5 session validates the codex findings.
- No session validates its own findings; fable never validates.
- Write each rejection set to a rebuttal addendum and send only its path to the originating session. Allow one rebuttal, then close the debate.

## Final judgement

The orchestrator delivers the verdict, not a validator. Re-judge every finding, contested ones especially, on validate-findings' two axes (is it real, does it matter) with the task context the reviewers lack. Validator verdicts and rebuttals are evidence, not decisions. The orchestrator owns the outcome: slop in the final report, or a real bug rejected, is the orchestrator's failure.

## Report and route

Lead with the tally, then survivors ranked by severity, each with impact, how it occurs, proposed solution, `found-by`, and the verdict trail. Split survivors into two buckets:

- In-scope findings: fix on this branch.
- `intent-mismatch` survivors: route each to a dedicated behavior-fix PR (split-pr has the mechanics) with its intent evidence; the in-scope change pins current behavior with a test until that PR lands.
