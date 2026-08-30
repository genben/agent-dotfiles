# cmux operations

Use these commands only after the entrypoint's precondition checks pass. Run each cmux mutation in its own shell call.

## Workspace layout

When one task spans several workspaces, create a group and leave its anchor workspace empty:

```bash
cmux workspace-group create --name "{task}" --json
cmux workspace-group move workspace_group:N --to-index 999
```

Create one workspace per worktree or independent unit:

```bash
cmux workspace create --name "{name}" --cwd "{dir}" --focus false \
  --group workspace_group:N --group-placement end --json
```

Record the returned `workspace_ref` and the workspace UUID from `cmux workspace list --json`. The UUID survives an app restart. The workspace's `--cwd` applies only to its first tab; pass `--working-directory` for later tabs.

Create the first agent atomically with its workspace when practical:

```bash
cmux workspace create --name "{name}" --cwd "{dir}" --focus false \
  --group workspace_group:N --group-placement end --json \
  --layout '{"pane":{"surfaces":[{"type":"terminal","command":"{agent command}"}]}}'
```

Create later agent tabs one mutation at a time:

```bash
cmux new-surface --type terminal --workspace {workspace_ref} \
  --working-directory "{dir}" --focus false
cmux rename-tab --workspace {workspace_ref} --surface {surface_ref} "{role}"
cmux send --surface {surface_ref} '{agent command}'
cmux send-key --surface {surface_ref} Enter
```

Name tabs after roles. Keep one session for all rounds of that role.

## Launch commands

Claude Code:

```bash
claude --name {unique-name} --model {model} --effort {level} --permission-mode auto \
  "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

Codex:

```bash
codex --approve-for-me "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

Cursor:

```bash
chat=$(agent create-chat)
agent --resume="$chat" --model kimi-k3-max --auto-review \
  "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

Record the Cursor chat UUID before launch. The brief must name absolute worklog and result paths because a TUI has no redirected stdout. Never run concurrent `agent -p` calls against its open TUI chat.

## Confirm startup

```bash
cmux read-screen --workspace {workspace_ref} --surface {surface_ref} --lines 20
```

If the screen visibly shows a first-launch trust prompt with its accept option selected, send Enter and inspect again. Never send Enter speculatively; another dialog may be waiting.

## Status and checklist

Set status and checklists only on workspaces created by this run:

```bash
cmux workspace status set <todo|working|review|needs-attention|done> --workspace {workspace_ref}
cmux todo set '[{"text":"…","state":"pending"},{"text":"…","state":"in-progress"}]' --workspace {workspace_ref}
cmux todo start <n> --workspace {workspace_ref}
cmux todo check <n> --workspace {workspace_ref}
```

Checklist item states are `pending`, `in-progress`, and `completed`; workspace statuses use a different vocabulary. Advance items when stages change so the sidebar remains a live view. Use `needs-attention` only when work is stopped pending a human action.

Use descriptions only for state the checklist cannot express, then clear them:

```bash
cmux workspace-action --action set-description --description "{one line}" --workspace {workspace_ref}
cmux workspace-action --action clear-description --workspace {workspace_ref}
```

## Supervision

At least every five minutes, check each working agent:

1. Confirm the process or registered session is alive.
2. Compare the worklog mtime and size with the previous check; check whether the separate result file exists.
3. Compare relevant repository state with the previous check.
4. Ask for state when the agent is idle without a result file.
5. If a busy agent is unchanged across two checks, send a progress request. If it reports a hung command, tell it to interrupt and retry.
6. If the session is gone, open a new `{role} (2)` tab with a recovery brief describing verified completed work and remaining work.

For Claude, inspect native peer status, worklog, and result. For Codex, inspect its process, thread callback, worklog, and result. For Cursor, inspect its process, chat cache timestamp, worklog, and result. An empty Cursor result after process exit means it died before reporting.

Interrupt a stuck terminal with `cmux send-key ... Escape`; `C-c` is not a valid key name.

## After a cmux restart

Surviving tabs may be detached dead terminals. If `read-screen` fails, run:

```bash
cmux surface-health --workspace {workspace_ref}
```

When every surface reports `in_window=false`, leave the dead tabs and relaunch agents in new tabs. Refresh Claude names and all callback identifiers after relaunch.
