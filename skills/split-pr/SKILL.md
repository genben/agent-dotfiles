---
name: split-pr
description: Split unrelated changes out of a feature branch into separate PRs against the base branch, review and merge them, then back-merge the base to denoise the original PR. Use when a branch has accumulated drive-by fixes that create review noise, or when asked to split a PR/branch, extract unrelated fixes, or denoise a PR diff.
---

# Split PR

Extract unrelated changes from a feature branch into independent, reviewable PRs against the base branch, merge them, then merge the base back into the feature branch so its diff shrinks to only the feature work.

## Role: you are the orchestrator

You manage subagents (analyst, implementer, reviewers, merger). You do not do the extraction, review, or merge work yourself.

- **Verify claims, not summaries.** Require the actual test-run tail, the actual PR diff file list, the actual review verdict — and check them.
- **Reject half-done work.** Name the unmet acceptance criterion in the redo message; never "try again".
- **Take over a step yourself** only after a subagent has failed the same criterion twice.
- Launch independent subagents in parallel (one Agent message with multiple tool uses). Honor any user or memory instruction about the agent model.
- Subagents run as their own `claude` session in a cmux tab inside cmux, and in-process through the Agent tool everywhere else. Briefs, acceptance criteria, and the redo policy are identical either way.
- **Messages carry findings, not essays.** State the finding, the evidence, and what "done" looks like. Cut context-setting, reassurance, and restatement of what the agent already knows. Long messages are your tokens, and they bury the instruction.

## Worktree ownership (every agent, every phase)

**An agent writes only in the worktree it owns.** State it in every brief.

- Writable: its own worktree, plus its one report file under `docs/plans/{branch}/split-pr/`. Nothing else.
- No commit, checkout, reset, revert, rebase, stash or `git config` on another branch — not even to restore byte-identity.
- Anything that should change elsewhere goes in its report and a message to you. You route it; the owning agent applies it.

## Inputs (resolve before Phase 1)

Resolve these from the repository's CLAUDE.md; ask the user for whatever is missing:

- **Base branch** — usually `master` or `main` (confirm with `gh repo view --json defaultBranchRef`).
- **Worktree init command** — the repo-specific setup for a fresh worktree (in miarecweb: `make setup`).
- **Full test suite command** and **lint command** for the repo.
- **Parallelism**: run extracted-PR pipelines and their full test suites truly in parallel. Serialize test runs only if a run fails from resource contention (shared databases, ports, CPU — rerun the failures once the sibling runs drain, then serially, before treating any failure as real), or if the user explicitly instructed serialization before the workflow started. Never accept a suite as green from a contention-polluted run; the evidence is the tail of the clean rerun.

## Progress file (resumability)

Keep all workflow state in the **original worktree** at `docs/plans/{branch}/split-pr-progress.md`. It is the single source of truth: a new session resumes by reading it and continuing from the first incomplete step.

- Create it at the start of Phase 1; update it at **every state transition** (grouping approved, worktree created, tests green, PR opened, review round done, PR merged, back-merge done), not in batches at phase ends.
- Record concrete identifiers: commit SHAs per group, worktree paths, branch names, PR numbers and URLs, test-run results, review round counts, resolved conflicts.
- **On invocation, check for an existing progress file first.** If one exists, resume — do not restart Phase 1.
- **Never commit the workflow state.** When creating the progress file, also create `docs/plans/{branch}/.gitignore` containing exactly:

  ```
  split-pr-progress.md
  split-pr/
  ```

  The progress file, briefs, reports, and review/validation files are session state, not repository content — they stay local and out of every commit, including the final one. Commit the `.gitignore` itself only if the plan directory holds other, committed documents that would otherwise expose the state files to a stray `git add`.

**Append-only, one entry per event**, in this shape. Never rewrite or reflow an earlier entry — that keeps line numbers stable, so you and your agents can cite `split-pr-progress.md:120-140` instead of re-pasting content. Omit sections that do not apply.

