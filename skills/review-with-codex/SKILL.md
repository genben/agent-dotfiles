---
name: review-with-codex
description: Run the codex CLI as an independent code reviewer on a diff, drive one session through review, validation, and rebuttal, and collect findings from a report file. Use when asked to review with codex, run codex as a second reviewer, or send findings to codex for validation.
---

# Review with codex

Run codex as an adversarial reviewer of a diff. One session carries the whole exchange: the review, then any follow-up (validating another reviewer's findings, defending its own against rejections). If `codex` isn't on PATH, tell the human and stop.

## Sandbox and permissions

- Pass no `--sandbox` flag. `~/.codex/config.toml` and the repo's `.codex/rules/*.rules` decide what codex may run; rules can allow test commands outside the sandbox, which is how the reviewer reaches the database and a browser. Anything uncovered raises an escalation that `approvals_reviewer` decides. Never use `--dangerously-bypass-approvals-and-sandbox`; `--approve-for-me` can't combine with `--sandbox`.
- Read `.codex/rules/` before writing the brief and tell the reviewer which check commands it can run. Without such rules, codex has no network and no database.
- Set effort with `-c model_reasoning_effort={low|medium|high|xhigh}`.
- Don't use `codex exec review`: it imposes its own report format and a tighter sandbox that can't reach the database.

## The brief

Keep the brief in a file; a generic brief returns generic findings. It must:

- Name the diff (`git diff {base}...{branch}`), the review dimensions, and what to attack in this diff specifically. Codex hunts for problems, not blesses the work.
- Allow running the suite, linters, type checker, any check in the repo's CLAUDE.md, and throwaway probes. Prohibit changing the code under review: no edits to tracked files, no commits, no pushes.
- State the production-path bar so codex self-filters: a finding names the production entry point and the input that reaches the defect, or labels itself theoretical.
- Name the absolute report path and the findings format, and make the report the final message (so `codex exec -o` captures it).
- For an interactive run, name an absolute thread-handshake file and require Codex to write `CODEX_THREAD_ID` there immediately after reading the brief.

Findings format, one `##` block per finding so later stages can refer to `codex-N` by id; omit fields that don't apply:

```markdown
## codex-3 — Export query drops the tenant filter
- severity: high
- category: correctness
- file: miarecweb/views/export.py:142
- evidence: `uv run pytest miarecweb/tests/functional_tests/test_export.py::test_scope` fails on this branch and passes on {base}
- detail: …
- suggested fix: …
```

Judge the report by its ids, evidence, and actionability; queue a correction when it falls short.

## Launching

Interactive TUI, in a terminal you keep open (a cmux or tmux tab); the session stays alive for follow-ups:

```bash
codex -c model_reasoning_effort=xhigh \
  "Read {brief-path} and follow it. Start with a tool call, not a reply."
```

Non-interactive, in the background. Pass the brief **on stdin**; `-o` captures the final message as the report:

```bash
codex exec -o {report-path} -c model_reasoning_effort=xhigh - < {brief-path} > {log-path} 2>&1
```

A backgrounded `codex exec` without stdin redirection hangs. Keep the log: `-o` writes nothing when a turn dies.

`codex exec` answers once and exits, so each follow-up is a fresh `codex exec` whose prompt carries the prior context (for a rebuttal: its original findings plus the rejections).

## Addressing the interactive session

- Wait for the non-empty thread-handshake file and record its UUID. Do not scrape Codex's database.
- Put every detailed follow-up in an addendum file. Require Codex to end its current turn, then send only the absolute addendum path with `codex queue --thread {thread-id} --message "Read {addendum-path}."`.
- Read responses from the named report files. Record callback receipt in the orchestrator worklog.
- If `codex queue` cannot update `~/.codex/state_*.sqlite`, retry from a context permitted to update Codex state. After interrupting a turn, use cmux typing as described by `orchestrate-agents-in-cmux`.

## Monitoring

A codex session is not a peer agent session (it never appears in `ListAgents`); check two signals:

- Process: `pgrep -f codex`.
- The report file's mtime.

An interactive session stays alive after answering; queue more work into it. A codex tab back at a shell prompt has exited; a finished run with no report died. Read its output before relaunching.

Relaunch after a crash or a sandbox denial, but not after a content refusal:

```
ERROR: This content was flagged for possible cybersecurity risk.
```

Codex aborts mid-turn and writes no report, even for a probe the brief authorized (a fuzz harness is enough), and the same brief reproduces it. Rewrite the probe as an ordinary test or give that dimension to another reviewer, and record which dimension went uncovered.
