# Team lifecycle

Read this reference before launching a team lead. The lead owns every stage for its workstream and reports only to the orchestrator.

## Brief the lead

The orchestrator's brief gives the lead:

- the deliverable, scope, non-goals, and acceptance criteria;
- the branch, worktree, and owned files or subsystem;
- repository instructions and source evidence;
- authorized edits and external actions;
- dependencies, shared resources, and owner checkpoints;
- worklog, result, and parent callback paths.

Mark settled owner decisions as settled. The lead reports new scope or policy questions instead of deciding them for the owner.

## Plan and staff the team

The lead inspects the worktree and records a concrete plan in its worklog. It creates only the roles the work needs. Parallel assignments must have disjoint ownership or a declared handoff order.

Every member brief contains one bounded task, acceptance checks, writable paths, worklog and result paths, and the callback to the lead. The lead uses `orchestrate-agents-in-cmux` for all session mechanics.

## Implement and inspect

The implementer changes code and tests in the team's worktree. It records progress, surprises, and deviations while working, then writes a result with the changed files and verification evidence.

The lead checks the result against the worktree before accepting it. Prose alone is not completion.

## Review and fix

Arrange independent review for code changes. Use `code-review-arena` when the owner requests multiple harnesses or the change warrants cross-validation.

Route accepted findings back to the implementer. Reuse the same implementer session while its context remains useful. Ask the reviewer that raised a finding to verify its fix. A new behavior change expands the reviewed scope and requires a fresh review of that scope.

Set a retry limit in the lead brief. After three unsuccessful fix or review rounds by default, stop delegating, preserve the evidence, and ask the orchestrator to arbitrate.

## Verify the delivered tree

Run the repository-required tests and quality checks against the final tree. A new change invalidates earlier verification of the affected tree.

When a check consumes a shared resource, request a slot from the orchestrator and wait for an explicit grant. Release the slot when the captured result is available.

## Deliver and report

Within its granted authority, the lead prepares focused commits, pushes the branch, creates or updates the PR, and applies the repository's PR-description workflow. The lead does not merge.

The final result contains:

- the branch, worktree, commits, and PR;
- the delivered scope and changed files;
- current test and quality-check evidence;
- the review verdict and resolved findings;
- deviations, routed work, unresolved blockers, and owner decisions needed.

Write the result before sending its absolute path to the orchestrator.

## Recover failed roles

The lead replaces a failed member. The orchestrator replaces a failed lead. Start the replacement in a new tab and base its recovery brief on verified worktree state, worklogs, and result files rather than the failed session's last message.