```markdown
## 2026-08-23 11:22 — PR #792 round 2
### Changes
- c85efe8a4 optgroup test takes db_session (fixes claude-r2-1)
### Discoveries & Surprises
- criterion 3 unsatisfiable: pytest prints dots, so grep of own test file is 0 on every green run
### Decisions
- codex-r2-4 dropped: E501 ignored at pyproject.toml:548, per-file counts unchanged vs master
```

The file opens with a header block — the only part ever edited in place, because it is the resume pointer:

```markdown
# split-pr progress — {branch}
Base: {base}   Started: {date}   Mode: cmux | in-process   cmux group: {ref, cmux mode only}
Status: {phase and step}
PR {#} {branch} | {worktree} | {cmux workspace + agent names} | state: pending | worktree-created | extracted | tests-green | pr-open | in-review (round N) | review-clean | merged
Stays on the original branch: {sha — reason entangled, per line}
```

Everything after it is append-only entries. Record in them, as they happen: the approved grouping and cherry-pick order per PR, splits and what stays behind, conflicts, redo reasons, deliberate divergences the Phase 4 back-merge must expect, each finding as `id — author — agreed/unique — verdict — withdrawn/insisted — your decision`, checkpoint approvals, merge SHAs, and the back-merge result.

## Running inside cmux

Detect the mode once, at the start of Phase 2, and record it in the progress file:

```bash
[ -n "$CMUX_WORKSPACE_ID" ] && command -v cmux >/dev/null 2>&1 && echo "cmux mode"
```

Outside cmux, skip every `cmux` command in this section and run subagents in-process.

### Rules

- Only you call `cmux`. Subagents never run cmux commands.
- Run one cmux mutation at a time: wait for its `OK`, and prefer the atomic forms (`workspace create --layout`, `todo set`). Concurrent mutations race the sidebar's row-geometry measurement and leave rows clipped or overlapping.
- Never take focus. Pass `--focus false`; never run `workspace select`, `focus-pane`, or `focus-panel`.
- Never close a workspace or a tab, and never terminate an agent, finished or not. To rerun a subagent, open a **new** tab named `implementer (2)`, `reviewer (2)`, and so on.
- Never reorder existing workspaces or groups. Everything this workflow creates goes to the bottom of the sidebar.
- Touch only the workspaces you create. Leave the feature branch's own workspace, status, and checklist alone.

### One group per split

```bash
cmux workspace-group create --name "split-pr: {branch}" --json    # → workspace_group:N
cmux workspace-group move workspace_group:N --to-index 999
```

Group creation also creates an anchor workspace whose row is the group header: leave it empty — no commands, no status, no checklist, no description. Groups don't nest, so this group is top-level even when the feature branch's workspace belongs to another group. Record the group ref and anchor ref in the progress file.

### One workspace per extracted PR

Create the worktree yourself so the workspace has a directory to open; the implementer then starts at the init command.

```bash
git worktree add {worktree} -b {pr-branch} {base}
cmux workspace create --name "{pr-branch}" --cwd "{worktree}" --focus false \
  --group workspace_group:N --group-placement end --json      # → workspace_ref
```

- Name the workspace after the branch only — cmux shows the PR link itself.
- Record `workspace_ref` and the workspace UUID (`workspaces[].id` from `cmux workspace list --json`, which survives an app restart).
- Give every tab its own `--working-directory`; the workspace's `--cwd` seeds only the first tab.
- Created a workspace by mistake? Rename it for the next PR — `cmux rename-workspace --workspace {ref} "{other-pr-branch}"` — never close it.

### One tab per subagent

Launch each agent with `--name`, so you can address it, and `--permission-mode auto`, so it never stops for an approval.

The first agent goes in the workspace's own tab, created in one mutation:

```bash
cmux workspace create --name "{pr-branch}" --cwd "{worktree}" --focus false \
  --group workspace_group:N --group-placement end --json \
  --layout '{"pane":{"surfaces":[{"type":"terminal","command":"claude --name {pr-branch}-implementer --permission-mode auto \"Read {brief-path} and follow it.\""}]}}'
```

Every later agent gets its own new tab:

