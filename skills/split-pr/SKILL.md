---
name: split-pr
description: Split unrelated changes out of a feature branch into separate PRs against the base, merge them, then back-merge to denoise the original PR. Use when asked to split a PR or branch, extract unrelated fixes, or denoise a PR diff.
---

# Split PR

Extract unrelated changes from a feature branch into independent PRs against the base branch, merge them, then merge the base back so the feature diff shrinks to only the feature work.

## Role: you are the orchestrator

You manage subagents (analyst, implementer, reviewers, merger); you never do the extraction, review, or merge work yourself.

- **Verify claims, not summaries.** Require the actual test-run tail, PR diff file list, and review verdict, and check them.
- **Reject half-done work.** Name the unmet acceptance criterion in the redo message; never "try again".
- **Take over a step** only after a subagent has failed the same criterion twice.
- Launch independent subagents in parallel. Honor any user or memory instruction about the agent model.
- Subagents run as their own `claude` session in a cmux tab inside cmux (per the `orchestrate-agents-in-cmux` skill), in-process through the Agent tool everywhere else. Briefs, acceptance criteria, and the redo policy are identical either way.
- **Messages carry findings, not essays.** State the finding, the evidence, and what "done" looks like; cut context-setting and restatement.

## Worktree ownership (every agent, every phase)

**An agent writes only in the worktree it owns.** State it in every brief.

- Writable: its own worktree plus its one report file under `docs/plans/{branch}/split-pr/`. Nothing else.
- No commit, checkout, reset, revert, rebase, stash, or `git config` on another branch, not even to restore byte-identity.
- Anything that should change elsewhere goes in its report and a message to you; the owning agent applies it.

## Inputs (resolve before Phase 1)

Resolve from the repository's CLAUDE.md; ask the user for what is missing:

- **Base branch** (confirm with `gh repo view --json defaultBranchRef`).
- **Worktree init command** (in miarecweb: `make setup`).
- **Full test suite command** and **lint command**.
- **Parallelism**: run extracted-PR pipelines and their full suites in parallel. Serialize only when a failure looks like resource contention (rerun the failures serially after sibling runs drain before treating them as real) or the user instructed serialization up front. A suite is green only on the tail of a clean run, never a contention-polluted one.

## Progress file (resumability)

Keep all workflow state in the **original worktree** at `docs/plans/{branch}/split-pr-progress.md`. It is the single source of truth: a new session resumes by reading it and continuing from the first incomplete step.

- **On invocation, check for an existing progress file first.** If it exists, resume; do not restart Phase 1.
- Create it at the start of Phase 1; update it at every state transition, not in batches at phase ends.
- Record concrete identifiers: commit SHAs per group, worktree paths, branch names, PR numbers and URLs, test results, review rounds, resolved conflicts.
- **Never commit the workflow state.** With the progress file, create `docs/plans/{branch}/.gitignore` containing exactly:

  ```
  split-pr-progress.md
  split-pr/
  ```

  Progress, briefs, reports, and review files are session state; they stay out of every commit, including the final one. Commit the `.gitignore` itself only if the plan directory holds committed documents.

**Append-only, one entry per event**, in this shape. Never rewrite an earlier entry; stable line numbers let agents cite `split-pr-progress.md:120-140` instead of re-pasting. Omit sections that do not apply.

```markdown
## 2026-08-23 11:22 — PR #792 round 2
### Changes
- c85efe8a4 optgroup test takes db_session (fixes claude-r2-1)
### Discoveries & Surprises
- criterion 3 unsatisfiable: pytest prints dots, so grep of own test file is 0 on every green run
### Decisions
- codex-r2-4 dropped: E501 ignored at pyproject.toml:548, per-file counts unchanged vs master
```

The file opens with a header block, the only part edited in place (it is the resume pointer):

```markdown
# split-pr progress — {branch}
Base: {base}   Started: {date}   Mode: cmux | in-process   cmux group: {ref, cmux mode only}
Status: {phase and step}
PR {#} {branch} | {worktree} | {cmux workspace + agent names} | state: pending | worktree-created | extracted | tests-green | pr-open | in-review (round N) | review-clean | merged
Stays on the original branch: {sha — reason entangled, per line}
```

Record in the entries, as they happen: the approved grouping and cherry-pick order per PR, splits and what stays behind, conflicts, redo reasons, deliberate divergences the Phase 4 back-merge must expect, each finding as `id — author — agreed/unique — verdict — withdrawn/insisted — your decision`, checkpoint approvals, merge SHAs, and the back-merge result.

## Running inside cmux

Detect the mode once, at the start of Phase 2, and record it in the progress file (detection command, workspace, tab, agent-launch, status, and checklist mechanics all live in the **`orchestrate-agents-in-cmux` skill**; follow it). Outside cmux, run subagents in-process.

