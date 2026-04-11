You are Codex. Extract session learnings that would change your behavior next time.

Task:
1) Analyze the CURRENT session only (agent actions, commands, edits, failures, user feedback).
2) Identify concrete learnings in these categories:
- Your own mistakes
- User corrections
- Tool/environment surprises
- User preferences
- What worked

Quality bar:
- Be specific and behavioral. Vague statements are not allowed.
- Every learning must include concrete evidence (command, error, file path, diff, or quoted user instruction).
- Explain why it happened and exactly what you will do differently next time.
- If something was retried/fixed, capture the bad attempt and the corrected approach.
- Prioritize items that would materially change future execution.

Output file path rule:
- Compute `branch_name` from git.
- If `docs/plans/{branch_name}/` exists, target:
  `docs/plans/{branch_name}/YYYY-MM-DD-learnings.md`
- Otherwise target:
  `docs/learnings/YYYY-MM-DD-{branch_name}.md`

Update behavior:
- Assume this is a continuously updated learnings log.
- If target file exists, append a new dated session entry at the bottom.
- Do not duplicate prior learnings; instead add a “Reinforced” note if repeated.
- Normalize wording so future you can act on it quickly.

Required output structure inside the file:

# Session Learnings - YYYY-MM-DD
## Context
- Branch:
- Goal:
- Session scope:

## Learnings
### [Category] <short title>
- Evidence:
- What happened:
- Root cause:
- Correction applied (or requested by user):
- Behavior change for next session:
- Guardrail/checklist rule:
- Impact:
- Confidence: High | Medium | Low

(Repeat for each learning; most critical first)

## Operational Preferences (User)
- Preference:
- How to apply it by default:
- Exceptions:

## Proven Effective Approaches
- Approach:
- Why it worked:
- When to reuse:

## Quick Start Rules for Next Session
- Rule 1:
- Rule 2:
- Rule 3:

Constraints:
- Do not invent facts.
- If evidence is missing, mark the item “Needs verification” and lower confidence.
- Keep entries concise but concrete.
- Focus on learnings that change agent behavior, not generic retrospectives.
