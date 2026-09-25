---
name: interrogate
description: "Use for \"interrogate\", \"adversarial review\", \"multi-model review\", \"challenge this\", \"stress test this code\", \"find blind spots\", or \"tear this apart\". Independent Claude Code, Codex, and Cursor reviewers attack the same change from different angles."
disable-model-invocation: true
---

# Interrogate

Run one adversarial reviewer per model against the same change, then deliver one synthesized verdict. The adversarial signal comes from model diversity, not from assigned personas. Models differ in blind spots, priors, and reasoning patterns. A harness is only where a model runs; one harness can host several models. Agreement across reviewers is high-confidence signal; a lone finding is worth reading at lower confidence.

The deliverable is a verdict. Never auto-apply changes, and reviewers never edit the code under review.

Use `code-review-arena` instead when findings need cross-validation, rebuttal, and routing into PRs. Interrogate stops at lead judgment.

## Step 1, Resolve the target

- Use the PR, branch, diff range, files, or working tree the user named.
- If the target is unspecified, use the current branch's open PR. Fall back to `git diff {base}...HEAD` on a feature branch. Ask for a target when neither exists.
- Name the exact review command in every brief, such as `gh pr diff {n}`, `git diff main...HEAD`, or `git diff HEAD`. Reviewers run it themselves; do not paste the diff into a brief.
- Note the surrounding files a reviewer needs to judge the change, such as callers, type definitions, and sibling modules.

## Step 2, State the intent

Before launch, write one paragraph on what this change is trying to accomplish. Derive it from the user's message, the commits, the PR description, and the code. Reviewers challenge whether the work achieves the intent well, not whether the intent is correct. Ask the user when the intent is unclear.

## Step 3, Launch reviewers

| Id prefix | Harness | Model | Effort |
| --- | --- | --- | --- |
| `claude-opus-N` | Claude Code | `opus` | xhigh |
| `claude-fable-N` | Claude Code | `fable[1m]` | high |
| `codex-N` | Codex | `gpt-5.6-sol` | xhigh |
| `cursor-kimi-N` | Cursor | `kimi-k3-max` | max |
| `cursor-grok-N` | Cursor | `grok-4.6-fast` | xhigh |

- One reviewer per model. A second reviewer on the same model adds cost, not signal.
- Use `claude-opus`, `codex`, and `cursor-kimi` by default: three models spanning three harnesses.
- Widen with `cursor-grok` or `claude-fable` when the user asks for more reviewers or the change warrants deeper coverage. Both reuse a harness already in the roster, so they cost a tab, not a new integration.
- If the user names models, use exactly those. If the user names harnesses, use those harnesses' models.
- Pass effort explicitly. Both Claude aliases resolve to the latest release, but only `opus` implies the 1M-context build. The `fable` alias resolves to a 200K window, so write `fable[1m]` to give that reviewer the full context.

Use `orchestrate-agents-in-cmux` for cmux detection, artifact layout, launch commands, identifiers, messaging, callbacks, supervision, and recovery. Read its cmux operations reference before launch and its messaging reference before the first send.

- Use one cmux workspace for the interrogation and one tab per reviewer.
- Pass the model and effort from the roster to the launch command templates.
- For Codex, use the normal TUI. Do not use `codex exec review`, which imposes a different report format and sandbox.
- Keep each reviewer session open until the verdict ships, so you can ask a reviewer to substantiate a finding during judgment.
- If this process is not inside cmux, report that this workflow requires cmux and stop.

Write one brief per reviewer from [`references/reviewer-prompt.md`](references/reviewer-prompt.md), filled with the intent, the review command, the rubric in [`references/rubric.md`](references/rubric.md), and the code-quality lens in [`references/code-quality-review.md`](references/code-quality-review.md). Every reviewer gets the same rubric and lens; only the id prefix and file paths differ.

Blind rule: no reviewer reads another reviewer's result before writing its own.

## Step 4, Synthesize

Once every result file exists:

1. **Parse all findings** from the result files.
2. **Identify consensus.** Findings raised by two or more reviewers independently are the highest signal.
3. **Identify lone findings.** Still worth reading, but weight accordingly.
4. **Deduplicate.** Merge findings with the same root cause and preserve every originating id in `found-by`.
5. **Note disagreements.** One reviewer flagging what another explicitly cleared is useful context for the verdict.

Attribute by reviewer id, never by harness. Two models on one harness are two independent reviewers, and consensus between them counts the same as consensus across harnesses.

## Step 5, Lead judgment

You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator.

Read [`references/lead-judgment.md`](references/lead-judgment.md) for the full framework. Reviewers only see a slice of the codebase. You have the full context: the goal, the constraints, the timeline, and which tradeoffs were already considered. Use that context aggressively.

Categorize every finding:

- **Act on.** Real issues affecting correctness, security, or maintainability given the actual goals. These would block a real PR.
- **Consider.** Legitimate points where the fix may not be worth its cost right now. Worth the user's attention.
- **Noted.** Technically valid but not actionable. Context-dependent, premature, or low-impact at this stage.
- **Dismissed.** Wrong, nitpicky, or missing context. Say briefly why.

For each finding, give the originating ids, the category, and a one-line rationale for the categorization.

## Output format

### Intent
> [The intent paragraph from Step 2]

### Reviewers
- `{id}`: {harness}, {model}, {N} findings (one bullet per reviewer)

### Act on
[Findings to address. For each: description, `found-by`, why it matters.]

### Consider
[Findings worth thinking about. For each: description, `found-by`, the tradeoff.]

### Noted
[Valid but low-priority. Brief list.]

### Dismissed
[Rejected findings with brief rationale, so the user can override your judgment.]

### Agreement map
[Where reviewers agreed, where they diverged, and what that pattern says about the change.]