Split-pr specifics on top of that skill:

- One group per split, named `split-pr: {branch}`; record the group and anchor refs in the progress file.
- One workspace per extracted PR, named after the PR branch only (cmux shows the PR link itself). Create the worktree yourself first (`git worktree add {worktree} -b {pr-branch} {base}`) so the workspace has a directory to open; the implementer starts at the init command. Record `workspace_ref` and the workspace UUID in the progress file.
- One tab per subagent, named `implementer`, `reviewer`, `codex reviewer`, `merger`; the implementer rides the workspace's first tab. Agent names: `{pr-branch}-{role}`.
- Briefs live under `docs/plans/{branch}/split-pr/briefs/`; every brief requires the report at `docs/plans/{branch}/split-pr/{pr-branch}.{role}.md` in the original worktree: PR URL, commits, file list, lint result, test command with exit code and output tail, findings. Verify from that report and your own `gh pr diff --name-only` and `gh pr view`.
- Checklist, written once at workspace creation: `create worktree` · `cherry-pick commits` · `lint + full tests` · `push + open PR` · `describe PR` · `review (claude)` · `review (codex)` · `cross-validate findings` · `fix findings` · `human review` · `merge` · `back-merge + cleanup`.
- Status lanes: `todo` while queued, `working` while extracting, testing, or fixing, `review` during review rounds, `needs-attention` only for "stopped until a human acts", `done` once merged.

## Supervising the agents

Check every running agent at least every five minutes. In-process subagents notify you; supervise tab sessions per the `orchestrate-agents-in-cmux` skill (watchdog heartbeat, per-tick checks, restart in a new tab). Record every intervention and restart in the progress file; a restarted agent's brief states what's done (from the progress file and worktree git state) and what remains.

## Adversarial review with two reviewers

Every extracted PR is reviewed twice, independently: a **claude reviewer** and a **codex reviewer**. Neither may read the other's findings before writing its own; cross-validation is the only channel between them. Then dedupe, cross-validate, take rebuttals, adjudicate.

`{plan-dir}` is `docs/plans/{branch}/split-pr/`; every file this protocol produces lives there. If `codex` isn't on PATH, tell the human, record it, and continue with the claude reviewer alone.

### Shared findings format

Both reviewers write plain Markdown, one `##` block per finding, to `{plan-dir}/{pr-branch}.claude-review.md` and `{plan-dir}/{pr-branch}.codex-review.md`:

```markdown
## claude-3 — Export query drops the tenant filter
- severity: high
- category: correctness
- file: miarecweb/views/export.py:142
- evidence: `uv run pytest miarecweb/tests/functional_tests/test_export.py::test_scope` fails on this branch and passes on {base}
- detail: …
- suggested fix: …
```

Later stages refer to findings by id (`claude-N`, `codex-N`). Omit fields that don't apply.

Judge a report by its ids, evidence, and actionability; queue a correction when it falls short.

### Running the two reviewers

Launch both at once, per PR, on the same brief: review `git diff {base}...{pr-branch}` for correctness, context dropped by a cherry-pick that silently depended on branch-only code, test quality against the repo's testing standards, and scope creep. They hunt for problems, not bless the work.

Reviewers may run the suite, linters, type checker, any check in the repo's CLAUDE.md, and throwaway probes. Neither may change the PR: no edits to tracked files, no commits, no pushes; state that in the brief.

Give every brief a shared preamble (allowed commands, prohibitions, review dimensions, id prefix) and a per-PR section naming what to attack in that diff. A generic brief returns generic findings.

- **claude reviewer**: in cmux, a new tab named `reviewer`; otherwise an in-process subagent. Writes `{plan-dir}/{pr-branch}.claude-review.md`.
- **codex reviewer**: run it per the review-with-codex skill; one session carries review, validation, and rebuttal. In cmux, the interactive TUI in a new tab named `codex reviewer`; outside cmux, the non-interactive form in the background. Report: `{plan-dir}/{pr-branch}.codex-review.md`; brief: `{plan-dir}/briefs/{pr-branch}.codex-review.md`; marker line: `split-pr {branch} {pr-branch} codex-reviewer`. Record the thread id in the progress file.

### Dedupe

When both findings files exist, dispatch a **dedup subagent** (in-process) with both files: match findings, never judge them. Two findings are the same when they name the same defect at the same place, however worded; two defects in one file are not duplicates. It writes `{plan-dir}/{pr-branch}.dedup.md`:

```markdown
## agreed
- claude-1 = codex-3 — Export query drops the tenant filter

## unique to claude
- claude-2 — Replacement test asserts on the mock, not the database

## unique to codex
- codex-1 — Migration lacks a downgrade path
```

