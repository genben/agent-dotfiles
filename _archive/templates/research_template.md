# Codebase Research for <Feature>

## 1. Research Scope
- Spec version/date referenced
- What areas were searched

## 2. Repo Orientation
- How to run / build / test (as discovered)
- Key directories

## 3. Relevant Components (Map)
For each component:
- Path(s)
- Responsibilities
- Key types/functions (names + brief role)
- Inputs/outputs
- What calls it / what it calls
- Notable invariants

## 4. Data Flow (As-Is)
- Request → processing → storage → response
- Diagrams optional (ASCII)

## 5. Extension Points / Integration Surfaces (As-Is)
- Where new behavior *could* attach, based on current architecture
- Constraints imposed by existing interfaces

## 6. Candidate Incorporation Paths (Observational)
Path A / B / C:
- Where it would likely live (paths)
- Pros / Cons
- Assumptions
- Unknowns / risks
(NO recommendation unless user asks.)

## 7. Tests & Tooling (As-Is)
- Existing test frameworks, patterns
- Linters/formatters
- CI notes (if present)

## 8. Open Questions
- Items that block planning
- Questions to ask the user (one at a time in chat)

## 9. Evidence Appendix
- Commands run (rg/ls/etc.)
- Links to key code locations (paths + symbols)
