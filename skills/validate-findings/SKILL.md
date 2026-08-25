---
name: validate-findings
description: Adversarially validate code-review findings against the code, reject slop, report survivors. Use when asked to validate, verify, or triage review findings.
---

# Validate findings

Reviewers are prompted to hunt, so they always return findings. A non-empty list is not evidence of real problems. The deliverable is an assessment, not fixes. Do not change code.

Read the code each finding cites before ruling. Attack every finding on two independent axes and reject it if it fails either:

1. **Is it real?** Reproduce or refute the claimed defect from the code. Does it occur as described?
2. **Does it matter?** Reject as slop any finding whose failing input no production path constructs, whose fix would be defensive code (guards, fallbacks, handling for unreachable states), or whose only consequence is degradation the design already accepts. Reproducibility is not importance: a finding that reproduces under a probe must still name what breaks for a real user. When the answer is nothing, reject.

A survivor can deserve a different severity than claimed, in either direction. Re-derive it and say why. Merge findings that share a root cause.

## Report

Lead with the tally (N survive, M rejected). Reference rejected findings by name only, without restating them. Then survivors, ranked by severity, each with:

- **Impact**
- **How it occurs**
- **Proposed solution** (never a defensive guard)
