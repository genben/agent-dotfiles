---
description: Create a concise but thorough handoff document for a new agent/session
---

# Create Handoff

## Mission
Create a handoff document that enables a new agent to continue work without context loss or rework.

## Output
Create `handoff_<YYYY-MM-DD--HH-MM>.md` with timestamp in filename.

## Required sections

### 1. Goal / Problem Statement
- What we're building and why (from spec.md)
- Business/user context in 2-3 sentences

### 2. Current Status
- What is done (completed phases/tasks)
- What is in progress (current task, if any)
- What remains (upcoming phases/tasks)
- Overall progress percentage estimate

### 3. Key Files Location
- `spec.md` - requirements and acceptance criteria
- `research.md` - codebase analysis
- `plan.md` - implementation plan and progress
- Phase docs (`plan_phase_*.md`)
- Any other critical files created/modified

### 4. How to Run
- Exact test command(s)
- Exact lint command(s)
- Any setup steps required
- Environment variables or configuration needed

### 5. Recent Decisions
- Key decisions from plan.md Decision Log
- Rationale for non-obvious choices
- Any trade-offs made

### 6. Open Issues / Blockers
- Unresolved open questions
- Blocked tasks and why
- Known issues or technical debt created
- Items deferred to future phases

### 7. Surprises & Discoveries
- Unexpected findings during implementation
- Things that didn't work as expected
- Workarounds applied

### 8. Next Steps
- Next 3-5 concrete tasks to execute
- Any decisions needed from the user
- Risks or concerns for upcoming work

## Guidelines
- Keep it compact but complete
- Do not omit anything that would cause rework
- Include exact file paths, not vague references
- Prefer bullet points over prose

---

**User's input:** $ARGUMENTS