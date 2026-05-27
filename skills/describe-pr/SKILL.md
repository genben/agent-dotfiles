---
name: describe-pr
description: Generate comprehensive PR description. Use when asked to describe, document, or write a PR description.
---

# Generate PR Description

You are tasked with generating a comprehensive pull request description following the repository's standard template.

## Steps to follow:

1. **Read the PR description template:**
   - Location (in the skill dir): `templates/pr_description_template.md`
   - Read the template carefully to understand all sections and requirements
   - Use Read() command to check these files, not Search.

2. **Identify the PR to describe:**
   - Check if the current branch has an associated PR: `gh pr view --json url,number,title,state 2>/dev/null`
   - If no PR exists for the current branch, or if on main/master, list open PRs: `gh pr list --limit 10 --json number,title,headRefName,author`
   - Ask the user which PR they want to describe

3. **Check for existing description:**
   - Check if `docs/prs/{number}_description.md` already exists (in the current project dir)
   - If it exists, read it and inform the user you'll be updating it
   - Consider what has changed since the last description was written

4. **Gather comprehensive PR information:**
   - Get the full PR diff: `gh pr diff {number}`
   - If you get an error about no default remote repository, instruct the user to run `gh repo set-default` and select the appropriate repository
   - Review the base branch: `gh pr view {number} --json baseRefName`
   - Get PR metadata: `gh pr view {number} --json url,title,number,state`
   - **Read full commit messages with bodies, not just headlines.** `git log --oneline` and `gh pr view --json commits` (which returns only `messageHeadline`) are NOT sufficient — they hide the "why", the surprises, the specific regressions, and the behavior-change rationale that the author wrote in the commit body. Use:
     ```bash
     git log {base-branch}..HEAD --no-merges --pretty=format:"=====%n%h %s%n%b" > /tmp/all_commits.txt
     wc -l /tmp/all_commits.txt
     ```
     Then Read the file (in chunks if large). Treat every non-trivial commit body as a primary source: it usually contains the root cause, the user-visible behavior change, and any guardrails the author put in. The PR description should reflect those specifics, not paraphrase the headlines.
   - For PRs with many commits (>20), do not skim only the most recent ones — the earliest commits typically contain the design rationale, and middle commits often contain behavior changes that ride along.

5. **Analyze the changes thoroughly:** (ultrathink about the code changes, their architectural implications, and potential impacts)
   - Read through the entire diff carefully
   - Cross-reference the diff with the commit bodies from step 4: each fix/feat commit body usually names the root cause, the user-visible symptom, and any subtle behavior change. These belong in the PR description.
   - For context, read any files that are referenced but not shown in the diff
   - Read any planning docs the PR adds under `docs/plans/` — they typically capture the design rationale, surprises, and decision log
   - Understand the purpose and impact of each change
   - Identify user-facing changes vs internal implementation details
   - Look for breaking changes or migration requirements — behavior changes are often buried in `fix(...)` commit bodies, not just `feat(...)` headlines

6. **Handle verification requirements:**
   - Look for any checklist items in the "How to verify it" section of the template
   - For each verification step:
     - If it's a command you can run (like `make check test`, `npm test`, `pytest`, etc.), run it
     - If it passes, mark the checkbox as checked: `- [x]`
     - If it fails, keep it unchecked and note what failed: `- [ ]` with explanation
     - If it requires manual testing (UI interactions, external services), leave unchecked and note for user
   - Document any verification steps you couldn't complete

7. **Generate the description:**
   - Replace the template title with the branch name (e.g., `# 2026-02-01-public-reports-role-permission`)
   - Fill out each section from the template thoroughly:
     - Answer each question/section based on your analysis
     - Be specific about problems solved and changes made
     - Focus on user impact where relevant
     - Include technical details in appropriate sections
     - Write a concise changelog entry
   - Ensure all checklist items are addressed (checked or explained)

8. **Save and sync the description:**
   - Write the completed description to `docs/prs/pr_{NNN}_{SHORT_DESCRIPTON}.md`
   - Format PR number with leading zeros, if needed (e.g., `001`, `023`)
   - Use the descriptive name as SHORT_DESCRIPTION (infer from the branch name, PR title and the content of the PR)
   - Show the user the generated description and name.

9. **Commit and push the description file:**
   - Stage the description file: `git add docs/prs/pr_{NNN}_{SHORT_DESCRIPTON}.md`
   - Commit with message: `docs: add PR description for #{number}`
   - Push to the remote branch

10. **Update the PR:**
   - Update the PR description directly: `gh pr edit {number} --body-file docs/prs/pr_{NNN}_{SHORT_DESCRIPTON}.md`
   - If any verification steps remain unchecked, remind the user to complete them before merging
   - Confirm the update was successful

## Important notes:
- This command works across different repositories - always read the local template
- Be thorough but concise - descriptions should be scannable
- Focus on the "why" as much as the "what"
- Include any breaking changes or migration notes prominently
- If the PR touches multiple components, organize the description accordingly
- Always attempt to run verification commands when possible
- Clearly communicate which verification steps need manual testing

---

**User's input:** $ARGUMENTS