```bash
cmux new-surface --type terminal --workspace {workspace_ref} \
  --working-directory "{worktree}" --focus false               # → surface_ref
cmux rename-tab --workspace {workspace_ref} --surface {surface_ref} "implementer"
cmux send --surface {surface_ref} 'claude --name {pr-branch}-implementer --permission-mode auto "Read {brief-path} and follow it."'
cmux send-key --surface {surface_ref} Enter
```

- `cmux send` types the text; `send-key Enter` submits it.
- Confirm the session came up with `cmux read-screen --workspace {workspace_ref} --surface {surface_ref} --lines 20`, then find its exact `--name` in `ListAgents`. If the tab shows "Do you trust this folder?", clear it with `cmux send-key --workspace {workspace_ref} --surface {surface_ref} Enter`.
- Tab names: `implementer`, `reviewer`, `codex reviewer`, `merger`. One session serves all of that role's rounds. A rerun gets a new tab and a new agent name; the old tab and session stay open.

### Talking to the agents

Keep each brief in a file under `docs/plans/{branch}/split-pr/briefs/` and give the tab a one-line command that reads it. Every brief must require the agent to:

1. Write its report to an absolute path you name, `docs/plans/{branch}/split-pr/{pr-branch}.{role}.md` in the original worktree, carrying PR URL, commits, file list, lint result, test command with exit code and output tail, and findings. Markdown with those facts is enough.
2. Message you when it finishes, replying to the name in the `from` attribute of your message.

Verify from that report and from your own `gh pr diff --name-only` and `gh pr view` — never from an agent's prose summary, and never from its screen. `cmux read-screen` is for diagnosing a stuck or dead session.

Drive the redo loop with `SendMessage(to: "{agent-name}", notify_when_idle: true)`.

### Status and checklist

Set these on per-PR workspaces only:

```bash
cmux workspace status set <todo|working|review|needs-attention|done> --workspace {workspace_ref}
cmux todo set '[{"text":"cherry-pick commits","state":"in-progress"}, …]' --workspace {workspace_ref}
```

Write the checklist once with `todo set` at workspace creation, then advance items with `cmux todo start <n>` and `cmux todo check <n>`:

`create worktree` · `cherry-pick commits` · `lint + full tests` · `push + open PR` · `describe PR` · `review (claude)` · `review (codex)` · `cross-validate findings` · `fix findings` · `human review` · `merge` · `back-merge + cleanup`

Status lanes: `todo` while queued, `working` while extracting, testing, or fixing, `review` during review rounds, `needs-attention` on any failure and at every human checkpoint, `done` once merged. Reserve `needs-attention` for "stopped until a human acts".

The cmux checklist belongs to the user; this skill manages it by the user's explicit instruction. Keep to the items above and never edit an item you didn't create.

Use the description only for what status and checklist can't express, and clear it once resolved:

```bash
cmux workspace-action --action set-description --description "2 test failures: test_siprec_rules" --workspace {workspace_ref}
cmux workspace-action --action clear-description --workspace {workspace_ref}
```

## Supervising the agents

Check every running agent at least every five minutes. In-process subagents need no polling — the harness notifies you. For tab sessions, arm a heartbeat before dispatching the first one:

```
Monitor(command: 'while true; do echo "watchdog tick"; sleep 240; done', persistent: true)
```

On each tick, for every agent still working:

1. Run `ListAgents`: is the agent listed, busy or idle? A codex session is not a peer session — check that its process is alive (`pgrep -f codex`), that its thread advanced (`select max(completed_at) from thread_turns where thread_id='{thread-id}';`), and that its report exists. A codex tab back at a shell prompt means that session exited.
2. Compare the report's mtime, `git -C {worktree} log --oneline -1`, and `git -C {worktree} status --porcelain` against the previous tick.
3. Idle with no report: ask it for its current state.
4. Busy but unchanged across two consecutive ticks: message it, or `codex queue` it. If it's waiting on a hung command, tell it to interrupt and retry.
5. Gone from `ListAgents`: open a new tab, `{role} (2)`, and launch a fresh agent with a brief stating what's done — from the progress file and the worktree's git state — and what remains.
6. Record every intervention and restart in the progress file.

