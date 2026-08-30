---
name: review-with-claude
description: Run the claude CLI (Claude Code) as an independent code reviewer on a diff from any orchestrator, including codex; drive one session through review, validation, and rebuttal, and collect findings from a report file. Use when asked to review with claude, run claude as a second reviewer, or send findings to claude for validation.
---

# Review with claude

Run the claude CLI as an adversarial reviewer of a diff. One session carries the whole exchange: the review, then any follow-up (validating another reviewer's findings, defending its own against rejections). If `claude` isn't on PATH, tell the human and stop.

## Model and permissions

- Pass `--permission-mode auto`: a classifier answers permission requests, so a headless run never stalls; a denied call just fails and the reviewer works around it. Never use `--dangerously-skip-permissions`.
- The default model is fine; add `--model {alias-or-id}` when the user names one.
- The repo's CLAUDE.md loads automatically, so the reviewer already knows the repo's check commands; the brief only restricts, never re-teaches them.

## The brief

Follow review-with-codex for the brief's content: the diff, the review dimensions, what to attack, the allowed checks, the no-edits rule, the production-path bar, and the findings format (ids `claude-{model}-N`, such as `claude-opus-3` or `claude-fable-2`; the model qualifier keeps parallel claude reviewers from colliding). Report capture depends on the launch form: headless `-p` prints the final message to stdout, so don't name a report path in the brief; an interactive session has no stdout to redirect, so its brief must name the report path. No marker line is needed; the session is addressed by `--name` or a pre-chosen session id.

## Launching

Interactive TUI, in a terminal you keep open (a cmux or tmux tab, per the cmux skill); the session stays alive for follow-ups:

```bash
claude --name {name} --session-id "$session" --permission-mode auto "Read {brief-path} and follow it."
```

`--name` makes the session addressable from a Claude Code orchestrator; include the model in it (`claude-opus-reviewer`, `claude-fable-reviewer`) so parallel claude sessions resolve unambiguously in `ListAgents`. `--session-id` (a pre-generated UUID, as below) keys the transcript for monitoring; record which UUID belongs to which reviewer.

Non-interactive, in the background (a long review takes minutes); choose the session id first so it is known before the run starts, then send the brief in print mode from the repo root. Each `-p` call blocks until the turn finishes and prints the final message to stdout, so redirect stdout to the report path:

```bash
session=$(uuidgen | tr 'A-Z' 'a-z')   # record this id
claude -p --session-id "$session" --permission-mode auto \
  "$(cat {brief-path})" > {report-path}
```

Headless `-p` never shows the trust dialog; the interactive form can stop on one in an unfamiliar directory (see the cmux skill).

Sessions are stored per directory (`~/.claude/projects/{cwd, slashes as dashes}/{session}.jsonl`, keyed by the resolved path, so `/private/tmp/...` on macOS): run every call on a session from the same repo root.

## Follow-ups

- **Interactive session, orchestrator is a Claude Code session**: find the exact `--name` in `ListAgents` and send follow-ups with `SendMessage(to: "{name}", notify_when_idle: true)`; the session keeps its context across review, validation, and rebuttal.
- **Interactive session, any other orchestrator**: type the follow-up into the tab (`cmux send` + `send-key Enter`); read results from the report files the briefs name.
- **Headless**: send each follow-up as another `-p` call resuming the same session; context persists across turns:

  ```bash
  claude -p --resume "$session" --permission-mode auto "{message}" > {reply-path}
  ```

  Turns are strictly request/response: wait for the current call to exit before sending the next. Don't pass `--fork-session`; a fork answers from the history but stops sharing a session with later follow-ups.

## Monitoring

From a Claude Code orchestrator, an interactive session shows in `ListAgents` (busy or idle). Everywhere else, check three signals; both forms carry the session id on the command line:

- Process: `pgrep -f "$session"`.
- The report file's size and mtime (headless stdout is written when the turn completes).
- Transcript growth: the mtime of `~/.claude/projects/{cwd-slug}/{session}.jsonl` advances while the turn runs.

A finished run with an empty report died; read stderr before relaunching. The session survives the process, so relaunching with `--resume "$session"` keeps prior context.
