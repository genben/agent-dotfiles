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
Mode: cmux | in-process   cmux group: {workspace_group:N / anchor ref, cmux mode only}

## Approved grouping (Checkpoint 1: {date/pending})
### PR 1 — {title}
- Branch: {name}  Worktree: {path}  PR: {#/url or pending}
- cmux: workspace {ref + uuid}  tabs {role → surface ref}  agents {--name per role}  (cmux mode only)
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

Name the workspace after the branch only. cmux shows the PR link by itself, so don't add the PR number. Record the `workspace_ref` and the UUID from `cmux workspace list --json` in the progress file; the UUID survives an app restart.

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

Name tabs for their role: `implementer`, `reviewer`, `codex reviewer`, `codex validator`, `codex rebuttal`, `merger`. A rerun gets a new tab, `implementer (2)`, and a new agent name; the old tab and its session stay open for the human.

### Talking to the agents

Keep each brief in a file under `docs/plans/{branch}/split-pr/briefs/` and give the tab a one-line command that reads it. Every brief must tell the agent to:

1. Write its result as JSON to an absolute path you name, `docs/plans/{branch}/split-pr/{pr-branch}.{role}.json` in the original worktree, carrying the evidence this skill requires: PR URL, commits, file list, lint result, test command with exit code and output tail, review findings.
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

1. Run `ListAgents`. Confirm the agent is listed, and note whether it's busy or idle. A codex run is a plain process, not a peer session, so check it with `pgrep -f "codex exec"` and the mtime of its `-o` file instead; a tab sitting at a shell prompt with no output file means the run died.
2. Compare its report file's mtime, and `git -C {worktree} log --oneline -1` and `git -C {worktree} status --porcelain`, against what you saw on the previous tick.
3. Idle with no report file: message it and ask for its current state.
4. Busy but unchanged across two consecutive ticks: message it. If it's waiting on a command that hung — a test run, a `gh` call — tell it to interrupt that command and retry.
5. Gone from `ListAgents`: the session died. Open a new tab, `{role} (2)`, and launch a fresh agent with a brief that states what's already done, from the progress file and the worktree's git state, and what remains.
6. Record every intervention and restart in the progress file.

Stop the watchdog with `TaskStop` when the last pipeline finishes.

## Adversarial review with two reviewers

Every extracted PR is reviewed twice, independently: once by a **claude reviewer** and once by a **codex reviewer**. Neither sees the other's work until both have written their findings. You then dedupe the two sets, have each reviewer judge the other's unique findings, let the author of a rejected finding withdraw it or defend it, and adjudicate what reaches the implementer.

`{plan-dir}` below is `docs/plans/{branch}/split-pr/` in the original worktree; every file this protocol produces lives there. If `codex` isn't on PATH, tell the human, record it in the progress file, and continue with the claude reviewer alone.

### Shared findings schema

Write it once per split, to `docs/plans/{branch}/split-pr/findings.schema.json`, and give it to both reviewers:

```json
{
  "type": "object",
  "properties": {
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {"type": "string"},
          "file": {"type": "string"},
          "line": {"type": "integer"},
          "severity": {"type": "string", "enum": ["low", "medium", "high"]},
          "category": {"type": "string"},
          "title": {"type": "string"},
          "detail": {"type": "string"},
          "evidence": {"type": "string"},
          "suggested_fix": {"type": "string"}
        },
        "required": ["id", "file", "severity", "category", "title", "detail", "evidence"],
        "additionalProperties": false
      }
    }
  },
  "required": ["findings"],
  "additionalProperties": false
}
```

Ids are `claude-1`, `claude-2`, … and `codex-1`, `codex-2`, … so every later stage can refer to a finding unambiguously.

### Running the two reviewers

Launch both at once, per PR. They get the same brief: review `git diff {base}...{pr-branch}` for correctness, context dropped by a cherry-pick that silently depended on branch-only code, test quality against the repo's testing standards, and scope creep — and hunt for problems rather than bless the work.

A reviewer that can only read a diff is worth little. Both reviewers may run the test suite, the linters, the type checker, and any other check in the repo's CLAUDE.md, and may write throwaway probes to reproduce a suspected defect. What they must not do is change the PR: no edits to tracked files, no commits, no pushes. Fixes are the implementer's job.

- **claude reviewer** — in cmux, a new tab named `reviewer`; otherwise an in-process subagent. Its brief adds: write the findings to `{plan-dir}/{pr-branch}.claude-review.json` in the schema's shape.
- **codex reviewer** — in cmux, a new tab named `codex reviewer`; otherwise the same command through Bash with `run_in_background`:

```bash
codex exec \
  --output-schema {plan-dir}/findings.schema.json \
  -o {plan-dir}/{pr-branch}.codex-review.json \
  "$(cat {plan-dir}/briefs/{pr-branch}.codex-review.md)"
```

Four things to know about driving codex:

- Use plain `codex exec`, not `codex exec review`. The review subcommand ignores `--output-schema` and writes prose to `-o`; plain `exec` honors the schema exactly. Both were verified on 2026-08-22 with codex-cli 0.149.0.
- **Pass no `--sandbox` flag.** The user's `~/.codex/config.toml` and the repo's `.codex/rules/*.rules` already decide what codex may run, and overriding the sandbox on the command line only gets in the way. In miarecweb the rules let `make test`, `make test-e2e`, and `uv run pytest` run outside the sandbox precisely so PostgreSQL and Playwright are reachable; a DB-backed functional test was verified running green under plain `codex exec`. For anything the rules don't cover, codex requests an escalation and `approvals_reviewer = "auto_review"` decides — so don't use `--dangerously-bypass-approvals-and-sandbox`. `--approve-for-me` routes approvals through automatic review as well, but it can't be combined with `--sandbox`.
- If a repo has no such rules, expect codex to be blocked from the network and the database. Check `.codex/rules/` before you write the brief, and tell the reviewer which check commands are actually available to it.
- `-o` is written by the codex process itself, not by a sandboxed shell command, so the findings file always lands even when the run couldn't touch the worktree.

`codex exec` exits when it's done, so its tab ends at a shell prompt. Leave the tab open, as with every other tab.

### Dedupe

When both findings files exist, dispatch a **dedup subagent** — in-process, since it needs no tab — with both files and this instruction: match findings, never judge them. Two findings are the same when they name the same defect at the same place, however differently they're worded; two different defects in one file are not duplicates. It writes `{plan-dir}/{pr-branch}.dedup.json`:

```json
{"agreed": [{"claude_id": "claude-1", "codex_id": "codex-3", "title": "…"}],
 "unique_claude": ["claude-2"],
 "unique_codex": ["codex-1"]}
```

### Cross-validation

Each reviewer judges the other's unique findings, accept or reject, with a reason and evidence. Verdicts use one schema, `verdicts.schema.json`: `{"verdicts": [{"finding_id": "…", "verdict": "accept|reject", "reason": "…", "evidence": "…"}]}`.

- **codex validates `unique_claude`** — a fresh `codex exec` in a new tab named `codex validator`, carrying those findings inline, with the verdict schema and `-o {plan-dir}/{pr-branch}.codex-validation.json`. A validator may run the same checks the reviewers ran — reproducing or failing to reproduce a defect is the strongest verdict evidence there is.
- **claude validates `unique_codex`** — `SendMessage` to the claude reviewer session that's still open in its tab; its context already holds the diff. It writes `{plan-dir}/{pr-branch}.claude-validation.json`.

### Rebuttal

Send every rejection back to the finding's author, which either withdraws it or insists, with an argument. Responses use `{"responses": [{"finding_id": "…", "response": "withdraw|insist", "argument": "…"}]}`.

- **claude author** — `SendMessage` to the same reviewer session → `{pr-branch}.claude-rebuttal.json`.
- **codex author** — a fresh `codex exec` in a new tab named `codex rebuttal`, carrying its original findings plus the rejections → `{pr-branch}.codex-rebuttal.json`.

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

Verify the analysis yourself on the two failure modes that matter: spot-check the entanglement calls, and confirm the union of groups + stays-behind + feature commits covers every commit.

Write the proposal into the progress file, then **present it to the human**: groups, commits, files, split commits, what stays behind and why, proposed merge order.

**Checkpoint 1 — stop. Create nothing until the human approves the grouping.** Record approval (and any adjustments) in the progress file.

## Phase 2 — Extract, verify, review (parallel per PR)

Detect the environment first (see "Running inside cmux") and record the mode. In cmux mode, create the group before the first PR, and for each PR create the worktree and its workspace yourself, then launch the implementer in that workspace's first tab; the workspace's checklist starts with `create worktree` already checked.

For each approved group, dispatch an **implementer subagent** with this pipeline (all implementers run in parallel, each in its own worktree):

1. Create a worktree and branch off the up-to-date base: `git worktree add <path> -b <branch-name> {base}`. Then run the repo's worktree init command. (In cmux mode you already created the worktree, so the implementer starts at the init command.)
2. Cherry-pick the group's commits in the approved order. For a split commit: apply only the approved hunks (`git checkout {sha} -- <files>` or apply a filtered diff), write the replacement test against a base-existing entry point, and keep the commit message's relevant content.
3. Run lint and the **full test suite**. Fix legitimate failures; never delete or skip tests to get green.
4. Push, open the PR against the base with `gh pr create`, then run the `describe-pr` skill to produce its description.
5. Report back: worktree path, branch, PR URL, tail of the test run, `gh pr diff --name-only` output.

Keep the workspace status and checklist in step with the pipeline as each stage lands: `working` from step 1, the matching checklist items checked at steps 2–4, `needs-attention` plus a one-line description on a failed test run or a cherry-pick conflict, `review` when the reviewer starts.

**Acceptance criteria you enforce before the review step:**

- PR diff file list matches the approved group exactly — nothing smuggled in, nothing missing.
- Full suite green in that worktree (see the actual output tail; on suspected resource contention, rerun serially before judging).
- Commits preserved individually (no squashing during extraction), messages intact.

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

When rejecting subagent output, the redo message must contain: the specific acceptance criterion missed, the evidence (test output, diff line, review finding), and what "done" looks like. After two failed redos on the same criterion, take over that step yourself and note the takeover in the progress file.
