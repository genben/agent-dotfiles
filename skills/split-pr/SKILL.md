---
name: split-pr
description: Split unrelated changes out of a feature branch into separate PRs against the base branch, review and merge them, then back-merge the base to denoise the original PR. Use when a branch has accumulated drive-by fixes that create review noise, or when asked to split a PR/branch, extract unrelated fixes, or denoise a PR diff.
---

# Split PR

Extract unrelated changes from a feature branch into independent, reviewable PRs against the base branch, merge them, then merge the base back into the feature branch so its diff shrinks to only the feature work.

## Role: you are the orchestrator

You manage subagents (analyst, implementer, reviewer, merger). You do not do the extraction, review, or merge work yourself. You are responsible for the results:

- **Verify claims, not summaries.** A subagent saying "tests pass" is not evidence. Require and check the actual test-run tail, the actual PR diff file list, the actual review verdict.
- **High quality of work is the priority. Do not accept a half-done job.** When output misses an acceptance criterion, send it back for redo, naming the specific unmet criterion — never "try again".
- **Take over yourself only exceptionally**, after a subagent has failed the same criterion twice.
- Launch independent subagents in parallel (one Agent message with multiple tool uses). Honor any user or memory instruction about the agent model (for example, a memory saying to pass a specific `model` on every Agent call).

## Inputs (resolve before Phase 1)

Resolve these from the repository's CLAUDE.md; ask the user for whatever is missing:

- **Base branch** — usually `master` or `main` (confirm with `gh repo view --json defaultBranchRef`).
- **Worktree init command** — the repo-specific setup for a fresh worktree (in miarecweb: `make setup`).
- **Full test suite command** and **lint command** for the repo.
- **Parallelism**: run extracted-PR pipelines and their full test suites truly in parallel. Serialize test runs only if a run fails from resource contention (DB/port/CPU exhaustion — rerun serially to confirm before treating a failure as real), or if the user explicitly instructed serialization before the workflow started.

## Progress file (resumability)

Keep all workflow state in the **original worktree** at `docs/plans/{branch}/split-pr-progress.md` (create the directory if needed). This file is the single source of truth: if the session is dropped, a new session resumes by reading it and continuing from the first incomplete step.

Rules:

