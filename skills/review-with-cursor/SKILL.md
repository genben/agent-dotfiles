---
name: review-with-cursor
description: Run the cursor CLI (agent) as an independent code reviewer on a diff, drive one chat through review, validation, and rebuttal, and collect findings from a report file. Use when asked to review with cursor, run cursor or kimi as a second reviewer, or send findings to cursor for validation.
---

# Review with cursor

Run the cursor CLI as an adversarial reviewer of a diff. One chat carries the whole exchange: the review, then any follow-up (validating another reviewer's findings, defending its own against rejections). If `agent` isn't on PATH, tell the human and stop.

## Model and permissions

- Default model: `--model kimi-k3-max`. Verify the id with `agent models` before launch.
- Pass `--auto-review` to use a classifier to automatically approve every tool call when running interactively in cmux tab. For in print mode, pass `--force` (yolo mode).

## The brief

Follow review-with-codex for the brief's content: the diff, the review dimensions, what to attack, the allowed checks, the no-edits rule, the production-path bar, and the findings format (ids `cursor-N`). Report capture depends on the launch form: in `-p` mode the entire final message is the report, taken from stdout, so don't name a report path in the brief (the shell owns that file via `>`, and a reviewer writing the same path mid-turn splices with the final stdout write); a TUI session has no stdout to redirect, so its brief must name the report path. No marker line is needed; the chat id is created explicitly before launch.

## Launching

Create the chat first so the id is known before the run starts; both forms run from the repo root:

```bash
chat=$(agent create-chat)   # record this id
```

Interactive TUI, in a terminal you keep open (a cmux or tmux tab, per the `orchestrate-agents-in-cmux` skill); the session stays alive for follow-ups:

```bash
agent --resume="$chat" --model kimi-k3-max --auto-review \
  "Read {brief-path} and follow it."
```

Non-interactive, in the background (a long review takes minutes). Each `-p` call blocks until the turn finishes and prints the final message to stdout, so redirect stdout to the report path:

```bash
agent -p --resume="$chat" --model kimi-k3-max --force \
  "Read {brief-path} and follow it." > {report-path}
```

Headless `-p` never prompts for trust; the TUI can stop on a trust prompt in an unfamiliar workspace (add `--trust`, or clear it per the `orchestrate-agents-in-cmux` skill).

Conversation state lives server-side, keyed by the chat id; `~/.cursor/chats/<cwd-hash>/<chat-id>/` is only a per-cwd local cache. So `-p` follow-ups keep context from any cwd, but the TUI and `meta.json` hydrate from the cache: open the TUI from the same directory as `create-chat`, and a resume from another cwd creates a second cache dir for the same id.

## Follow-ups

- **TUI session**: write the detailed follow-up to an addendum file, then type only `Read {addendum-path} and follow it.` into the tab with `cmux send` plus Enter. Cursor queues typed input as the next turn when busy; it does not steer the active turn. Never mix concurrent `-p` calls into a chat a TUI has open.
- **Headless**: send each follow-up as another `-p` call on the same chat id; context persists across turns:

  ```bash
  agent -p --resume="$chat" --model kimi-k3-max --force \
    "Read {addendum-path} and follow it." > {reply-path}
  ```

Turns are strictly request/response: there is no mid-turn steering. A typed TUI follow-up becomes the next turn; a headless follow-up waits for the current process to exit.

## Monitoring

A cursor chat is not a peer agent session; check three signals:

- Process: `pgrep -f "$chat"` (the chat id is on the command line in both forms).
- The report file's size and mtime (stdout is written when the turn completes).
- Chat activity: `updatedAtMs` in `~/.cursor/chats/*/$chat/meta.json`. If the glob matches two cache dirs, trust the one whose `updatedAtMs` is moving, or skip meta and rely on pgrep plus the report file.
- Live internals mid-turn: tool calls and results append to the active cache's `store.db` as JSON blobs (`sqlite3 store.db "select cast(data as text) from blobs;"`); reasoning is encrypted. For a structured live feed, launch with `--output-format stream-json`.

A finished run with an empty report died; read stderr before relaunching. The chat survives the process, so relaunching with `--resume="$chat"` keeps prior context.
