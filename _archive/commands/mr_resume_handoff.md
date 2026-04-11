---
description: Resume work from a handoff document by syncing state and proposing next steps
---

# Resume from Handoff

## Mission
Resume work from a previous session's handoff document, verify current state, and propose the next concrete task.

## Steps

### 1. Read context documents
- Read the handoff document (handoff_*.md)
- Read plan.md to understand full scope
- Read spec.md to understand requirements and acceptance criteria
- Skim research.md for key patterns and constraints

### 2. Summarize current state
Provide a 5-10 bullet summary:
- Goal of the work
- What phases/tasks are complete
- What is currently in progress (if any)
- What remains to be done
- Any blockers or open questions noted

### 3. Verify repo state matches handoff
- Check git status for uncommitted changes
- Run tests to verify current state
- Compare actual file state vs what handoff claims
- Note any discrepancies

### 4. Check for stale items
- Review open questions - are any now answerable?
- Review blockers - are any now resolved?
- Check if any decisions need to be revisited

### 5. Update plan.md
- Sync Progress section to match reality (checkboxes, timestamps)
- Add any new discoveries to Surprises & Discoveries
- Update Decision Log if state verification revealed issues

### 6. Propose next task
- Identify the next smallest verifiable task
- Explain what it involves and how to verify completion
- Note any decisions needed from user before starting

## Important
- **STOP** and wait for user confirmation before implementing anything
- If state doesn't match handoff, ask the user how to proceed
- If tests are failing, report this before proposing new work

## Project standards
Check for and read project standards documents:
- `docs/standards/testing.md` - testing conventions
- `docs/standards/code_quality.md` or `code_styleguide.md` - code standards

Apply these standards when resuming implementation.

---

**User's input:** $ARGUMENTS