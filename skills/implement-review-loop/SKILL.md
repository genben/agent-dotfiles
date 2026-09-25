---
name: implement-review-loop
description: Delegate work to implementer, adversarial-reviewer, and findings-validator sub-agents, arbitrate their debate, and loop until the fixes pass review. Use when implementing via sub-agents with quality control.
---

# Implement-review loop

You orchestrate; sub-agents do the work. Sub-agents have no conversation context, so every brief must be self-contained. Continue an existing sub-agent via SendMessage to keep its context; a new role or task gets a fresh sub-agent.

1. **Implement.** Launch an implementer with the goal, acceptance criteria, and constraints. It writes tests and runs validation before reporting back.
2. **Review.** Launch a fresh adversarial reviewer with a brief of what changed and where (commits, not diffs), the acceptance criteria, and the applicable standards; it reads the diff itself. It hunts for defects and returns an acceptance or concrete change requests. It judges against the criteria, not rubber-stamps.
3. **Validate findings.** Launch a findings validator on the reviewer's change requests, following the validate-findings skill.
4. **Debate.** Relay the validator's rejections to the reviewer and the rebuttals back. The reviewer withdraws each contested finding or insists with new evidence.
5. **Judge.** You decide which findings survive; you own the delivered quality. Record the dropped findings and why, so they are not re-litigated.
6. **Fix and re-review.** Send the surviving findings to the same implementer, then send the applied fixes back through review (step 2). Repeat until the reviewer accepts. Past ~3 rounds, stop delegating: investigate yourself, fix or overrule, or escalate to the user.
