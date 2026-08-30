---
name: validate-findings
description: Adversarially validate code-review findings against the code, reject slop, report survivors. Use when asked to validate, verify, or triage review findings.
---

# Validate findings

Reviewers are prompted to hunt, so they always return findings. A non-empty list is not evidence of real problems. The deliverable is an assessment, not fixes. Do not change code.

A defect exists only relative to intent. Before ruling, infer the intended behavior from evidence: docstrings, naming, sibling idioms, commit history, domain semantics. No single source settles intent; unit tests can pin the wrong behavior, and comments or docstrings go stale, so corroborate across sources. Judge "is it real" against that intent, not the reviewer's assumption, and judge an intent-mismatch finding by whether the evidence supports the claimed intent, not by whether anything breaks today. Intent claims without evidence carry no weight, in either direction.

Read the code each finding cites before ruling. Attack every finding on two independent axes and reject it if it fails either:

1. **Is it real?** Reproduce or refute the claimed defect from the code. Does it occur as described?
2. **Does it matter?** Reject as slop any finding whose failing input no production path constructs, whose fix would be defensive code (guards, fallbacks, handling for unreachable states), or whose only consequence is degradation the design already accepts. Reproducibility is not importance: a finding that reproduces under a probe must still name what breaks for a real user. When the answer is nothing, reject.

A survivor can deserve a different severity than claimed, in either direction. Re-derive it and say why. Merge findings that share a root cause.

## Report

Lead with the tally (N survive, M rejected). Reference rejected findings by name only, without restating them. Then survivors, ranked by severity, each with:

- **Impact**
- **How it occurs**
- **Proposed solution** (never a defensive guard)