Stop the watchdog with `TaskStop` when the last pipeline finishes.

## Adversarial review with two reviewers

Every extracted PR is reviewed twice, independently: a **claude reviewer** and a **codex reviewer**. Neither may read the other's findings before writing its own; cross-validation is the only channel between them. Then dedupe, cross-validate, take rebuttals, and adjudicate.

`{plan-dir}` is `docs/plans/{branch}/split-pr/` in the original worktree; every file this protocol produces lives there. If `codex` isn't on PATH, tell the human, record it in the progress file, and continue with the claude reviewer alone.

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

Every finding needs an id — `claude-N` from the claude reviewer, `codex-N` from codex — since every later stage refers to findings by id. Omit fields that don't apply.

Judge a report by its ids, evidence, and whether it's actionable; queue a correction when it isn't.

### Running the two reviewers

Launch both at once, per PR, on the same brief: review `git diff {base}...{pr-branch}` for correctness, context dropped by a cherry-pick that silently depended on branch-only code, test quality against the repo's testing standards, and scope creep — hunting for problems, not blessing the work.

Both reviewers may run the test suite, the linters, the type checker, any other check in the repo's CLAUDE.md, and throwaway probes that reproduce a suspected defect. Neither may change the PR: no edits to tracked files, no commits, no pushes. State that prohibition in the brief — a reviewer has the same tools as the implementer.

Give every brief a shared preamble (what it may run, what it must never touch, the review dimensions, its id prefix) and a per-PR section naming what to attack in that diff. A generic brief returns generic findings.

- **claude reviewer** — in cmux, a new tab named `reviewer`; otherwise an in-process subagent. Writes `{plan-dir}/{pr-branch}.claude-review.md`.
- **codex reviewer** — in cmux, the interactive TUI in a new tab named `codex reviewer`; one session carries the review, its validation pass, and its rebuttal:

  ```bash
  codex --approve-for-me "$(cat {plan-dir}/briefs/{pr-branch}.codex-review.md)"
  ```

  Outside cmux, run the non-interactive form in the background; tell that brief to make the report its final message, which `-o` captures:

  ```bash
  codex exec \
    -o {plan-dir}/{pr-branch}.codex-review.md \
    "$(cat {plan-dir}/briefs/{pr-branch}.codex-review.md)"
  ```

Driving codex:

- **Address a session by thread id.** Interactive codex has no `--name`. Open the brief with a unique marker line — `split-pr {branch} {pr-branch} codex-reviewer` — and resolve the thread once the session starts. Match the marker, never "the newest thread". Record the id in the progress file.

  ```bash
  sqlite3 ~/.codex/thread_history_1.sqlite \
    "select thread_id from thread_items where item_type='userMessage'
      and item_json like '%{marker}%' order by created_at_ms desc limit 1;"
  ```

- **Send follow-ups with `codex queue --thread {thread-id} --message "…"`** — the codex counterpart of `SendMessage`, keeping one session's context across review, validation, and rebuttal.
- **Collect results from the report file** the session writes. To read its last message without the screen:

  ```bash
  sqlite3 ~/.codex/thread_history_1.sqlite \
    "select item_json from thread_items where thread_id='{thread-id}'
      and item_type='agentMessage' order by rollout_ordinal desc limit 1;"
  ```

- **Pass no `--sandbox` flag.** `~/.codex/config.toml` and the repo's `.codex/rules/*.rules` decide what codex may run; rules can allow test commands to run outside the sandbox, which is how the reviewer reaches the database and a browser. Anything the rules don't cover raises an escalation request that `approvals_reviewer` decides. Never use `--dangerously-bypass-approvals-and-sandbox`; `--approve-for-me` can't be combined with `--sandbox`.
- **Read `.codex/rules/` before writing the brief** and tell the reviewer which check commands it can run. Without such rules, codex has no network and no database.
- **Don't use `codex exec review`** — it imposes its own report format and runs under a tighter sandbox that can't reach the database.
- An interactive session stays alive after answering; queue more work into it. `codex exec` exits and leaves its tab at a shell prompt — leave the tab open. A finished tab with no report means the run died; read the tab before relaunching.

