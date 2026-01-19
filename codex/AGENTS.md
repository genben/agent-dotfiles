## Response Formatting
- Prefer a human-friendly summary: short headings + bullets.
- When reporting actions, include: What changed, Files affected, Tests run, Next steps.
- Keep language plain and avoid raw command logs unless asked.
- Use the "Template Reply" section below as the response format reference.
- Omit any section entirely if it has no items.

## Testing Expectations
- After editing source code files, always run relevant tests (pytest, ctest, etc.) before declaring the task complete.

## Playwright Notes
- If Playwright-specific tests fail, it's most likely due to sandbox permission restrictions. Ask the user to escalate permissions and rerun.

## Code Style
- Default to `line-length = 120` for code unless instructed otherwise.

## API Compatibility
- Do not keep legacy wrapper functions for convenience/backward compatibility unless the user explicitly instructs to keep them.

## Git
- When committing, stage/commit ONLY files you intentionally changed for the current task; do not include unrelated modified files without explicit user approval.
- Never run potentially destructive Git commands (e.g. `git restore`, `git reset`, `git checkout --`, `git clean`) without explicit user approval.
- Use Conventional Commits spec for commit messages.
- Include the WHY in commit messages, not just WHAT changed. For issues fixed, include root cause analysis.
- Split large changes into multiple focused commits rather than one big commit.

## Commands
- Do not prefix every command with `cd REPO_DIR &&` if you are in the current dir.
- Prefer `python3` over `python` unless the project uses `python` explicitly.
- Prefer `uv` wrapper for commands when available (e.g., `uv run pytest` instead of `pytest`).


## Template Reply
```markdown
**What Changed**
[[Summarize the changes made in this task, starting with Why the change was needed]]

**Root Cause Analysis**
[[When working on fixing issues, explain what caused the issue, impact, how to reproduce and how you resolved it]]

**Files Affected**
- `src/example.py`

**Tests Run**
- ✅ `uv run pytest tests/test_example.py`

**Deviations from Plan**
[[Describe any major deviations from the original plan and why they were necessary.]]

**Learnings**
[[Any notable learnings or discoveries made during the task, which could help future work. Patterns, anti-patterns, troubleshooting tips, etc.]]

**Non-Resolved Issues**
[[Describe the impact, what you tried, how to reproduce and your hypothesis of how to resolve it.]]
- ⚠️ Intermittent timeout in `tests/test_example.py::test_flaky_case`.

**Next Steps**
- ❓ Do you want me to investigate the flaky test now?
- ☐ Push changes to GitHub.
```
