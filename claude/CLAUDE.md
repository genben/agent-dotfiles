## Code Style

Avoid over-engineering. Only make changes that are directly requested or clearly necessary. Keep solutions simple and focused.

Don't add features, refactor code, or make "improvements" beyond what was asked. A bug fix doesn't need surrounding code cleaned up. A simple feature doesn't need extra configurability.

Don't add error handling, fallbacks, or validation for scenarios that can't happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs). Don't use backwards-compatibility shims when you can just change the code.

Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements. The right amount of complexity is the minimum needed for the current task. Reuse existing abstractions where possible and follow the DRY principle.

When committing to git, do not add "Generated with" or "Co-Authored-By" lines to the messages.

When running git commands, avoid using "-C dir" command-line argument.
- When running git commands do not use format 'git -C DIR cmd'. Instead call 'git cmd'. If required, `cd` into dir before it. But skip `cd` if the current working directory is already DIR.

## PR Review Guidelines

When reviewing pull requests:

1. First run `gh pr diff --name-only` to see all changed files
2. Exclude non-code files from the diff (e.g., `uv.lock`, `package-lock.json`)
3. If the diff is large, review file-by-file using `gh pr diff -- "path/to/file"` or the Read tool
4. Never fabricate or guess code content - always read the actual files before commenting on them