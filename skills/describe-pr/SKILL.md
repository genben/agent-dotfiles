---
name: describe-pr
description: Generate a PR description focused on why the change exists, its user impact, and its risks. Use when asked to describe, document, or write a PR description.
---

# Generate PR description

Describe the PR; don't verify it. Never run tests or checks, and never report their results: CI owns verification. All content guidance (audience, per-section rules, length) lives in the template's comments and nowhere else. Apply the technical-writing skill to all prose.

## Workflow

Run from the checked-out PR branch or worktree.

1. **Read the template**: `templates/pr_description_template.md` in the skill dir. Its HTML comments carry the content guidance per section; follow them, and keep neither the comments nor inapplicable sections in the output.

2. **Identify the PR**: `gh pr view --json url,number,title,state,baseRefName`. If the current branch has no PR, stop and ask the user.

3. **Check for an existing description**: `docs/prs/pr_{NNN}_*.md` in the project. If found, update it and account for what changed since.

4. **Gather sources**:
   - Diff: `gh pr diff {number}`.
   - Full commit messages with bodies; headlines hide the why:

     ```bash
     git log {base}..HEAD --no-merges --pretty=format:"=====%n%h %s%n%b" > /tmp/all_commits.txt
     ```

     Read all of it, in chunks if large. Commit bodies are the primary source for root cause, user-visible symptoms, and guardrails. On iterative PRs, early messages may describe behavior that later commits replaced; when messages disagree with each other or with the diff, the source code is the ground truth.
   - Any exec plan the PR adds under `docs/plans/`. It holds the implementation detail; link it rather than restating it.

5. **Analyze for behavior, not code**: for each change, state the behavior before and after in user terms. No behavior change means it's a refactor; one line suffices. Watch for breaking changes and migrations, which often hide in `fix(...)` commit bodies.

6. **Research every factual claim**: severity, exposure, and likelihood come from the codebase and its history, never from guessing. Date a bug's introduction with `git log -S` or `git blame` and map it to a release. Trace which code paths can actually hit the trigger and how often they run. If a reader could ask "since when?", "which versions?", or "how likely?", the description answers with a commit, release, or named path.

7. **Gather evidence**: skip this step entirely if `~/.config/show-me/publish.env` is missing. Otherwise scan `~/.show-me/{repo-name}/{branch-name}/*/manifest.md` (conventions in the show-me skill). Select only screenshots and screen recordings of the product UI; ignore diagrams and explainers, whose content the prose sections already cover. Use evidence with `status: approved` whose `commit` is still current; if the relevant code changed after capture, treat it as outdated and confirm with the user. If several candidates exist, ask the user which to include. If nothing usable exists, offer to produce it by running a sub-agent with the show-me skill. Get public URLs for the selected files by following the publish instructions in the show-me skill.

8. **Save**: write to `docs/prs/pr_{NNN}_{short_description}.md` (zero-padded number; short description inferred from branch name and PR title). Show the user the result.

9. **Commit and push**: stage the description, commit as `docs: add PR description for #{number}` (`update` when revising), push.

10. **Update the PR**: `gh pr edit {number} --body-file docs/prs/pr_{NNN}_{short_description}.md` and confirm it succeeded.

---

**User's input:** $ARGUMENTS
