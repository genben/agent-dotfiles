# Address PR Comments Skill

Process and address review comments on a GitHub Pull Request.

## Trigger

Use this skill when the user asks to:
- "Address PR comments"
- "Check PR comments"
- "Review PR feedback"
- "Fix PR review comments"

## Workflow

### 1. Fetch PR Comments

```bash
# Get PR number and details
gh pr view --json number,title,url

# Get all review comments with file, line, author, and body
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | "\n---\nFile: \(.path):\(.original_line)\nAuthor: \(.user.login)\nBody: \(.body)\n"'
```

### 2. Analyze Comments

For each comment:
- Identify if it requires a code change or just an explanation
- Group related comments that can be addressed together
- If unclear, ask the user for clarification before proceeding

### 3. Address One Issue at a Time

Work on issues sequentially unless they are related/in the same group:

1. **Read the relevant file(s)** to understand context
2. **Make the necessary changes** if code modification is needed
3. **Run linters** on modified files (use project-appropriate linter)
4. **Run the full project test suite** (not a subset):
   - Check CLAUDE.md or project documentation for the test command
   - Run ALL tests to ensure no regressions
5. **Commit the change** with a descriptive message:
   ```bash
   git add <files> && git commit -m "Description of the fix"
   ```
6. **Reply to the PR comment** with resolution details:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
     -f body="Fixed in commit {commit_hash} - {brief description of the change}"
   ```

### 4. For Comments Not Requiring Code Changes

If a comment is a question or doesn't require code modification:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -f body="Explanation of why no code change is needed or answering the question"
```

### 5. Push Changes

After all comments are addressed:

```bash
git push
```

## Important Rules

- **Always run linters before committing** - ensures code quality
- **Always run the FULL test suite before committing** - ensures no regressions anywhere in the project
- **Work on one issue at a time** - unless issues are related
- **Include commit hash in PR comment replies** - provides traceability
- **If unclear, ask for clarification** - don't assume intent

## Example Comment Reply Format

For code fixes:
> Fixed in commit abc1234 - removed the unused function call that was causing the NameError.

For questions:
> No, the login form does not use CSRF tokens, so this code path is never executed. Removed in commit def5678.

For explanations (no code change):
> This is intentional - the retry logic handles transient network failures. The 3-second timeout is sufficient for our use case based on p99 latency measurements.
