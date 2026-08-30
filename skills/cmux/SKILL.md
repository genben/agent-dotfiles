---
name: cmux
description: Orchestrate interactive agent sessions in cmux with a dedicated workspace per unit of work and a dedicated tab per agent (claude, codex, cursor), plus workspace status, checklist, and supervision. Use when running subagents inside cmux, opening cmux workspaces or tabs, or launching claude, codex, or cursor sessions the user can watch.
---

# cmux

Run each subagent as an interactive session in its own cmux tab, grouped into one workspace per unit of work (a PR, a task), so the user can watch any session live and type into it.

## Detect the mode

```bash
echo "$CMUX_WORKSPACE_ID"
command -v cmux
```

Both non-empty means cmux mode. Keep the two commands separate: a worktree-isolated session refuses the chained form, and the refusal looks like cmux is missing.

Outside cmux, skip every `cmux` command and run subagents in-process through the Agent tool; briefs, acceptance criteria, and redo policy stay identical, except that an in-process subagent cannot write a report file.

## Rules

- Only you, the orchestrator, call `cmux`; subagents never do.
- One cmux mutation at a time (concurrent ones corrupt the sidebar layout): wait for its `OK`, prefer the atomic forms (`workspace create --layout`, `todo set`). One `cmux` call per Bash call: a worktree-isolated session refuses chained commands, and a broken `&&` chain leaves the sidebar half-updated.
- Address by ref (`workspace:64`, `surface:183`), never by bare number, and never from a loop variable holding more than one field.
- Never take focus: pass `--focus false`; never run `workspace select`, `focus-pane`, or `focus-panel`.
- Never close a workspace or a tab, never terminate an agent, finished or not. To rerun an agent, open a **new** tab named `{role} (2)`, and so on.
- Never reorder existing workspaces or groups; everything you create goes to the bottom of the sidebar.
- Touch only workspaces you create. Leave the user's workspaces, statuses, and checklists alone.

## One group per task

When the task spans several workspaces, group them:

```bash
cmux workspace-group create --name "{task}" --json    # → workspace_group:N
cmux workspace-group move workspace_group:N --to-index 999
```

Group creation also creates an anchor workspace whose row is the group header: leave it empty. Groups do not nest, so the group is top-level. Record the group and anchor refs.

## One workspace per unit of work

Give the workspace a real directory (create the worktree first if the work needs one):

```bash
cmux workspace create --name "{name}" --cwd "{dir}" --focus false \
  --group workspace_group:N --group-placement end --json      # → workspace_ref
```

- Record `workspace_ref` and the workspace UUID (`workspaces[].id` from `cmux workspace list --json`; it survives an app restart).
- The workspace's `--cwd` seeds only the first tab; give every later tab its own `--working-directory`.
- Created a workspace by mistake? Rename it (`cmux workspace rename {ref} --title "{name}"`), never close it.

## One tab per agent

The first agent rides the workspace's own tab, created in one mutation with `--layout`:

```bash
cmux workspace create --name "{name}" --cwd "{dir}" --focus false \
  --group workspace_group:N --group-placement end --json \
  --layout '{"pane":{"surfaces":[{"type":"terminal","command":"{agent command}"}]}}'
```

Every later agent gets its own tab:

```bash
cmux new-surface --type terminal --workspace {workspace_ref} \
  --working-directory "{dir}" --focus false               # → surface_ref
cmux rename-tab --workspace {workspace_ref} --surface {surface_ref} "{role}"
cmux send --surface {surface_ref} '{agent command}'
cmux send-key --surface {surface_ref} Enter
```

- `cmux send` types the text; `send-key Enter` submits it.
- Name tabs after roles (`implementer`, `reviewer`, `codex reviewer`); one session serves all of that role's rounds.
- Confirm the session came up with `cmux read-screen --workspace {workspace_ref} --surface {surface_ref} --lines 20`. If the screen shows a first-launch trust prompt ("Do you trust …" / "Workspace Trust Required"; rare, since a trusted repo covers its worktrees), its accept option is preselected: send `cmux send-key --workspace {workspace_ref} --surface {surface_ref} Enter`, then read the screen again to confirm the session is ready. Never send Enter without seeing the prompt — a stalled tab may be a different dialog (login, update, approval).

### Agent commands

