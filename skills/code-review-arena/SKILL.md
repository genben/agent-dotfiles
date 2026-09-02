---
name: code-review-arena
description: Review a PR, diff, branch, or working tree with one or more independent Claude Code, Codex, or Cursor reviewers, then validate and arbitrate their findings. Use when asked to run a review arena, review with multiple models, or review with Claude, Codex, Cursor, or Kimi.
---

# Code review arena

Run independent reviewers, validate their findings, and deliver one evidence-backed report. Reviewers do not edit the code under review.

## Select the roster

| Id prefix | Harness | Model | Effort |
| --- | --- | --- | --- |
| `claude-opus-N` | Claude Code | `opus` | xhigh |
| `claude-fable-N` | Claude Code | `fable[1m]` | high |
| `codex-N` | Codex | `gpt-5.6-sol` | xhigh |
| `cursor-kimi-N` | Cursor | `kimi-k3-max` | max |
| `cursor-grok-N` | Cursor | `grok-4.6-fast` | xhigh |

- For an arena or unspecified multi-review request, use `claude-opus`, `codex`, and `cursor-kimi`.
- If the user names one or more harnesses, use only those harnesses' models.
- Add `claude-fable` or `cursor-grok` only when the user explicitly requests more reviewers.
- Pass effort explicitly. Both Claude aliases resolve to the latest release, but only `opus` implies the 1M-context build. The `fable` alias resolves to a 200K window, so write `fable[1m]` to give that reviewer the full context.

## Start and control reviewers

Use `orchestrate-agents-in-cmux` for cmux detection, artifact layout, launch commands, identifiers, messaging, callbacks, supervision, and recovery. Read its cmux operations reference before launch and its messaging reference before the first send.

- Use one cmux workspace for the review and one tab per reviewer.
- Pass the model and effort from the roster to the launch command templates.
- Keep each reviewer session open through validation and rebuttal.
- For Codex, use the normal TUI. Do not use `codex exec review`, which imposes a different report format and sandbox.
- If this process is not inside cmux, report that this review workflow requires cmux and stop.

## Frame the review

Resolve the target before launch:

- Use the PR, branch, diff range, or working tree the user named.
- If the target is unspecified, use the current branch's open PR. Ask for a target when no PR exists.
- Name the exact review command in every brief, such as `gh pr diff {n}`, `git diff {base}...{branch}`, or `git diff HEAD`.
- Gather intent evidence from the PR description, commits, linked issues, tests, and sibling code.
- Use the artifact directory selected through `orchestrate-agents-in-cmux`, with one brief, worklog, result, handshake, and addendum set per reviewer.

For a large change or an explicit deep review, add one relevant specialty lens per reviewer. Keep correctness and test adequacy in every brief.

## Write reviewer briefs

Each brief must:

- Name the target, the review dimensions, and what to attack in this diff.
- Allow relevant tests, linters, type checks, and throwaway probes.
- Limit writes to the review's orchestration files. Prohibit source edits, commits, and pushes.
- Require each finding to name the production entry point and reachable input, or label the finding theoretical.
- Require intent mismatches even when they fall outside the task scope. Tag them `intent-mismatch` and cite the intent evidence.
- Name the absolute worklog and result paths, the callback contract, and the harness-specific id prefix.

Use one `##` block per finding:

```markdown
## codex-3: Export query drops the tenant filter
- severity: high
- category: correctness
- file: miarecweb/views/export.py:142
- evidence: `uv run pytest miarecweb/tests/functional_tests/test_export.py::test_scope` fails
- detail: The export endpoint returns another tenant's records.
- suggested fix: Apply the tenant predicate before export pagination.
```

Blind rule: no reviewer reads another reviewer's findings before writing its own result.

## Merge and validate findings

After every result file exists:

1. Merge findings with the same root cause. Preserve every originating id in `found-by`.
2. Keep unique findings. Uniqueness is not evidence against a finding.
3. If two or more reviewers ran, assign each unique finding to a different reviewer, preferably on another harness. No reviewer validates its own finding. In the default roster, Codex validates Claude and Cursor findings, and Claude Opus validates Codex findings. Fable does not validate.
4. Write each validation or rebuttal assignment to an addendum. Send only its absolute path through the transport chosen by `orchestrate-agents-in-cmux`.
5. Allow one rebuttal from the finding's author, then close the debate.

For a single-reviewer run, the orchestrator validates every finding directly with `validate-findings`.

## Judge and report

The orchestrator decides whether each finding is real and matters. Validator votes and rebuttals are evidence, not decisions.

Lead with the tally. Rank survivors by severity and include impact, trigger, proposed solution, `found-by`, and verdict history. Route findings as:

- In scope: fix on the reviewed branch.
- `intent-mismatch`: create a separate behavior-fix PR. Pin current behavior in the original change when needed.
