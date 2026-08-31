---
name: orchestrate-agents-in-cmux
description: Orchestrate persistent Claude Code, Codex, and Cursor sessions in cmux, including launch, steering, callbacks, and supervision. Use when an agent should coordinate another coding agent in a cmux workspace.
---

# Orchestrate agents in cmux

Give each unit of work its own cmux workspace and each agent its own interactive tab. Keep the sessions visible so the user can inspect and steer them.

This skill owns cmux detection, session launch, identifiers, messaging, callbacks, supervision, and recovery. Calling skills own the delegated task, acceptance criteria, and result format. Keep those task rules out of this skill and keep cmux mechanics out of callers.

## Preconditions

Run the bundled live-membership probe:

```bash
python3 {skill-dir}/scripts/is_inside_cmux.py
```

Exit `0` means this process belongs to a live cmux terminal. Exit `1` means it does not. Exit `2` means detection failed; report the error or rerun the same probe from a context permitted to access the cmux socket instead of treating it as outside cmux.

Use `CMUX_WORKSPACE_ID` and `CMUX_SURFACE_ID` as targeting hints when present, not as presence checks. `cmux ping` proves only that the app is reachable. An `identify` result with `caller: null` describes focused UI context, not this process.

## File-first communication

- Put the detailed assignment and work plan in a brief. Send the agent only a short action and the absolute brief path.
- Give the agent a worklog path. Require its first action to create a meaningful entry, then append handoffs, state changes, surprises, discoveries, and plan deviations as they happen. Do not pre-create an empty worklog.
- Give the agent a separate result path. Require it to persist the final result there before sending a short completion message with the path.
- Record callback receipt and delivery evidence in the orchestrator's worklog; the child's result cannot report the outcome of a callback sent afterward.
- Keep `SendMessage`, `codex queue`, and cmux-typed messages to file references, state changes, questions, and short check-ins. Put complex instructions, findings, and reports in files.
- Unless the user chooses another location, keep briefs, addenda, worklogs, results, and handshake files under `~/.agents-orchestration/{repo}/{branch}/` (choose the appropriate files/dirs organization).

## Rules

- Only the designated controller for a workspace calls `cmux`. A calling workflow may designate a team lead as the controller for its member workspace. Controlled members never manage cmux.
- Claude Code and Codex may orchestrate. Treat Cursor as a controlled agent only.
- Use one workspace per unit of work and one tab, brief, worklog, and result file per agent assignment.
- Perform one cmux mutation per shell call. Require exit status `0`; parse JSON commands for their refs, and require `OK` from commands whose documented response is `OK`.
- Address workspaces and surfaces by typed refs, never bare numbers.
- Pass `--focus false`. Never select, focus, reorder, close, or repurpose the user's workspaces or tabs.
- Never terminate an agent. Relaunch a failed role in a new tab named `{role} (2)`.
- Treat callbacks and result files as evidence of completion. Use `cmux read-screen` only to launch, handle a visible prompt, or diagnose a stall.
- Before launching an externally hosted harness, obtain any required user authorization for the named service and scoped files during preflight.

## Required references

- Read [references/cmux-operations.md](references/cmux-operations.md) before creating, launching, supervising, or recovering sessions.
- Read [references/messaging.md](references/messaging.md) before the first cross-agent send or callback.
- Read [references/claude-message-protocol.md](references/claude-message-protocol.md) only when diagnosing or updating Claude's internal socket transport.

For ordinary sends to Claude, run [scripts/claude_queue.py](scripts/claude_queue.py); do not reimplement the protocol from the reference.

## Workflow

1. Create or select a workspace owned by this orchestration run.
2. Resolve and create the artifact directory using the location rule above.
3. Write each brief with the task, work plan, boundaries, acceptance checks, worklog path, result path, and callback contract. For a one-turn assignment, require any handshake and let the agent continue. If the assignment needs a later addendum, require a ready check-in and an ended turn, then send an explicit go-ahead before expecting work. Never ask an agent to poll inside an active turn.
4. Launch each agent in a dedicated tab. Record its Claude name and PID, Codex thread UUID, or Cursor chat UUID as applicable.
5. Send short file pointers and check-ins through the harness transport. Put detailed follow-ups in an addendum file first.
6. Supervise callbacks, worklog updates, result creation, and repository state. Inspect the cmux tab when progress stops.
7. Verify material claims independently before reporting completion.

## Transport selection

| Orchestrator | Controlled agent | Send | Return path |
| --- | --- | --- | --- |
| Claude | Claude | Native `SendMessage` | Result-path callback |
| Claude | Codex | `codex queue` | Result-path callback via `claude_queue.py` |
| Codex | Claude | `claude_queue.py` | Result-path callback via `codex queue` |
| Codex | Codex | `codex queue` | Result-path callback via `codex queue` |
| Claude or Codex | Cursor | cmux typing plus files | Result-path callback via the parent transport |

Do not start `codex app-server` for these flows. A normal Codex TUI accepts `codex queue`.
