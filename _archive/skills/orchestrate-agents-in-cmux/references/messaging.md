# Agent messaging

All transports are asynchronous. A successful send proves delivery to an inbox, not that the receiving model processed or completed the request.

Use one turn when the complete assignment is already in the brief. The child publishes any required handshake and continues working. Use a ready callback and a separate turn only when the parent must supply a later addendum. After readiness, the parent must queue that addendum or an explicit go-ahead before it waits for a result.

Follow the file-first contract in `SKILL.md`. Every assignment has a brief, a live worklog, and a separate final result file. Transport messages contain only a task identifier, short state or question, and an absolute file path. Write a detailed follow-up to an addendum file before notifying the agent.

Resolve orchestration file paths using the location rule in `SKILL.md`. Do not place Claude tokens in prompts, arguments, or those files.

## Identifiers

### Claude parent

A Claude parent gives a Codex child its own PID:

```bash
basename "$CLAUDE_CODE_MESSAGING_SOCKET" .sock
```

If that variable is absent or the session registry lacks `messagingSocketPath`, restart Claude. Its inbox setup is one-time at process startup.

For Claude-to-Claude messaging, record the parent's exact native peer name and give it to the child.

### Codex parent or child

Codex exposes its thread UUID as `CODEX_THREAD_ID`. After reading its brief, a newly launched child must publish it before substantive work to a unique handshake file:

```bash
printf '%s\n' "$CODEX_THREAD_ID" > {thread-file}
```

Wait with a bounded poll for a non-empty file. Prefer this handshake over scraping Codex's database.

### Claude child

Launch Claude with a unique `--name`. A Claude parent addresses it by that name. A Codex parent resolves its PID with the bundled helper, which requires one matching live process and socket:

```bash
python3 {skill-dir}/scripts/find_claude_pid.py "{unique-name}"
```

### Cursor child

Create the chat from the orchestrator shell first with `agent create-chat` and record its UUID. Give the brief absolute worklog and result paths plus the parent callback command. Cursor has no inbound queue transport in this workflow.

Verify the exact callback command in the child environment before launch. `codex queue` needs the Codex CLI and writable Codex state. `claude_queue.py` needs `python3`, the bundled script, and the target Claude socket and key. If the callback cannot work, omit it and make the parent monitor the worklog and result file directly.

## Send to Codex

A normal interactive Codex TUI accepts:

```bash
codex queue --thread "{thread-uuid}" --message "{short-message-with-file-path}"
```

Use the explicit UUID, not a display name. The message starts a turn when Codex is idle or queues behind its current turn when busy.

`codex queue` updates Codex's local state. In a restricted environment it may fail with `attempt to write a readonly database` for `~/.codex/state_*.sqlite`; retry the same command from a context permitted to update that state.

Never tell a Codex worker to poll while awaiting a queued follow-up. For a staged assignment, require it to send a ready callback and end the current turn. The parent then queues the addendum pointer before expecting work or a result. If a busy turn is interrupted with Escape, queued messages may not start afterward; once the TUI visibly returns to `Ready`, use cmux typing as recovery.

## Send to Claude

Invoke the bundled helper by its resolved skill-relative path:

```bash
python3 {skill-dir}/scripts/claude_queue.py {claude-pid} "{short-message-with-file-path}"
```

It also reads the message from standard input and supports `--priority now`, `next`, and `later`. It reads the target inbox's `peerToken` from the target's key file; it does not need `CLAUDE_CODE_MESSAGING_TOKEN`.

The helper supports Claude's Unix socket transport on macOS and Linux. It omits `from` because Codex does not expose a Claude inbox. A zero exit status means the frames were written, not that Claude accepted or acted on them.

Claude may render a helper-delivered message as coming from another Claude session and suggest replying to its peer address. When the parent is Codex, the helper omits that reply address. The child must ignore the generic peer-reply suggestion and use the callback command in its brief.

## Claude starts Claude

1. Record the parent's exact native peer name.
2. Launch the child with a unique `--name`. Put the parent name and orchestration file paths in its brief.
3. Use native `SendMessage` for short file pointers and check-ins.
4. Require the child to write its result, then reply with the result path.

Do not use the socket helper between two Claude sessions; native messaging supplies reply addressing and delivery state.

## Claude starts Codex

Put this callback contract in the Codex brief:

```text
Parent callback
- Claude PID: {parent-claude-pid}
- After reading this brief, immediately write CODEX_THREAD_ID to {child-thread-file} before substantive work.
- Persist ongoing work in {worklog-file} and the final result in {result-file}.
- Send short check-ins and the final result path with:
  python3 {skill-dir}/scripts/claude_queue.py {parent-claude-pid} "{short-message-with-file-path}"
```

After the thread file appears, Claude sends follow-ups with `codex queue --thread ...`. Codex returns through `claude_queue.py`. For a one-turn assignment, Codex continues after the handshake. For a staged assignment, Codex sends a ready callback and ends its turn; Claude must then queue the next addendum or an explicit go-ahead.

## Codex starts Claude

Put this callback contract in the Claude brief:

```text
Parent callback
- Codex thread: {parent-codex-thread}
- Persist ongoing work in {worklog-file} and the final result in {result-file}.
- Send short check-ins and the final result path with:
  codex queue --thread "{parent-codex-thread}" --message "{short-message-with-file-path}"
```

Resolve the child's PID with `find_claude_pid.py` after its live registry entry and socket appear. Codex sends follow-ups through `claude_queue.py`; Claude returns through `codex queue`.

## Codex starts Codex

Give the child the parent thread UUID and a unique thread handshake file. Both sides send short pointers and check-ins with `codex queue --thread ...`. Give every child a distinct brief, worklog, result, and handshake file. In a staged assignment, end each turn before waiting for the next queued addendum and require the sender to start the next turn explicitly.

## Control Cursor

Put the assignment, absolute worklog and result paths, and parent callback command in its brief. Write detailed follow-ups to an addendum file, then type only its path into the cmux tab:

```bash
cmux send --surface {surface_ref} 'Read {addendum-path} and follow it.'
cmux send-key --surface {surface_ref} Enter
```

Cursor follow-ups become the next turn; there is no mid-turn steering. Require Cursor to write the result and run the callback command with its path. Verify the result independently. Use screen reads only for diagnosis.

## Recovery

- Missing Claude socket: restart that Claude session; the listener does not retry setup.
- Missing Codex handshake: inspect the named surface, then run `cmux send --surface {surface_ref} 'Publish CODEX_THREAD_ID to {thread-file}.'` followed by `cmux send-key --surface {surface_ref} Enter`.
- Send succeeds but no callback: inspect the worklog, result file, and repository, then send a short state request.
- Complete result but callback cannot write Codex state: record the callback failure and accept parent-side result monitoring as the handoff. Do not relay the callback through another child.
- Claude is stuck in a wait after a normal-priority correction appears on screen: resend the same file pointer with `python3 {skill-dir}/scripts/claude_queue.py --priority now {claude-pid} "{same-file-pointer}"`. Use immediate priority only for a verified stall.
- Codex turn interrupted: after the surface visibly returns to `Ready`, use cmux typing for the recovery pointer; do not assume an old or newly queued message will auto-start.
- Transport unavailable: use cmux typing as recovery, not as the normal Claude or Codex channel.
- Process exited: relaunch in a new tab with a fresh identifier and recovery brief.