### Cross-validation

Each reviewer judges the other's unique findings, accept or reject. A validator may run the same checks the reviewers ran; reproducing, or failing to reproduce, a defect is the strongest evidence.

Instruct the validator to follow the validate-findings skill: reject any finding that is not real or does not matter.

```markdown
## codex-2 — reject
- reason: the guard it claims is missing runs in the decorator two frames up
- evidence: `rg "require_tenant" miarecweb/views/export.py` and the passing test it points at
```

- **codex validates `unique to claude`**: `codex queue --thread {thread-id}` into the same session, writing `{plan-dir}/{pr-branch}.codex-validation.md`. Outside cmux, a fresh `codex exec` with `-o` at that path.
- **claude validates `unique to codex`**: `SendMessage` to the claude reviewer session, which still holds the diff. It writes `{plan-dir}/{pr-branch}.claude-validation.md`.

### Rebuttal

Send every rejection back to the finding's author, which withdraws or insists:

```markdown
## claude-3 — insist
- argument: the decorator it names runs only on the HTML view; the export endpoint is registered separately
```

- **claude author**: `SendMessage` to the same reviewer session → `{pr-branch}.claude-rebuttal.md`.
- **codex author**: `codex queue` into the same codex session → `{pr-branch}.codex-rebuttal.md`. Outside cmux, a fresh `codex exec` carrying both its original findings and the rejections.

### Adjudicate

Decide on the evidence, not by counting votes:

- **Agreed by both**: route to the implementer.
- **Unique, accepted by the other reviewer**: route to the implementer.
- **Unique, rejected, then withdrawn**: drop; record it was raised and withdrawn.
- **Unique, rejected, then insisted**: read the code yourself and settle it. If it stays unsettled, keep it; the implementer fixes it or explains in writing why it isn't a defect.

**You own the quality of the outcome, and quality includes what does NOT get written.** Acceptance is necessary to route a finding, never sufficient; re-apply the validate-findings gates yourself before anything reaches the implementer:

- A finding becomes a fix only when it names a production entry point and an input that reaches the defect today. A probe that constructs the failing input proves the defect real, not important; document-or-drop.
- Reviewers always return something. For a low-severity finding, ask what breaks for a real user if it ships unfixed; when the answer is nothing, drop it and record why.
- Rounds drift theoretical: when a round's survivors are only pathological-input polish, end the loop. Two clean-enough rounds beat five rounds of hardening nobody asked for.

Record the trail for every finding in the progress file, then send the implementer one consolidated list. After it reports back, rerun the protocol on the new diff. The loop ends on a round where nothing survives adjudication.

State the production-path bar in every reviewer brief so reviewers self-filter: a finding names the production entry point and the input that reaches the defect, or labels itself theoretical.

## Phase 1: Analyze and propose

Dispatch an **analyst subagent** (read-only) with the base branch, feature branch, and this brief:

> Map every commit on `{branch}` not in `{base}` (`git log {base}..HEAD --oneline`). Classify each as feature work or an unrelated change. For unrelated changes, form independent groups that would each make a coherent PR. For every commit with a generic-looking scope, check **entanglement**: does it modify files created on this branch, or code the feature commits introduced (`git log {base}..HEAD -- <file>` per touched file)? Entangled commits stay on the branch; flag them with the reason. For each group report: commits in cherry-pick order, files touched, overlaps with other groups (shared files mean a merge-order dependency), expected cherry-pick conflicts, and any commit that needs a **split** (part general fix, part branch-only files) with the exact hunk division and whether a replacement test must be written against base-existing entry points. Return the raw evidence (file-to-commit mapping), not just conclusions.

The brief must also require an **already-on-base check**: fetch the base and establish, per candidate commit, whether its content already landed there. `git cherry {base} {branch}` marks patch-equivalent commits with `-`; an empty `git diff {base}...{branch} -- {files}` for a group's files says the same. A branch merged from base several times can carry commits whose work reached the base through an earlier PR; cherry-picking those produces an empty or nonsensical PR.

Verify the analysis yourself on three failure modes: spot-check the entanglement calls, confirm groups + stays-behind + feature commits cover every commit, and rerun the already-on-base check against a freshly fetched base.

Write the proposal into the progress file, then **present it to the human**: groups, commits, files, split commits, what stays behind and why, proposed merge order.

**Checkpoint 1: stop. Create nothing until the human approves the grouping.** Record approval and adjustments in the progress file.

## Phase 2: Extract, verify, review (parallel per PR)

Detect the environment first and record the mode. In cmux mode, create the group before the first PR; per PR, create the worktree and workspace yourself, launch the implementer in the workspace's first tab, and start its checklist with `create worktree` checked.

