---
name: divide-and-conquer-workflow
description: Divide software-engineering work into team-owned workstreams and coordinate team leads through implementation, review, verification, and delivery. Use when an orchestrator should manage multiple teams or a team lead should manage specialized coding agents.
---

# Divide and conquer workflow

Organize a software-engineering effort as a hierarchy of accountable teams. Each team owns one deliverable from plan through handoff.

## Keep responsibilities separate

This skill owns decomposition, team roles, authority, coordination, and delivery state.

- Use `orchestrate-agents-in-cmux` for workspaces, tabs, harness launch, messaging, callbacks, monitoring, and recovery.
- Use `code-review-arena` for multi-harness review, cross-validation, and adjudication.
- Follow the repository instructions and task-specific skills for implementation and acceptance criteria.

## Roles

| Role | Responsibility |
| --- | --- |
| Owner | Sets the outcome and scope, resolves policy decisions, authorizes publication, and approves merges. |
| Orchestrator | Divides the effort, starts team leads, orders dependencies, grants shared resources, verifies results, and reports to the owner. |
| Team lead | Owns one workstream through implementation, review, verification, and delivery. It creates and supervises its team. |
| Implementer | Changes the assigned code and tests in the team's worktree, records evidence, and reports to the lead. |
| Reviewer | Independently evaluates the change and reports findings without editing the reviewed code. |
| Specialist | Performs a bounded investigation, test, integration, documentation, or release assignment. |

Use this communication chain:

```text
owner <-> orchestrator <-> team leads <-> team members
```

The orchestrator communicates with team leads, not their members. A team member escalates through its lead, and a lead escalates owner decisions through the orchestrator. Replace a failed role at the same boundary instead of bypassing a healthy lead.

A lead is the designated cmux controller for its team workspace. It is a controlled agent at the parent boundary and the controller at the member boundary. Team members never call cmux.

## Divide by deliverable

- Give each team one independently deliverable workstream, branch, worktree, cmux workspace, lead, worklog, and final result.
- Keep overlapping files and coupled decisions under one lead.
- Record dependencies between teams and run only independent work in parallel.
- Limit concurrency when teams compete for machines, test environments, integration branches, or other shared resources.
- Let the orchestrator create each worktree and workspace before launching its lead. Give the lead the typed workspace ref and designate it as that workspace's cmux controller.

## Preserve authority

The owner authorizes external actions. State each team's authority in its lead brief, including edits, commits, pushes, PR creation, and merge checkpoints. A lead may prepare and publish its PR when authorized, but it never merges. The orchestrator merges only after explicit owner approval.

The orchestrator writes coordination artifacts rather than product code. It verifies team claims from worklogs, result files, repository state, captured checks, and PR state.

## Keep durable state

Use the artifact location and file-first contract from `orchestrate-agents-in-cmux`.

- The orchestrator worklog tracks the workstreams, dependencies, team states, owner decisions, shared-resource grants, and integration order.
- Each lead brief defines the outcome, ownership, acceptance criteria, authority, checkpoints, artifact paths, parent callback, cmux workspace ref, and required task skills.
- Each lead maintains its worklog and final result. It gives every member separate brief, worklog, and result files.
- Create worklogs with the first meaningful entry. Append each handoff, decision, state change, surprise, and deviation when it happens. Empty placeholder worklogs and end-of-run reconstruction are not live state.

## Run the effort

1. Resolve the outcome, scope, authority, repository rules, and owner checkpoints.
2. Divide the work into teams and record the dependency order.
3. Bootstrap each worktree, workspace, lead brief, and team lead.
4. Let each lead run the lifecycle in [references/team-lifecycle.md](references/team-lifecycle.md).
5. Coordinate shared gates and decisions through the leads.
6. Verify every team's result and integrate deliverables in dependency order.
7. Present the final state to the owner. Perform only the publication or merge actions the owner authorized.

Completion requires a final result from every team, current verification for every delivered tree, resolved dependencies, and an explicit record of remaining blockers or owner decisions.