### Dedupe

When both findings files exist, dispatch a **dedup subagent** (in-process) with both files: match findings, never judge them. Two findings are the same when they name the same defect at the same place, however differently worded; two different defects in one file are not duplicates. It writes `{plan-dir}/{pr-branch}.dedup.md`:

```markdown
## agreed
- claude-1 = codex-3 — Export query drops the tenant filter

## unique to claude
- claude-2 — Replacement test asserts on the mock, not the database

## unique to codex
- codex-1 — Migration lacks a downgrade path
```

### Cross-validation

Each reviewer judges the other's unique findings, accept or reject, with a reason and evidence — one block per verdict. A validator may run the same checks the reviewers ran; reproducing, or failing to reproduce, a defect is the strongest verdict evidence.

The validator's job is critical judgment, not technical confirmation — instruct it to attack each finding on two independent axes and reject on either:

1. **Is it real?** Does the claimed defect actually occur as described (the classic reproduce-or-refute pass)?
2. **Does it matter?** Reject as slop any finding whose failing input no production path constructs, whose fix would be defensive code for a problem that does not exist, or whose only consequence is degraded behavior on inputs the application can never produce. Reproducibility is not importance: a validator that reproduces a probe must still ask what breaks for a real user, and reject when the answer is nothing. Defensive code is slop — a suggested fix that adds guards, fallbacks, or handling for unreachable states is grounds to reject the finding, not to soften it.

```markdown
## codex-2 — reject
- reason: the guard it claims is missing runs in the decorator two frames up
- evidence: `rg "require_tenant" miarecweb/views/export.py` and the passing test it points at

## codex-4 — reject
- reason: real as probed, but no production path constructs a self-referential mapping; the fix would be defensive code for an impossible input
- evidence: `rg` over all mapping constructors — every one builds a fresh literal dict; nothing stores a container into its own mapping
```

- **codex validates `unique to claude`** — `codex queue --thread {thread-id}` into the same session, writing `{plan-dir}/{pr-branch}.codex-validation.md`. Outside cmux, a fresh `codex exec` with `-o` at that path.
- **claude validates `unique to codex`** — `SendMessage` to the claude reviewer session, which still holds the diff in context. It writes `{plan-dir}/{pr-branch}.claude-validation.md`.

### Rebuttal

Send every rejection back to the finding's author, which withdraws it or insists, with an argument — one block per response:

```markdown
## claude-3 — insist
- argument: the decorator it names runs only on the HTML view; the export endpoint is registered separately
```

- **claude author** — `SendMessage` to the same reviewer session → `{pr-branch}.claude-rebuttal.md`.
- **codex author** — `codex queue` into the same codex session → `{pr-branch}.codex-rebuttal.md`. Outside cmux, a fresh `codex exec` carrying both its original findings and the rejections.

### Adjudicate

Decide on the evidence, not by counting votes:

- **Agreed by both** — route to the implementer.
- **Unique, accepted by the other reviewer** — route to the implementer.
- **Unique, rejected, then withdrawn** — drop it; record that it was raised and withdrawn.
- **Unique, rejected, then insisted** — read the code yourself and settle it. If it stays unsettled, keep it and have the implementer fix it or explain in writing why it isn't a defect.

**You own the quality of the outcome, and quality includes what does NOT get written.** Acceptance is a necessary condition to route a finding, never a sufficient one — apply these bars before anything reaches the implementer:

- **No defensive code for problems that do not exist.** A finding becomes a fix only when it names a production entry point and an input that reaches the defect today. A reviewer probe that *constructs* the failing input proves the defect is real, not that it matters — self-referential structures, adversarial orderings, and API shapes with zero call sites are adjudicated as document-or-drop, however reproducible. Every landed fix is permanent read/review/maintain cost for the repo's owners; a corner nothing can reach is not worth that cost.
- **Take low-severity findings with a grain of salt.** Reviewers are prompted to hunt, so they will always return something; volume and reproducibility are not importance. For a low-severity finding, ask what breaks for a real user if it ships unfixed — if the honest answer is "nothing", drop it and record why.
- **Expect the loop to drift theoretical.** Round N+1's findings are usually weaker than round N's; when a round's survivors are only pathological-input polish, END the loop instead of routing them. Two clean-enough rounds beat five rounds of hardening nobody asked for.

