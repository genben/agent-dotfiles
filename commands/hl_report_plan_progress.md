---
description: Save the implementation progess into the plan document
---

# Save progress

You are tasked with writing a progress of the implementation into the plan document to hand off your work to another agent in a new session. 
The goal is to compact and summarize your progress without losing any of the key details of what you've completed so far.

# Key Guidelines

- This plan is living document. As you make key design decisions, update the plan to record both the decision and the thinking behind it. Record all decisions in the `Decision Log` section.
- This plan must contain and maintain a `Progress` section, a `Surprises & Discoveries` section, a `Decision Log`, an `Outcomes & Retrospective`, and the `Next steps` section. These are not optional.
- When you discover optimizer behavior, performance tradeoffs, unexpected bugs, or inverse/unapply semantics that shaped your approach, capture those observations in the `Surprises & Discoveries` section with short evidence snippets (test output is ideal).
- If you change course mid-implementation, document why in the `Decision Log` and reflect the implications in `Progress`. Plans are guides for the next contributor as much as checklists for you.
- At completion of a major task or the full plan, write an `Outcomes & Retrospective` entry summarizing what was achieved, what remains, and lessons learned.

Use a list with checkboxes to summarize granular steps in the `Progress` section. Every stopping point must be documented here, even if it requires splitting a partially completed task into two (“done” vs. “remaining”). This section must always reflect the actual current state of the work.

Example:

```markdown 
- [x] (2025-10-01 13:00) Example completed step.
- [ ] Example incomplete step.
- [ ] Example partially completed step (completed: X; remaining: Y).
```
 
Use timestamps to measure rates of progress.

Section `Surprises & Discoveries`:
 
Document unexpected behaviors, bugs, optimizations, or insights discovered during implementation. Provide concise evidence.
 
- Observation: …
  Evidence: …
 
Section `Decision Log`
 
Record every decision made while working on the plan in the format:
 
- Decision: …
  Rationale: …
  Date/Author: …
 
Section `Outcomes & Retrospective`
 
Summarize outcomes, gaps, and lessons learned at major milestones or at completion. Compare the result against the original purpose.

Section `Next steps`

Outline the remaining work, future improvements, or follow-up actions needed to complete the plan or address any outstanding issues.
