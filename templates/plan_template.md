# Plan — <Feature Name>

## Summary
(2-3 paragraphs: why this work, what it delivers, phase overview)

## 0. References

### 0.1 Specification (Always Read)
- [spec.md](spec.md) — Detailed specification with acceptance criteria. **Read before any implementation.**

### 0.2 Phase Plans (Read Relevant Phase)
- [plan_phase_1.md](plan_phase_1.md) — Phase 1: ...
- [plan_phase_2.md](plan_phase_2.md) — Phase 2: ...

### 0.3 Research (Read to Understand Codebase)
- [research.md](research.md) — Codebase exploration, component mapping, existing patterns.

### 0.4 Source Document (Read if Requested)
- [idea.md](idea.md) — Original problem analysis and solution hypothesis. Source from which spec.md was produced.

## 1. Software Design Document (SDD)
### 1.1 Goals & Constraints
### 1.2 Proposed Architecture (High-level)
### 1.3 Data Model & Types (Signatures, not full code)
### 1.4 Module / File-level Design
- Files to modify/add
- Responsibilities per module
### 1.5 Interfaces & Contracts
- APIs, function/class interfaces
### 1.6 Key Algorithms (Pseudo-code)
### 1.7 Testing Architecture
- Test strategy by layer
- Fixtures/mocks
- Edge-case scenarios
### 1.8 Edge Cases
### 1.9 Observability & Ops (if relevant)

## 2. Phase Breakdown (Approval checkpoint)
Phase 1..N:
- Goal
- Acceptance criteria
- Tests to add (this phase)
- "Done means": tests pass + lint pass for modified scope

## 3. Living Sections (Mandatory)

> **Instructions for maintainers:**
>
> This plan is a living document. As you make key design decisions, update the plan to record both the decision and the thinking behind it. Record all decisions in the `Decision Log` section.
>
> Maintain the `Progress` section in this plan and in the corresponding phase document. Mark tasks as `[ ]` not started, `[~]` in progress, or `[x]` done.
>
> When you discover optimizer behavior, performance tradeoffs, unexpected bugs, or inverse/unapply semantics that shaped your approach, capture those observations in the `Surprises & Discoveries` section with short evidence snippets (test output is ideal).
>
> If you change course mid-implementation, document why in the `Decision Log` and reflect the implications in `Progress`. Plans are guides for the next contributor as much as checklists for you.
>
> At completion of a major task or the full plan, write an `Outcomes & Retrospective` entry summarizing what was achieved, what remains, and lessons learned.
>
> **This document must describe not just the what but the why for almost everything.**

### 3.1 Progress
- [ ] Phase 1: ...
- [ ] Phase 2: ...

### 3.2 Decision Log
- **Decision:** ...
  - Date: YYYY-MM-DD
  - Rationale: ...

### 3.3 Surprises & Discoveries
- **Observation:** ...
  - Evidence: ...

### 3.4 Outcomes & Retrospective
(To be filled after completion)
