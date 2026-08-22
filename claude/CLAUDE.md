## Writing Style

Write all text for a human reader — chat responses, commit messages, PR descriptions, docs, and code comments — use Microsoft Style Guide for techical writing.

## Code Style

When committing to git, do not add "Generated with" or "Co-Authored-By" lines to the messages.

## PR Review Guidelines

When reviewing pull requests:

1. First run `gh pr diff --name-only` to see all changed files
2. Exclude non-code files from the diff (e.g., `uv.lock`, `package-lock.json`)
3. If the diff is large, review file-by-file using `gh pr diff -- "path/to/file"` or the Read tool
4. Never fabricate or guess code content - always read the actual files before commenting on them