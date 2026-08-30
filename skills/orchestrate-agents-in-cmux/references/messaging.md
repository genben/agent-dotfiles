# Agent messaging

All transports are asynchronous. A successful send proves delivery to an inbox, not that the receiving model processed or completed the request.

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

Codex exposes its thread UUID as `CODEX_THREAD_ID`. A newly launched child must publish it during its first tool call to a unique handshake file:

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

Create the chat first with `agent create-chat` and record its UUID. Give the brief absolute worklog and result paths plus the parent callback command. Cursor has no inbound queue transport in this workflow.

## Send to Codex

A normal interactive Codex TUI accepts:

```bash
codex queue --thread "{thread-uuid}" --message "{short-message-with-file-path}"
```

Use the explicit UUID, not a display name. The message starts a turn when Codex is idle or queues behind its current turn when busy.

## Send to Claude

Invoke the bundled helper by its resolved skill-relative path:

```bash
python3 {skill-dir}/scripts/claude_queue.py {claude-pid} "{short-message-with-file-path}"
```

It also reads the message from standard input and supports `--priority now`, `next`, and `later`. It reads the target inbox's `peerToken` from the target's key file; it does not need `CLAUDE_CODE_MESSAGING_TOKEN`.

The helper supports Claude's Unix socket transport on macOS and Linux. It omits `from` because Codex does not expose a Claude inbox. A zero exit status means the frames were written, not that Claude accepted or acted on them.

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
- First tool call: write CODEX_THREAD_ID to {child-thread-file}.
- Persist ongoing work in {worklog-file} and the final result in {result-file}.
- Send short check-ins and the final result path with:
  python3 {skill-dir}/scripts/claude_queue.py {parent-claude-pid} "{short-message-with-file-path}"
```

After the thread file appears, Claude sends follow-ups with `codex queue --thread ...`. Codex returns through `claude_queue.py`.

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

Give the child the parent thread UUID and a unique thread handshake file. Both sides send short pointers and check-ins with `codex queue --thread ...`. Give every child a distinct brief, worklog, result, and handshake file.

## Control Cursor

Put the assignment, absolute worklog and result paths, and parent callback command in its brief. Write detailed follow-ups to an addendum file, then type only its path into the cmux tab:

```bash
cmux send --surface {surface_ref} 'Read {addendum-path} and follow it.'
cmux send-key --surface {surface_ref} Enter
```

Cursor follow-ups become the next turn; there is no mid-turn steering. Require Cursor to write the result and run the callback command with its path. Verify the result independently. Use screen reads only for diagnosis.

## Recovery

- Missing Claude socket: restart that Claude session; the listener does not retry setup.
- Missing Codex handshake: inspect the tab, then send a direct prompt asking it to publish `CODEX_THREAD_ID`.
- Send succeeds but no callback: inspect the worklog, result file, and repository, then send a short state request.
- Transport unavailable: use cmux typing as recovery, not as the normal Claude or Codex channel.
- Process exited: relaunch in a new tab with a fresh identifier and recovery brief.
