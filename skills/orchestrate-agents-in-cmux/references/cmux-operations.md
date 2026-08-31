# cmux operations

Use these commands only after the entrypoint's precondition checks pass. Run each cmux mutation in its own shell call.

## Workspace layout

When one task spans several workspaces, create a group and leave its anchor workspace empty:

```bash
cmux workspace-group create --name "{task}" --cwd "{dir}" --json
```

Pass `--cwd` even though the anchor stays empty. Without it, cmux can inherit an unrelated focused workspace directory.

Create one workspace per worktree or independent unit:

```bash
cmux workspace create --name "{name}" --cwd "{dir}" --focus false \
  --group workspace_group:N --group-placement end --json
```

Record the returned `workspace_ref` and its UUID. Filter the list instead of loading every workspace:

```bash
cmux workspace list --json | jq '.workspaces[] | select(.ref == "{workspace_ref}") | {ref,id,title,current_directory}'
```

The UUID survives an app restart. The workspace's `--cwd` applies only to its first tab; pass `--working-directory` for later tabs.

Create agent tabs one mutation at a time. Keeping the launch command out of layout JSON avoids nested quoting errors:

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
  --add-dir "{artifact-dir}" \
  "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

Codex:

```bash
codex --approve-for-me -C "{worktree}" --add-dir "{artifact-dir}" \
  "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

The Codex recipe above was verified with Codex 0.151.0. `--approve-for-me` selects the workspace-write sandbox; do not combine it with `--sandbox`. If automatic review is inappropriate, use the compatible pair `--sandbox workspace-write --ask-for-approval never` and expect cmux or callback operations outside the sandbox to fail. Check `codex --help` when the installed version differs.

Choose the narrowest roots that permit the worktree and exact artifact directory. For a source-review-only task, prohibit source edits in the brief. Treat startup as incomplete until the agent writes its first meaningful worklog entry. If that write fails, relaunch with corrected writable roots.

Cursor:

```bash
agent --resume="{recorded-chat-uuid}" --model {model} --auto-review \
  "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

Run `agent create-chat` in the orchestrator's own shell first and record the returned UUID before typing the launch command into the target tab. Verify the selected model with `agent models`. The brief must name absolute worklog and result paths because a TUI has no redirected stdout. Never run concurrent `agent -p` calls against its open TUI chat.

## Confirm startup

```bash
cmux read-screen --workspace {workspace_ref} --surface {surface_ref} --lines 20
```

If the screen visibly shows a first-launch trust prompt with its accept option selected, send Enter and inspect again. Never send Enter speculatively; another dialog may be waiting.

## Status

Set status only on workspaces created by this run:

```bash
cmux workspace status set <todo|working|review|needs-attention|done> --workspace {workspace_ref}
```

Status overrides may auto-clear when cmux infers a different state. Use `needs-attention` only when work is stopped pending a human action. Do not manage `cmux todo`; that checklist belongs to the user unless the user explicitly asks the agent to update it.

Use descriptions only for state the workspace status cannot express, then clear them:

```bash
cmux workspace-action --action set-description --description "{one line}" --workspace {workspace_ref}
cmux workspace-action --action clear-description --workspace {workspace_ref}
```

## Supervision

At least every five minutes, check each working agent:

1. Compare the worklog mtime and size with the previous check; check whether the separate result file exists.
2. Compare relevant repository state with the previous check.
3. Ask for state when the agent is idle without a result file.
4. If a busy agent is unchanged across two checks, inspect its recorded surface and send a progress request. Repeated self-polling or repeated waiting is not progress. If it reports a hung command, tell it to interrupt and retry.
5. If the terminal visibly exited or the surface is unreachable and no other signal shows progress, open a new `{role} (2)` tab with a recovery brief describing verified completed work and remaining work.

For Claude, inspect native peer status, worklog, and result. For Codex, inspect thread callbacks, worklog, and result. For Cursor, inspect the recorded chat UUID, worklog, and result. Use `cmux read-screen` to diagnose a stalled tab. `cmux surface-health` returning `in_window=false` does not prove the terminal is dead.

Interrupt a visibly stuck terminal with `cmux send-key ... Escape`; `C-c` is not a valid key name. After interrupting Codex, wait for a visible `Ready` prompt. If queued messages do not start, type the addendum pointer through cmux and press Enter instead of trusting the old queue.

## After a cmux restart

Surviving tabs may be detached dead terminals. If `read-screen` fails, `surface-health` can provide supplementary placement information:

```bash
cmux surface-health --workspace {workspace_ref}
```

Do not infer death from `in_window=false`; live TUI tabs can report it. Relaunch only when the recorded surface is unreachable or visibly exited and callbacks, worklogs, and results show no continuing progress. Leave the old tab in place and refresh the relaunched agent's identifiers.
