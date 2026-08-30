---
name: review-with-cursor
description: Run the cursor CLI (agent) as an independent code reviewer on a diff, drive one chat through review, validation, and rebuttal, and collect findings from a report file. Use when asked to review with cursor, run cursor or grok as a second reviewer, or send findings to cursor for validation.
---

# Review with cursor

Run the cursor CLI as an adversarial reviewer of a diff. One chat carries the whole exchange: the review, then any follow-up (validating another reviewer's findings, defending its own against rejections). If `agent` isn't on PATH, tell the human and stop.

## Model and permissions

- Default model: `--model cursor-grok-4.6-xhigh`. Verify the id with `agent --list-models` if the run rejects it.
- Pass `--force`: auto-approves every tool call unless `~/.cursor/cli-config.json` `permissions.deny` blocks it (`--yolo` is an alias for it). Don't pass `--auto-review` in print mode; it prompts for unsafe calls and a headless run can't answer, and it hard-conflicts with `--force`.
- Read `.cursor/rules/` before writing the brief and tell the reviewer which check commands it can run.

## The brief

Follow review-with-codex for the brief's content: the diff, the review dimensions, what to attack, the allowed checks, the no-edits rule, the production-path bar, and the findings format (ids `cursor-N`). Report capture depends on the launch form: in `-p` mode the entire final message is the report, taken from stdout, so don't name a report path in the brief (the shell owns that file via `>`, and a reviewer writing the same path mid-turn splices with the final stdout write); a TUI session has no stdout to redirect, so its brief must name the report path. No marker line is needed; the chat id is created explicitly before launch.

## Launching

Create the chat first so the id is known before the run starts; both forms run from the repo root:

```bash
chat=$(agent create-chat)   # record this id
```

Interactive TUI, in a terminal you keep open (a cmux or tmux tab, per the cmux skill); the session stays alive for follow-ups:

```bash
agent --resume="$chat" --model cursor-grok-4.6-xhigh --force "$(cat {brief-path})"
```

Non-interactive, in the background (a long review takes minutes). Each `-p` call blocks until the turn finishes and prints the final message to stdout, so redirect stdout to the report path:

```bash
agent -p --resume="$chat" --model cursor-grok-4.6-xhigh --force \
  "$(cat {brief-path})" > {report-path}
```

Headless `-p` never prompts for trust; the TUI can stop on a trust prompt in an unfamiliar workspace (add `--trust`, or clear it per the cmux skill).

Conversation state lives server-side, keyed by the chat id; `~/.cursor/chats/<cwd-hash>/<chat-id>/` is only a per-cwd local cache. So `-p` follow-ups keep context from any cwd, but the TUI and `meta.json` hydrate from the cache: open the TUI from the same directory as `create-chat`, and a resume from another cwd creates a second cache dir for the same id.

## Follow-ups

- **TUI session**: type the follow-up into the tab (`cmux send` + `send-key Enter`); read results from the report files the briefs name. Never mix concurrent `-p` calls into a chat a TUI has open.
- **Headless**: send each follow-up as another `-p` call on the same chat id; context persists across turns:

  ```bash
  agent -p --resume="$chat" --model cursor-grok-4.6-xhigh --force "{message}" > {reply-path}
  ```

Turns are strictly request/response in both forms: there is no queue and no mid-turn steering. Wait for the current turn to finish before sending the next; a steering message becomes the next turn's prompt.

## Monitoring

A cursor chat is not a peer agent session; check three signals:

- Process: `pgrep -f "$chat"` (the chat id is on the command line in both forms).
- The report file's size and mtime (stdout is written when the turn completes).
- Chat activity: `updatedAtMs` in `~/.cursor/chats/*/$chat/meta.json`. If the glob matches two cache dirs, trust the one whose `updatedAtMs` is moving, or skip meta and rely on pgrep plus the report file.
- Live internals mid-turn: tool calls and results append to the active cache's `store.db` as JSON blobs (`sqlite3 store.db "select cast(data as text) from blobs;"`); reasoning is encrypted. For a structured live feed, launch with `--output-format stream-json`.

A finished run with an empty report died; read stderr before relaunching. The chat survives the process, so relaunching with `--resume="$chat"` keeps prior context.