For each approved group, dispatch an **implementer subagent** with this pipeline (all implementers in parallel, each in its own worktree):

1. Create a worktree and branch off the up-to-date base: `git worktree add <path> -b <branch-name> {base}`, then run the worktree init command. In cmux mode the worktree exists; start at the init command.
2. Cherry-pick the group's commits in the approved order. For a split commit: apply only the approved hunks (`git checkout {sha} -- <files>` or a filtered diff), write the replacement test against a base-existing entry point, keep the relevant commit message content.
3. Run lint and the **full test suite**. Fix legitimate failures; never delete or skip tests to get green. Run every check in the foreground and do not end the turn until the step-5 report is written; long suites are fine.
4. Push, open the PR against the base with `gh pr create`, then run the describe-pr skill for its description.
5. Report back: worktree path, branch, PR URL, tail of the test run, `gh pr diff --name-only` output.

Keep the workspace status and checklist in step with the pipeline: `working` from step 1, checklist items checked at steps 2–4, `needs-attention` plus a one-line description on a failure, `review` when the reviewers start.

**Acceptance criteria you enforce before the review step:**

- PR diff file list matches the approved group exactly: nothing smuggled in, nothing missing.
- **Byte-identity with the source branch.** When the base tip is an ancestor of the feature branch (`git merge-base --is-ancestor {base} {branch}`), `git diff {pr-branch} {branch} -- {group files}` must print nothing; anything else means a cherry-pick resolved a conflict wrong. Record deliberate divergences (a replacement test, a review-demanded fix) so the Phase 4 back-merge expects them.
- **Full suite green from a LOCAL run in that worktree**, evidenced by the output tail. CI is never the acceptance signal.
- Commits preserved individually (no squashing during extraction), messages intact.
- **A behavior fix is pinned by a test that fails without it.** The implementer proves it: temporarily revert the fix, show the new test fails, restore, report the evidence; never commit the revert. Exercise the production entry point end to end, not the source of a value.

Then run "Adversarial review with two reviewers" on each PR. Route what survives adjudication back to the same implementer and repeat on the new diff. Record each round in the progress file.

When all PRs are review-clean, update the progress file and **report to the human**: one line per PR (URL, scope, test result, review rounds) plus anything that deviated from the approved plan.

**Checkpoint 2: stop. The human reviews the PRs and approves the merge set.** In cmux mode, set every PR workspace to `needs-attention` and check its `cross-validate findings` item first.

## Phase 3: Merge serially

Merge the approved PRs one at a time, in the approved dependency order:

- `gh pr merge <n> --merge`: **merge commit, never squash** (preserved commits let the back-merge resolve cherry-picks as identical). **No `--delete-branch`.**
- After each merge, check the next PR still merges cleanly (`gh pr view <n> --json mergeable`). If not, dispatch a **merger subagent** to update that PR's branch on the new base, resolve conflicts, rerun the full suite, and push; verify green before merging.
- Record each merge commit SHA in the progress file. In cmux mode, set that PR's workspace to `done` and check its `merge` item.

## Phase 4: Back-merge and denoise

Dispatch a **merger subagent** in the original worktree (in cmux mode, a new tab named `merger` in the last PR's workspace, since this skill never touches the feature branch's own workspace):

1. Merge the updated base into the feature branch (`git merge {base}`) and resolve conflicts. Cherry-picked commits should resolve as identical; investigate anything that doesn't, since it usually means an extraction diverged from the branch version.
2. Run the full test suite; fix legitimate fallout.
3. Push.

Then dispatch an **adversarial reviewer** on the reduced diff (`{base}...HEAD`): the final pre-merge review of the feature PR itself.

**Denoise the PR description too**: rerun the describe-pr skill against the reduced diff and update the description with `gh pr edit`, linking the extracted PRs where that adds context. If the repo keeps PR description files (for example `docs/prs/`), regenerate the original PR's file and commit it.

Finish the progress file (final diff stat before and after, review verdict); it stays uncommitted under the plan directory's `.gitignore`. In cmux mode, check `back-merge + cleanup` on each PR workspace and stop the watchdog. **Report to the human**: diff size reduction, test results, review outcome. The human approves and merges the original PR.

## Redo policy (every phase)

A redo message contains the missed acceptance criterion, the evidence (test output, diff line, review finding), and what "done" looks like. After two failed redos on one criterion, take over the step yourself and note the takeover in the progress file. A session that dies or stalls mid-step counts as one of those failures: recover its uncommitted work from the worktree, verify it yourself, and finish the step.

Review fixes land as **new commits on top**, never amendments to pushed commits. Amend only the tip docs commit, only when it holds nothing else, and fall back to a follow-up commit the moment it resists. Never reword a cherry-picked commit; its message is the link back to the feature branch.