**claude** — launch with `--name` (so you can address it) and `--permission-mode auto` (so it never stops for approval); add `--model` and `--effort` per the role:

```bash
claude --name {name} --model {model} --effort {level} --permission-mode auto \
  "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

Find its exact `--name` in `ListAgents`; drive the redo loop with `SendMessage(to: "{name}", notify_when_idle: true)`.

**codex** — the interactive TUI per the review-with-codex skill (marker line in the brief, thread id from sqlite, `codex queue` for follow-ups):

```bash
codex --approve-for-me "$(cat {brief-path})"
```

**cursor** — create the chat first so the id is known, then open the TUI on it (model and permissions per the review-with-cursor skill):

```bash
chat=$(agent create-chat)    # record this id
agent --resume="$chat" --model kimi-k3-max --auto-review "$(cat {brief-path})"
```

A TUI tab has no stdout to redirect, so unlike `-p` mode the brief must name the report path. Send follow-ups by typing into the tab (`cmux send` + `send-key Enter`), never with concurrent `-p` calls on the same chat.

## Talking to the agents

Keep each brief in a file and give the tab a one-line command that reads it. Every brief must require the agent to write its report to an absolute path you name, and to message you when it finishes (claude replies to the name in the `from` attribute of your message; codex and cursor can't message you, so watch their report files).

That rule covers tab sessions only. An in-process subagent is blocked from writing a report file, so brief it to return the report as its final message; ask it for a file and it goes idle with the work done and nothing delivered.

Verify from report files and your own commands, never from an agent's prose summary or its screen; `cmux read-screen` is for diagnosing a stuck session.

## Status and checklist

The workspace checklist belongs to the user: set one only on workspaces you created, as part of a workflow the user asked for, and never edit an item you didn't create.

```bash
cmux workspace status set <todo|working|review|needs-attention|done> --workspace {workspace_ref}
cmux todo set '[{"text":"…","state":"pending"},{"text":"…","state":"in-progress"}]' --workspace {workspace_ref}
cmux todo list --workspace {workspace_ref}
```

Item state is `pending`, `in-progress`, or `completed`; the workspace status vocabulary is a separate set and `todo` rejects it.

Write the checklist once with `todo set` at workspace creation, then advance items with `cmux todo start <n>` and `cmux todo check <n>` as each stage changes, never in one batch at the end: the checklist is the user's live view. `needs-attention` means "stopped until a human acts", nothing else.

Use the description only for what status and checklist can't express, and clear it once resolved:

```bash
cmux workspace-action --action set-description --description "{one line}" --workspace {workspace_ref}
cmux workspace-action --action clear-description --workspace {workspace_ref}
```

## Supervising tab sessions

Tab sessions don't notify you the way in-process subagents do; arm a heartbeat before dispatching the first one, and stop it with `TaskStop` when the last agent finishes:

```
Monitor(command: 'while true; do echo "watchdog tick"; sleep 240; done', persistent: true)
```

Let the heartbeat do the waiting; a chained `sleep` is blocked. To block on a condition, use `Monitor` with an `until` loop.

On each tick, for every agent still working:

1. `ListAgents`: listed, busy or idle? codex and cursor sessions never appear there; check them per their skills (process, thread or chat progress, report file).
2. Compare the report's mtime and the working directory's git state (`git log --oneline -1`, `git status --porcelain`) against the previous tick.
3. Idle with no report: ask it for its current state.
4. Busy but unchanged across two ticks: message it; if it waits on a hung command, tell it to interrupt and retry. Interrupt a tab with `send-key … Escape` (`C-c` is not a valid key name).
5. Gone from `ListAgents`: open a new tab, `{role} (2)`, and launch a fresh agent with a brief stating what's done and what remains.

### Idle without acting

A tab session answers in prose, makes no tool call, and goes idle. Check the worktree's git state, then re-message with "start with a tool call, not a reply". Verify every claim against git, allowing for the reverse race: a commit can land seconds after you look.

### After a cmux restart

Tabs survive an app restart as dead terminals, and every `read-screen` fails with `internal_error: Failed to read terminal text`. Confirm with `cmux surface-health --workspace {workspace_ref}`: `in_window=false` on every surface means detached, not stuck.

Leave the dead tabs and relaunch each agent per step 5. Your own session name changes across a restart, so re-read it from `ListAgents` before briefing anyone to message you.