- Create it at the start of Phase 1; update it at **every state transition** (grouping approved, worktree created, tests green, PR opened, review round done, PR merged, back-merge done) — not in batches at phase ends.
- Record concrete identifiers: commit SHAs per group, worktree paths, branch names, PR numbers/URLs, test-run results, review round counts, resolved conflicts.
- Commit the progress file to the original branch when the workflow completes (per the repo's plan-docs convention); while in flight, keeping it uncommitted in the worktree is fine.
- **On invocation, always check for an existing progress file first.** If one exists, resume — do not restart Phase 1.

Template:

```markdown
# split-pr progress — {branch}

Base: {base}  Started: {date}  Status: {phase and step}

## Approved grouping (Checkpoint 1: {date/pending})
### PR 1 — {title}
- Branch: {name}  Worktree: {path}  PR: {#/url or pending}
- Commits (cherry-pick order): {sha — subject, per line; mark commits needing a split and what stays behind}
- Files: {list}
- State: pending | worktree-created | extracted | tests-green | pr-open | in-review (round N) | review-clean | merged
- Notes: {conflicts hit, redo reasons, deviations}

## Stays on the original branch
- {sha — reason it is entangled}

## Checkpoint 2 (ready for human review): {date/pending}
## Merge order and results
## Back-merge (Phase 4)
- Conflicts resolved: … Tests: … Review: … Pushed: {sha}
```

## Phase 1 — Analyze and propose

Dispatch an **analyst subagent** (read-only) with the base branch, feature branch, and this brief:

> Map every commit on `{branch}` not in `{base}` (`git log {base}..HEAD --oneline`). Classify each as feature work or an unrelated change. For unrelated changes, form independent groups that would each make a coherent PR. For every commit with a generic-looking scope, check **entanglement**: does it modify files created on this branch, or code the feature commits introduced (`git log {base}..HEAD -- <file>` per touched file)? Entangled commits stay on the branch — flag them explicitly with the reason. For each group report: commits in cherry-pick order, files touched, overlaps with other groups (shared files → merge-order dependency), expected cherry-pick conflicts, and any commit that needs a **split** (part general fix, part branch-only files) with the exact hunk division and whether a replacement test must be written against base-existing entry points. Return the raw evidence (file→commit mapping), not just conclusions.

Verify the analysis yourself on the two failure modes that matter: spot-check the entanglement calls, and confirm the union of groups + stays-behind + feature commits covers every commit.

Write the proposal into the progress file, then **present it to the human**: groups, commits, files, split commits, what stays behind and why, proposed merge order.

**Checkpoint 1 — stop. Create nothing until the human approves the grouping.** Record approval (and any adjustments) in the progress file.

## Phase 2 — Extract, verify, review (parallel per PR)

For each approved group, dispatch an **implementer subagent** with this pipeline (all implementers run in parallel, each in its own worktree):

1. Create a worktree and branch off the up-to-date base: `git worktree add <path> -b <branch-name> {base}`. Then run the repo's worktree init command.
2. Cherry-pick the group's commits in the approved order. For a split commit: apply only the approved hunks (`git checkout {sha} -- <files>` or apply a filtered diff), write the replacement test against a base-existing entry point, and keep the commit message's relevant content.
3. Run lint and the **full test suite**. Fix legitimate failures; never delete or skip tests to get green.
4. Push, open the PR against the base with `gh pr create`, then run the `describe-pr` skill to produce its description.
5. Report back: worktree path, branch, PR URL, tail of the test run, `gh pr diff --name-only` output.

**Acceptance criteria you enforce before the review step:**

- PR diff file list matches the approved group exactly — nothing smuggled in, nothing missing.
- Full suite green in that worktree (see the actual output tail; on suspected resource contention, rerun serially before judging).
- Commits preserved individually (no squashing during extraction), messages intact.

Then dispatch an **adversarial reviewer subagent** per PR: review the PR diff for correctness, dropped context from the original branch (a cherry-pick that silently depends on branch-only code), test quality per the repo's testing standards, and scope creep. The reviewer must try to find problems, not bless the work. Route findings back to the same implementer; loop until the reviewer has no remaining findings. Record each round in the progress file.

When all PRs are review-clean: update the progress file and **report to the human** — one line per PR (URL, scope, test result, review rounds) plus anything that deviated from the approved plan.

**Checkpoint 2 — stop. The human does the final review of the PRs and approves the merge set.**

## Phase 3 — Merge serially

Merge the approved PRs one at a time, in the approved dependency order:

- `gh pr merge <n> --merge` — **merge commit, never squash** (preserving the original commits lets the Phase 4 back-merge resolve cherry-picked changes as identical). **Do not delete the branch on GitHub** (no `--delete-branch`).
- After each merge, check whether the next PR still merges cleanly (`gh pr view <n> --json mergeable`). If not, dispatch a **merger subagent**: update that PR's branch on the new base, resolve conflicts, rerun the full suite, push. Verify green before merging it.
- Record each merge (merge commit SHA) in the progress file.

## Phase 4 — Back-merge and denoise

Dispatch a **merger subagent** in the original worktree:

1. Merge the updated base into the feature branch (`git merge {base}`), resolve conflicts. Cherry-picked commits should resolve as identical changes; investigate anything that does not — it usually means an extraction diverged from the branch version.
2. Run the full test suite; fix legitimate fallout.
3. Push.

Then dispatch an **adversarial reviewer** on the reduced diff (`{base}...HEAD`) — this is the final pre-merge review of the feature PR itself.

**Denoise the PR description too.** The original PR's description still covers the extracted changes. Rerun the `describe-pr` skill against the reduced diff and update the description on GitHub (`gh pr edit`); where mentioning the split adds context, link the extracted PRs. If the repo keeps PR description files (for example `docs/prs/`), regenerate the original PR's file the same way and commit it alongside the progress file.

Finish the progress file (final diff stat before/after, review verdict) and commit it. **Report to the human**: diff size reduction, test results, review outcome. The human approves and merges the original PR.

## Redo policy (applies in every phase)

When rejecting subagent output, the redo message must contain: the specific acceptance criterion missed, the evidence (test output, diff line, review finding), and what "done" looks like. After two failed redos on the same criterion, take over that step yourself and note the takeover in the progress file.
