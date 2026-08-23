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
- **Where subagents run** depends on the environment: inside cmux, each one is its own `claude` session in its own tab (see "Running inside cmux"); everywhere else, in-process through the Agent tool. Everything else in this skill — briefs, acceptance criteria, redo policy — is the same either way.

## Inputs (resolve before Phase 1)

Resolve these from the repository's CLAUDE.md; ask the user for whatever is missing:

- **Base branch** — usually `master` or `main` (confirm with `gh repo view --json defaultBranchRef`).
- **Worktree init command** — the repo-specific setup for a fresh worktree (in miarecweb: `make setup`).
- **Full test suite command** and **lint command** for the repo.
- **Parallelism**: run extracted-PR pipelines and their full test suites truly in parallel. Serialize test runs only if a run fails from resource contention (shared databases, ports, CPU — rerun the failures once the sibling runs drain, then serially, before treating any failure as real), or if the user explicitly instructed serialization before the workflow started. Never accept a suite as green from a contention-polluted run; the evidence is the tail of the clean rerun.

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
Mode: cmux | in-process   cmux group: {workspace_group:N / anchor ref, cmux mode only}

## Approved grouping (Checkpoint 1: {date/pending})
### PR 1 — {title}
- Branch: {name}  Worktree: {path}  PR: {#/url or pending}
- cmux: workspace {ref + uuid}  tabs {role → surface ref}  agents {claude --name per role, codex thread id per role}  (cmux mode only)
- Commits (cherry-pick order): {sha — subject, per line; mark commits needing a split and what stays behind}
- Files: {list}
- State: pending | worktree-created | extracted | tests-green | pr-open | in-review (round N) | review-clean | merged
- Findings (round N): {id — author — agreed/unique — verdict — withdrawn/insisted — your decision, per line}
- Notes: {conflicts hit, redo reasons, deviations}

## Stays on the original branch
- {sha — reason it is entangled}

## Checkpoint 2 (ready for human review): {date/pending}
## Merge order and results
## Back-merge (Phase 4)
- Conflicts resolved: … Tests: … Review: … Pushed: {sha}
```

## Running inside cmux

cmux is the terminal multiplexer the user runs Claude Code in. Inside it, every subagent gets its own visible tab in a per-PR workspace, so the human can watch each agent work and take one over at any time. Outside cmux, none of this applies: run subagents in-process with the Agent tool and skip every `cmux` command.

Detect the mode once, at the start of Phase 2, and record it in the progress file:

```bash
[ -n "$CMUX_WORKSPACE_ID" ] && command -v cmux >/dev/null 2>&1 && echo "cmux mode"
```

### Rules

- **Only you call `cmux`.** Subagents never run cmux commands.
- **Run one cmux mutation at a time.** Wait for its `OK` before the next, and prefer the atomic forms (`workspace create --layout`, `todo set`) over several small calls. cmux sidebar rows measure their own height through a `GeometryReader` → `@State` feedback path, and a burst of list mutations races it: rows render with stale geometry — clipped titles, rows drawn over each other (cmux issues #6556, #4299, #8303, #10373). The fix, PR #10396, was still open on 2026-08-22. This rule adds no delay, only ordering. After #10396 ships, re-test with ten rapid mutations and delete this rule if the sidebar holds.
- **Never take focus.** Pass `--focus false`, and never run `workspace select`, `focus-pane`, or `focus-panel`. The human may be looking at another workspace.
- **Never close a workspace or a tab, and never terminate an agent** — not even one that finished its work. The human has to be able to open the tab and send the agent a follow-up. To rerun a subagent, open a **new** tab named `implementer (2)`, `reviewer (2)`, and so on.
- **Never reorder existing workspaces or groups.** Everything this workflow creates goes to the bottom of the sidebar, where the human expects to find it.
- **Touch only the workspaces you create.** Leave the feature branch's own workspace, its status, and its checklist alone.

### One group per split

Create the group at the start of Phase 2, then park it at the bottom:

```bash
cmux workspace-group create --name "split-pr: {branch}" --json    # → workspace_group:N
cmux workspace-group move workspace_group:N --to-index 999
```

`workspace-group create` also creates an **anchor workspace** whose sidebar row is the group header. Leave it empty: run nothing in it and set no status, checklist, or description on it. Groups don't nest, so this group stays top-level even when the feature branch's workspace belongs to another group.

Record the group ref and the anchor ref in the progress file.

### One workspace per extracted PR

In cmux mode you create the worktree yourself, so the workspace has a directory to open; the implementer starts from the repo's worktree init command instead:

```bash
git worktree add {worktree} -b {pr-branch} {base}
cmux workspace create --name "{pr-branch}" --cwd "{worktree}" --focus false \
  --group workspace_group:N --group-placement end --json      # → workspace_ref
```

Name the workspace after the branch only — cmux shows the PR link itself.

Record both identifiers in the progress file: the `workspace_ref` that `workspace create --json` returns, and the workspace UUID, which only `cmux workspace list --json` carries as `workspaces[].id` and which survives an app restart.

Give every tab its own `--working-directory`; the workspace's `--cwd` seeds only the first tab.

Created a workspace by mistake? Rename it for the next PR — `cmux rename-workspace --workspace {ref} "{other-pr-branch}"` — never close it.

### One tab per subagent

Each subagent is its own `claude` session in its own tab. Launch it with `--name` so you can address it and `--permission-mode auto` so it never stops for an approval.

The workspace already has one tab — a plain shell in the worktree. Start the implementer there rather than adding another: either launch it with the workspace in a single mutation,

```bash
cmux workspace create --name "{pr-branch}" --cwd "{worktree}" --focus false \
  --group workspace_group:N --group-placement end --json \
  --layout '{"pane":{"surfaces":[{"type":"terminal","command":"claude --name {pr-branch}-implementer --permission-mode auto \"Read {brief-path} and follow it.\""}]}}'
```

or rename the tab the plain `workspace create` returned and send the command into it. Every later agent gets its own new tab:

```bash
cmux new-surface --type terminal --workspace {workspace_ref} \
  --working-directory "{worktree}" --focus false               # → surface_ref
cmux rename-tab --workspace {workspace_ref} --surface {surface_ref} "implementer"
cmux send --surface {surface_ref} 'claude --name {pr-branch}-implementer --permission-mode auto "Read {brief-path} and follow it."'
cmux send-key --surface {surface_ref} Enter
```

`cmux send` types the text but doesn't submit it — the `send-key Enter` is required.

After launching, read the tab once to confirm the session came up, then confirm it registered by finding its exact `--name` in `ListAgents`. A worktree of a repository the user already trusts starts without a trust prompt, but a directory outside any trusted repository opens on "Do you trust this folder?" and waits there. If you see that question, clear it and check again:

```bash
cmux read-screen --workspace {workspace_ref} --surface {surface_ref} --lines 20
cmux send-key --workspace {workspace_ref} --surface {surface_ref} Enter   # only if the trust prompt is showing; selects "Yes, I trust this folder"
```

Name tabs for their role: `implementer`, `reviewer`, `codex reviewer`, `merger`. One tab holds one session for all of that role's work — review, validation, and rebuttal go to the same session, which is what keeps its context. A rerun gets a new tab, `implementer (2)`, and a new agent name; the old tab and its session stay open for the human.

### Talking to the agents

Keep each brief in a file under `docs/plans/{branch}/split-pr/briefs/` and give the tab a one-line command that reads it. Every brief must tell the agent to:

1. Write its report to an absolute path you name, `docs/plans/{branch}/split-pr/{pr-branch}.{role}.md` in the original worktree, carrying the evidence this skill requires: PR URL, commits, file list, lint result, test command with exit code and output tail, review findings. Markdown with those facts is enough — don't demand a rigid structure from an agent whose only reader is another agent.
2. Message you when it finishes, replying to the name in the `from` attribute of your message. Your first message to the agent establishes that address.

Verify from that file and from your own `gh pr diff --name-only` and `gh pr view` — never from an agent's prose summary, and never by reading its screen. `cmux read-screen` is for diagnosing a stuck or dead session, not for collecting results.

Drive the redo loop with `SendMessage(to: "{agent-name}", notify_when_idle: true)`: the message lands in that tab's session with its context intact, and you get one notice when it goes idle again.

### Status and checklist

Set these on the per-PR workspaces only:

```bash
cmux workspace status set <todo|working|review|needs-attention|done> --workspace {workspace_ref}
cmux todo set '[{"text":"cherry-pick commits","state":"in-progress"}, …]' --workspace {workspace_ref}
```

Write the checklist once with `todo set` when you create the workspace, then advance items with `cmux todo start <n>` and `cmux todo check <n>`:

`create worktree` · `cherry-pick commits` · `lint + full tests` · `push + open PR` · `describe PR` · `review (claude)` · `review (codex)` · `cross-validate findings` · `fix findings` · `human review` · `merge` · `back-merge + cleanup`

Map the state to the status lane: `todo` while queued, `working` while extracting, testing, or fixing, `review` during review rounds, `needs-attention` on any failure and at every human checkpoint, `done` once merged. `needs-attention` means the workflow is stopped until a human acts — keep it for that, so one glance at the sidebar answers whether the human is needed.

`cmux todo --help` warns agents that the checklist belongs to the user. This skill manages it by the user's explicit instruction. Keep to the items above and never edit an item you didn't create.

Use the description only for what the status and checklist can't express, and clear it once resolved:

```bash
cmux workspace-action --action set-description --description "2 test failures: test_siprec_rules" --workspace {workspace_ref}
cmux workspace-action --action clear-description --workspace {workspace_ref}
```

## Supervising the agents

Agents die, and sessions hang on a command that never returns. Check on every running agent at least every five minutes.

In-process subagents need no polling — the harness notifies you when one finishes. For tab sessions, arm a heartbeat before you dispatch the first one:

```
Monitor(command: 'while true; do echo "watchdog tick"; sleep 240; done', persistent: true)
```

On each tick, for every agent still working:

1. Run `ListAgents`. Confirm the agent is listed, and note whether it's busy or idle. A codex session isn't a peer session: check that its process is alive (`pgrep -f codex`), that its thread advanced (`select max(completed_at) from thread_turns where thread_id='{thread-id}';`), and that its output file exists; nudge it with `codex queue`. A codex tab back at a shell prompt means that session exited.
2. Compare its report file's mtime, and `git -C {worktree} log --oneline -1` and `git -C {worktree} status --porcelain`, against what you saw on the previous tick.
3. Idle with no report file: message it and ask for its current state.
4. Busy but unchanged across two consecutive ticks: message it. If it's waiting on a command that hung — a test run, a `gh` call — tell it to interrupt that command and retry.
5. Gone from `ListAgents`: the session died. Open a new tab, `{role} (2)`, and launch a fresh agent with a brief that states what's already done, from the progress file and the worktree's git state, and what remains.
6. Record every intervention and restart in the progress file.

Stop the watchdog with `TaskStop` when the last pipeline finishes.

## Adversarial review with two reviewers

Every extracted PR is reviewed twice, independently: once by a **claude reviewer** and once by a **codex reviewer**. Neither sees the other's work until both have written their findings. You then dedupe the two sets, have each reviewer judge the other's unique findings, let the author of a rejected finding withdraw it or defend it, and adjudicate what reaches the implementer.

`{plan-dir}` below is `docs/plans/{branch}/split-pr/` in the original worktree; every file this protocol produces lives there. If `codex` isn't on PATH, tell the human, record it in the progress file, and continue with the claude reviewer alone.

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

Launch both at once, per PR. They get the same brief: review `git diff {base}...{pr-branch}` for correctness, context dropped by a cherry-pick that silently depended on branch-only code, test quality against the repo's testing standards, and scope creep — and hunt for problems rather than bless the work.

A reviewer that can only read a diff is worth little. Both reviewers may run the test suite, the linters, the type checker, and any other check in the repo's CLAUDE.md, and may write throwaway probes to reproduce a suspected defect. What they must not do is change the PR: no edits to tracked files, no commits, no pushes. Fixes are the implementer's job.

- **claude reviewer** — in cmux, a new tab named `reviewer`; otherwise an in-process subagent. Its brief adds: write the findings to `{plan-dir}/{pr-branch}.claude-review.md` in the format above.
- **codex reviewer** — in cmux, the **interactive TUI** in a new tab named `codex reviewer`, so the human watches a real interface instead of a console dump, and one session carries the review, its validation pass, and its rebuttal:

  ```bash
  codex --approve-for-me "$(cat {plan-dir}/briefs/{pr-branch}.codex-review.md)"
  ```

  Outside cmux there's nothing to watch, so run the non-interactive form in the background instead. Tell that brief to make the report its final message, and `-o` captures it:

  ```bash
  codex exec \
    -o {plan-dir}/{pr-branch}.codex-review.md \
    "$(cat {plan-dir}/briefs/{pr-branch}.codex-review.md)"
  ```

What to know about driving codex:

- **Address an interactive session by its thread id.** Interactive codex has no `--name`, so open the brief with a unique marker line — `split-pr {branch} {pr-branch} codex-reviewer` — and resolve the thread from codex's own history once the session starts:

  ```bash
  sqlite3 ~/.codex/thread_history_1.sqlite \
    "select thread_id from thread_items where item_type='userMessage'
      and item_json like '%{marker}%' order by created_at_ms desc limit 1;"
  ```

  Match on the marker, never on "the newest thread" — parallel PR pipelines would pick up each other's sessions. Record the thread id in the progress file.
- **Send follow-ups with `codex queue --thread {thread-id} --message "…"`.** The running TUI picks the message up and works on it; this is the codex counterpart of `SendMessage`, and it keeps one session's context across the review, validation, and rebuttal rounds.
- **Collect results from files.** The brief names the report format and the exact output path, and the TUI session writes that file itself with a shell command. Read it and judge it on content, not on shape; queue a correction if ids or evidence are missing. To read what a session last said without scraping the screen:

  ```bash
  sqlite3 ~/.codex/thread_history_1.sqlite \
    "select item_json from thread_items where thread_id='{thread-id}'
      and item_type='agentMessage' order by rollout_ordinal desc limit 1;"
  ```

- **Don't use `codex exec review`.** It follows its own review format instead of the one your brief asks for, and it runs under a tighter sandbox — a verified run reported that it couldn't reach PostgreSQL, so its findings rest on reading alone. Plain `codex` and `codex exec` were both verified on 2026-08-22 with codex-cli 0.149.0.
- **Pass no `--sandbox` flag.** The user's `~/.codex/config.toml` and the repo's `.codex/rules/*.rules` already decide what codex may run, and overriding the sandbox on the command line only gets in the way. In miarecweb the rules let `make test`, `make test-e2e`, and `uv run pytest` run outside the sandbox precisely so PostgreSQL and Playwright are reachable; a DB-backed functional test was verified running green under plain `codex exec`. For anything the rules don't cover, codex requests an escalation and `approvals_reviewer = "auto_review"` decides — so don't use `--dangerously-bypass-approvals-and-sandbox`. `--approve-for-me` routes approvals through automatic review as well, but it can't be combined with `--sandbox`.
- If a repo has no such rules, expect codex to be blocked from the network and the database. Check `.codex/rules/` before you write the brief, and tell the reviewer which check commands are actually available to it.
- `-o` is written by the codex process itself, not by a sandboxed shell command, so the findings file always lands even when the run couldn't touch the worktree.
- The brief goes in through command substitution — `codex exec … "$(cat {plan-dir}/briefs/{pr-branch}.codex-review.md)"` — so keep it in a file and let the tab command stay one line. Give every codex brief the same shared preamble (what it may run, what it must never touch, the review dimensions, the id prefix) and append a per-PR section naming the specific things to attack in that diff. A codex reviewer pointed at a generic brief returns generic findings.
- Tell codex explicitly that it must not modify the PR. It has the same tools the implementer has, and nothing but the brief stops it from "helpfully" applying a fix.

An interactive session stays alive after it answers, which is what you want: the human can open the tab and keep talking to the reviewer, and you can queue more work into it. The non-interactive `codex exec` instead exits when it's done, so its tab ends at a shell prompt. Leave the tab open, as with every other tab. A finished run leaves its report behind; a tab back at a prompt with no report means the run died — read the tab to find out why before relaunching.

### Dedupe

When both findings files exist, dispatch a **dedup subagent** — in-process, since it needs no tab — with both files and this instruction: match findings, never judge them. Two findings are the same when they name the same defect at the same place, however differently they're worded; two different defects in one file are not duplicates. It writes `{plan-dir}/{pr-branch}.dedup.md`, listing findings by id:

```markdown
## agreed
- claude-1 = codex-3 — Export query drops the tenant filter

## unique to claude
- claude-2 — Replacement test asserts on the mock, not the database

## unique to codex
- codex-1 — Migration lacks a downgrade path
```

### Cross-validation

Each reviewer judges the other's unique findings, accept or reject, with a reason and evidence — same Markdown shape as the findings, one block per verdict:

```markdown
## codex-2 — reject
- reason: the guard it claims is missing runs in the decorator two frames up
- evidence: `rg "require_tenant" miarecweb/views/export.py` and the passing test it points at
```

- **codex validates `unique_claude`** — `codex queue --thread {thread-id}` into the same codex session, carrying those findings and the verdict shape, writing `{plan-dir}/{pr-branch}.codex-validation.md`. Outside cmux, a fresh `codex exec` with `-o` at that path. A validator may run the same checks the reviewers ran — reproducing or failing to reproduce a defect is the strongest verdict evidence there is.
- **claude validates `unique_codex`** — `SendMessage` to the claude reviewer session that's still open in its tab; its context already holds the diff. It writes `{plan-dir}/{pr-branch}.claude-validation.md`.

### Rebuttal

Send every rejection back to the finding's author, which either withdraws it or insists, with an argument — one block per response:

```markdown
## claude-3 — insist
- argument: the decorator it names runs only on the HTML view; the export endpoint is registered separately
```

- **claude author** — `SendMessage` to the same reviewer session → `{pr-branch}.claude-rebuttal.md`.
- **codex author** — `codex queue` into the same codex session, carrying the rejections → `{pr-branch}.codex-rebuttal.md`; its own findings are already in its context. Outside cmux, a fresh `codex exec` carrying both its original findings and the rejections.

### Adjudicate

You decide on the evidence, not by counting votes:

- **Agreed by both** — treat as real and route to the implementer.
- **Unique, accepted by the other reviewer** — route to the implementer.
- **Unique, rejected, then withdrawn** — drop it, and record that it was raised and withdrawn.
- **Unique, rejected, then insisted** — read the code yourself and settle it. If you still can't, keep it and have the implementer either fix it or explain in writing why it isn't a defect.

Record the trail for every finding in the progress file — author, dedupe class, verdict, rebuttal, your decision — then send the implementer one consolidated list. After the implementer reports back, run this whole protocol again on the new diff. The loop ends on a round where nothing survives adjudication.

Keep the reviewers isolated: neither may read the other's findings file before writing its own, and cross-validation is the only channel between them.

## Phase 1 — Analyze and propose

Dispatch an **analyst subagent** (read-only) with the base branch, feature branch, and this brief:

> Map every commit on `{branch}` not in `{base}` (`git log {base}..HEAD --oneline`). Classify each as feature work or an unrelated change. For unrelated changes, form independent groups that would each make a coherent PR. For every commit with a generic-looking scope, check **entanglement**: does it modify files created on this branch, or code the feature commits introduced (`git log {base}..HEAD -- <file>` per touched file)? Entangled commits stay on the branch — flag them explicitly with the reason. For each group report: commits in cherry-pick order, files touched, overlaps with other groups (shared files → merge-order dependency), expected cherry-pick conflicts, and any commit that needs a **split** (part general fix, part branch-only files) with the exact hunk division and whether a replacement test must be written against base-existing entry points. Return the raw evidence (file→commit mapping), not just conclusions.

The brief must also require an **already-on-base check**: fetch the base and, for every candidate commit, establish whether its content already landed there (`git cherry {base} {branch}` marks patch-equivalent commits with `-`; a `git diff {base}...{branch} -- {files}` that is empty for a group's files says the same thing louder). A branch that has been merged from base several times can carry commits whose work reached the base through an earlier PR, and cherry-picking those produces an empty or nonsensical PR.

Verify the analysis yourself on the three failure modes that matter: spot-check the entanglement calls, confirm the union of groups + stays-behind + feature commits covers every commit, and re-run the already-on-base check against a freshly fetched base before you present the grouping. In one run of this skill, three of five commits in a proposed group had already merged to master as a separate PR; catching that at Checkpoint 1 costs a minute, catching it after the worktree exists costs a rebuild.

Write the proposal into the progress file, then **present it to the human**: groups, commits, files, split commits, what stays behind and why, proposed merge order.

**Checkpoint 1 — stop. Create nothing until the human approves the grouping.** Record approval (and any adjustments) in the progress file.

## Phase 2 — Extract, verify, review (parallel per PR)

Detect the environment first (see "Running inside cmux") and record the mode. In cmux mode, create the group before the first PR, and for each PR create the worktree and its workspace yourself, then launch the implementer in that workspace's first tab; the workspace's checklist starts with `create worktree` already checked.

For each approved group, dispatch an **implementer subagent** with this pipeline (all implementers run in parallel, each in its own worktree):

1. Create a worktree and branch off the up-to-date base: `git worktree add <path> -b <branch-name> {base}`. Then run the repo's worktree init command. (In cmux mode you already created the worktree, so the implementer starts at the init command.)
2. Cherry-pick the group's commits in the approved order. For a split commit: apply only the approved hunks (`git checkout {sha} -- <files>` or apply a filtered diff), write the replacement test against a base-existing entry point, and keep the commit message's relevant content.
3. Run lint and the **full test suite**. Fix legitimate failures; never delete or skip tests to get green.
   Run every check in the **foreground** and don't end the turn until the report in step 5 is written. Backgrounding a suite and stopping to "wait for it" is the most common way these pipelines stall: the agent goes idle holding unreported work, and each nudge costs a round trip. Long suites are fine — the turn simply lasts as long as they do.
4. Push, open the PR against the base with `gh pr create`, then run the `describe-pr` skill to produce its description.
5. Report back: worktree path, branch, PR URL, tail of the test run, `gh pr diff --name-only` output.

Keep the workspace status and checklist in step with the pipeline as each stage lands: `working` from step 1, the matching checklist items checked at steps 2–4, `needs-attention` plus a one-line description on a failed test run or a cherry-pick conflict, `review` when the reviewer starts.

**Acceptance criteria you enforce before the review step:**

- PR diff file list matches the approved group exactly — nothing smuggled in, nothing missing.
- **Byte-identity with the source branch.** When the base tip is already an ancestor of the feature branch (`git merge-base --is-ancestor {base} {branch}`), every extracted file must be byte-identical to its feature-branch version: `git diff {pr-branch} {branch} -- {group files}` prints nothing. This catches a cherry-pick that silently resolved a conflict the wrong way, and it costs one command. Where a PR deliberately diverges — a replacement test, a fix demanded by review — record the exception in the progress file so the Phase 4 back-merge expects it.
- Full suite green in that worktree (see the actual output tail; on suspected resource contention, rerun serially before judging).
- Commits preserved individually (no squashing during extraction), messages intact.
- **A behavior fix is pinned by a test that fails without it.** Whenever a PR claims to fix behavior, the implementer must prove falsifiability: temporarily revert the fix, show the new test fails, restore, and report the evidence (never commit the revert). Two separate failures in one run of this skill were caught only by this check — a fix no test exercised, so removing it left the suite green, and a fix that was a no-op at the mechanism level because the marking it relied on was destroyed by a serialization boundary before the code under test ran. A test written against the source of a value proves nothing about the path the value actually travels: exercise the production entry point end to end.

Then review each PR with **two independent adversarial reviewers**, claude and codex, and run the dedupe, cross-validation, rebuttal, and adjudication protocol in "Adversarial review with two reviewers". Route what survives adjudication back to the same implementer, and repeat the protocol on the new diff. The loop ends on a round where nothing survives. Record each round in the progress file.

When all PRs are review-clean: update the progress file and **report to the human** — one line per PR (URL, scope, test result, review rounds) plus anything that deviated from the approved plan.

**Checkpoint 2 — stop. The human does the final review of the PRs and approves the merge set.** In cmux mode, set every PR workspace to `needs-attention` and check its `cross-validate findings` item first, so the sidebar shows what's waiting on the human.

## Phase 3 — Merge serially

Merge the approved PRs one at a time, in the approved dependency order:

- `gh pr merge <n> --merge` — **merge commit, never squash** (preserving the original commits lets the Phase 4 back-merge resolve cherry-picked changes as identical). **Do not delete the branch on GitHub** (no `--delete-branch`).
- After each merge, check whether the next PR still merges cleanly (`gh pr view <n> --json mergeable`). If not, dispatch a **merger subagent**: update that PR's branch on the new base, resolve conflicts, rerun the full suite, push. Verify green before merging it.
- Record each merge (merge commit SHA) in the progress file. In cmux mode, set that PR's workspace to `done` and check its `merge` item; leave the workspace and its tabs open.

## Phase 4 — Back-merge and denoise

Dispatch a **merger subagent** in the original worktree — in cmux mode, run it in a new tab named `merger` in the last PR's workspace, since this skill never touches the feature branch's own workspace:

1. Merge the updated base into the feature branch (`git merge {base}`), resolve conflicts. Cherry-picked commits should resolve as identical changes; investigate anything that does not — it usually means an extraction diverged from the branch version.
2. Run the full test suite; fix legitimate fallout.
3. Push.

Then dispatch an **adversarial reviewer** on the reduced diff (`{base}...HEAD`) — this is the final pre-merge review of the feature PR itself.

**Denoise the PR description too.** The original PR's description still covers the extracted changes. Rerun the `describe-pr` skill against the reduced diff and update the description on GitHub (`gh pr edit`); where mentioning the split adds context, link the extracted PRs. If the repo keeps PR description files (for example `docs/prs/`), regenerate the original PR's file the same way and commit it alongside the progress file.

Finish the progress file (final diff stat before/after, review verdict) and commit it. In cmux mode, check the `back-merge + cleanup` item on each PR workspace and stop the watchdog; leave the group, its workspaces, and every tab open for the human to close. **Report to the human**: diff size reduction, test results, review outcome. The human approves and merges the original PR.

## Redo policy (applies in every phase)

When rejecting subagent output, the redo message must contain: the specific acceptance criterion missed, the evidence (test output, diff line, review finding), and what "done" looks like. After two failed redos on the same criterion, take over that step yourself and note the takeover in the progress file. Count a session that dies or stalls mid-step as one of those failures: recover its uncommitted work from the worktree, verify it yourself rather than trusting it, and finish the step.

Review fixes land as **new commits on top**. Amending an already-pushed commit needs a history rewrite that the permission layer may refuse (`git reset --soft` is a common casualty), and a force-push costs more than a clean follow-up commit is worth. Amend only the tip docs commit, only when it holds nothing else, and fall back to a follow-up commit the moment it resists. Never reword a cherry-picked commit: its message is the link back to the feature branch.
