---
description: Research the existing codebase relevant to spec.md; produce research.md (no code changes)
---

# Research Codebase

## CRITICAL: YOUR ONLY JOB IS TO DOCUMENT AND EXPLAIN THE CODEBASE AS IT EXISTS TODAY
- DO NOT suggest improvements or changes unless the user explicitly asks
- DO NOT perform root cause analysis unless explicitly asked
- DO NOT propose future enhancements unless explicitly asked
- DO NOT critique the implementation or identify problems
- DO NOT recommend refactoring, optimization, or architectural changes
- ONLY describe what exists, where it exists, how it works, and how components interact
- You are creating a technical map/documentation of the existing system

## Steps
1) Read `spec.md` (or provided spec file) and extract:
   - key behaviors and constraints
   - acceptance criteria
   - keywords/entities to search for

2) Explore the repo to map relevant areas:
   - identify modules/files/classes/functions
   - document call paths and data flow for the spec-relevant behaviors
   - cite evidence via exact paths + symbol names

3) Capture a "Tech Stack Snapshot (as-is)":
   - languages/frameworks present
   - key build/test tools (as discovered)
   - major third-party dependencies relevant to the spec
   (Do not propose changing any of these.)

4) Verify existing patterns apply to new use case:
   - For each existing pattern identified (e.g., existing test fixtures, mocking approaches):
     - Document whether it can be reused as-is for the spec requirements
     - If not, document WHY it won't work and what gap exists
   - Check if new dependencies will be required; list them explicitly

5) Review CI/CD configuration:
   - Document existing CI service containers (databases, caches, etc.)
   - Document existing test execution patterns
   - Note any constraints that may affect the implementation

6) If multiple incorporation points exist, document them as **observations**:
   - "Path A/B/C" with pros/cons + assumptions + unknowns
   - no recommendation unless user asks

7) If you get stuck or spec is ambiguous:
   - ask the user **one** clarifying question at a time.

## Constraints
- Do not modify code.
- If any file is accidentally modified, revert it immediately.

## Template (required)
Use this template as the starting structure for the research doc:
- `~/.claude/templates/research_template.md`

If the template file is missing, notify the user and stop. Only proceed after the user provides the template inline or creates the template file.

## Output
Write the research doc to `research.md` (next to `spec.md`), following the template, including:
- relevant components map (paths + responsibilities + key symbols)
- as-is data/control flow
- integration surfaces (as-is)
- candidate incorporation paths (observational)
- dependency gap analysis (new packages/tools that may be needed)
- CI/CD constraints and existing patterns
- pattern applicability assessment (can existing patterns be reused?)
- open questions + assumptions
- evidence appendix (commands run + pointers)

Keep chat updates brief; only announce major milestones.
