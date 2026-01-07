---
description: Create/iterate on spec.md from brainstormed requirements (interactive)
---

# Create Specification

## Mission
Turn the user's brainstormed requirements into a clear, testable `spec.md` that describes **what** we should achieve (user/business outcomes + UX behavior), not how.

## Inputs
- If a requirements file path is provided as argument, read it first.
- Otherwise, ask the user to paste the initial requirements.

## Interaction protocol (Strict)
1) Before asking any clarifying questions:
   - Thoroughly research the codebase to find answers first.
   - Only ask questions that cannot be answered through research.
   - Do not ask obvious questions.
2) Ask **one** clarifying question at a time.
   - Prefer multiple choice answers when reasonable.
   - Provide recommended options with rationale.
   - Maintain `Open Questions` + `Assumptions` as you go.
3) Use `AskUserQuestionTool` tool if available, otherwise use chat
4) When you believe requirements are sufficiently clear:
   - Propose the `spec.md` outline (from the template).
   - Then present the user the spec for approval in small blocks ~200-300 words per block.
   - After each block, ask: "Does this look right so far? (yes/no + corrections)"
   - If user provides corrections, apply them and re-present only the modified portions.
5) Only after user confirms the summaries, write/update `spec.md`.

## What the spec must include
- Context & goals (user/business perspective)
- UX/user experience expectations (as applicable)
- Functional requirements (user stories, use cases)
- Edge cases & failure modes
- Non-functional requirements (performance, security, reliability, observability, etc.)
- Scope & non-goals
- Top-level acceptance criteria (measurable outcomes)
- Open questions + assumptions
- References section with all relevant external links

## Information preservation (Critical)
- **All important information** from the original user request MUST appear in `spec.md` in one form or another (requirements, context, assumptions, or references).
- **All external links** (documentation URLs, issue links, example code, etc.) MUST be preserved in a References section unless explicitly deemed irrelevant by the user.
- Do NOT silently drop details from the original request. If something seems unclear or out of scope, ask about it or note it in Open Questions.
- Code snippets or pseudocode from the original request should be preserved in the spec (in a "Technical Notes" or "Implementation Hints" subsection) if they clarify intent.

## Open Questions Resolution Gate
Before the spec is considered complete:
- All open questions must either be:
  1. Resolved with a concrete answer documented in the spec, OR
  2. Explicitly marked as "deferred to research phase" with justification
- Questions that affect implementation approach MUST be resolved before planning
- Ask the user to make decisions on open questions before finalizing the spec

## Template (required)
Use this template as the starting structure for the spec:
- `~/.claude/templates/spec_template.md`

If the template file is missing, notify the user and stop. Only proceed after the user provides the template inline or creates the template file.

## Output shaping
- Clarifying question turns: ONLY the question + answer options.
- Approval turns: 200-300 words per approval block, then stop for confirmation.
- Avoid long narrative; prefer crisp bullets.

## Ambiguity handling
- Do not invent requirements.
- If underspecified, ask the next best single clarifying question.
- Record assumptions explicitly.

Stop once `spec.md` is written and the user confirms it looks correct.