Record the trail for every finding in the progress file — author, dedupe class, verdict, rebuttal, your decision — then send the implementer one consolidated list. After the implementer reports back, run the protocol again on the new diff. The loop ends on a round where nothing survives adjudication.

State the production-path bar in every reviewer brief so reviewers self-filter: findings must name the production entry point and the input that reaches the defect, or explicitly label themselves theoretical so adjudication can drop them cheaply.

## Phase 1 — Analyze and propose

Dispatch an **analyst subagent** (read-only) with the base branch, feature branch, and this brief:

> Map every commit on `{branch}` not in `{base}` (`git log {base}..HEAD --oneline`). Classify each as feature work or an unrelated change. For unrelated changes, form independent groups that would each make a coherent PR. For every commit with a generic-looking scope, check **entanglement**: does it modify files created on this branch, or code the feature commits introduced (`git log {base}..HEAD -- <file>` per touched file)? Entangled commits stay on the branch — flag them explicitly with the reason. For each group report: commits in cherry-pick order, files touched, overlaps with other groups (shared files → merge-order dependency), expected cherry-pick conflicts, and any commit that needs a **split** (part general fix, part branch-only files) with the exact hunk division and whether a replacement test must be written against base-existing entry points. Return the raw evidence (file→commit mapping), not just conclusions.

The brief must also require an **already-on-base check**: fetch the base and, for every candidate commit, establish whether its content already landed there. `git cherry {base} {branch}` marks patch-equivalent commits with `-`; an empty `git diff {base}...{branch} -- {files}` for a group's files says the same. A branch merged from base several times can carry commits whose work reached the base through an earlier PR, and cherry-picking those produces an empty or nonsensical PR.

Verify the analysis yourself on three failure modes: spot-check the entanglement calls, confirm the union of groups + stays-behind + feature commits covers every commit, and re-run the already-on-base check against a freshly fetched base before presenting the grouping.

Write the proposal into the progress file, then **present it to the human**: groups, commits, files, split commits, what stays behind and why, proposed merge order.

**Checkpoint 1 — stop. Create nothing until the human approves the grouping.** Record approval and any adjustments in the progress file.

## Phase 2 — Extract, verify, review (parallel per PR)

Detect the environment first and record the mode. In cmux mode, create the group before the first PR; for each PR create the worktree and workspace yourself, launch the implementer in the workspace's first tab, and start its checklist with `create worktree` checked.

For each approved group, dispatch an **implementer subagent** with this pipeline (all implementers run in parallel, each in its own worktree):

1. Create a worktree and branch off the up-to-date base: `git worktree add <path> -b <branch-name> {base}`, then run the repo's worktree init command. In cmux mode the worktree already exists, so start at the init command.
2. Cherry-pick the group's commits in the approved order. For a split commit: apply only the approved hunks (`git checkout {sha} -- <files>` or a filtered diff), write the replacement test against a base-existing entry point, and keep the relevant content of the commit message.
3. Run lint and the **full test suite**. Fix legitimate failures; never delete or skip tests to get green. Run every check in the **foreground** and don't end the turn until the step-5 report is written — a backgrounded suite leaves the agent idle holding unreported work. Long suites are fine; the turn lasts as long as they do.
4. Push, open the PR against the base with `gh pr create`, then run the `describe-pr` skill to produce its description.
5. Report back: worktree path, branch, PR URL, tail of the test run, `gh pr diff --name-only` output.

Keep the workspace status and checklist in step with the pipeline: `working` from step 1, matching checklist items checked at steps 2–4, `needs-attention` plus a one-line description on a failed test run or a cherry-pick conflict, `review` when the reviewers start.

**Acceptance criteria you enforce before the review step:**

- PR diff file list matches the approved group exactly — nothing smuggled in, nothing missing.
- **Byte-identity with the source branch.** When the base tip is already an ancestor of the feature branch (`git merge-base --is-ancestor {base} {branch}`), `git diff {pr-branch} {branch} -- {group files}` must print nothing; anything else means a cherry-pick resolved a conflict the wrong way. Record deliberate divergences — a replacement test, a fix demanded by review — in the progress file so the Phase 4 back-merge expects them.
- **Full suite green from a LOCAL run in that worktree**, evidenced by the output tail. CI is never the acceptance signal. On contention, serialize the runs — never fall back to citing CI.
- Commits preserved individually (no squashing during extraction), messages intact.
- **A behavior fix is pinned by a test that fails without it.** The implementer proves falsifiability: temporarily revert the fix, show the new test fails, restore, and report the evidence — never commit the revert. A test written against the source of a value proves nothing about the path that value travels; exercise the production entry point end to end.

Then review each PR with two independent adversarial reviewers and run the protocol in "Adversarial review with two reviewers". Route what survives adjudication back to the same implementer and repeat on the new diff. Record each round in the progress file.

When all PRs are review-clean: update the progress file and **report to the human** — one line per PR (URL, scope, test result, review rounds) plus anything that deviated from the approved plan.

**Checkpoint 2 — stop. The human reviews the PRs and approves the merge set.** In cmux mode, set every PR workspace to `needs-attention` and check its `cross-validate findings` item first.

## Phase 3 — Merge serially

Merge the approved PRs one at a time, in the approved dependency order:

- `gh pr merge <n> --merge` — **merge commit, never squash**; preserved commits let the Phase 4 back-merge resolve cherry-picked changes as identical. **Do not delete the branch on GitHub** (no `--delete-branch`).
- After each merge, check whether the next PR still merges cleanly (`gh pr view <n> --json mergeable`). If not, dispatch a **merger subagent** to update that PR's branch on the new base, resolve conflicts, rerun the full suite, and push. Verify green before merging it.
- Record each merge commit SHA in the progress file. In cmux mode, set that PR's workspace to `done` and check its `merge` item.

## Phase 4 — Back-merge and denoise

Dispatch a **merger subagent** in the original worktree — in cmux mode, in a new tab named `merger` in the last PR's workspace, since this skill never touches the feature branch's own workspace:

1. Merge the updated base into the feature branch (`git merge {base}`) and resolve conflicts. Cherry-picked commits should resolve as identical changes; investigate anything that doesn't — it usually means an extraction diverged from the branch version.
2. Run the full test suite; fix legitimate fallout.
3. Push.

Then dispatch an **adversarial reviewer** on the reduced diff (`{base}...HEAD`) — the final pre-merge review of the feature PR itself.

**Denoise the PR description too**: rerun the `describe-pr` skill against the reduced diff and update the description with `gh pr edit`, linking the extracted PRs where that adds context. If the repo keeps PR description files (for example `docs/prs/`), regenerate the original PR's file and commit it.

Finish the progress file (final diff stat before and after, review verdict) — it stays uncommitted, covered by the plan directory's `.gitignore`. In cmux mode, check the `back-merge + cleanup` item on each PR workspace and stop the watchdog. **Report to the human**: diff size reduction, test results, review outcome. The human approves and merges the original PR.

## Redo policy (applies in every phase)

A redo message must contain the specific acceptance criterion missed, the evidence (test output, diff line, review finding), and what "done" looks like. After two failed redos on the same criterion, take over that step yourself and note the takeover in the progress file. A session that dies or stalls mid-step counts as one of those failures: recover its uncommitted work from the worktree, verify it yourself rather than trusting it, and finish the step.

Review fixes land as **new commits on top**. Amending an already-pushed commit needs a history rewrite the permission layer may refuse, and a force-push costs more than a clean follow-up commit is worth. Amend only the tip docs commit, only when it holds nothing else, and fall back to a follow-up commit the moment it resists. Never reword a cherry-picked commit: its message is the link back to the feature branch.
