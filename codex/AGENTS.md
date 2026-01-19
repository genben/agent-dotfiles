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
- Use Conventional Commits spec to write git messages

## Commands
- Do not prefix every command with `cd REPO_DIR &&` if you are in the current dir.


## Template Reply
```markdown
**What Changed**
- Updated example logic to handle edge cases and keep output stable.

**Files Affected**
- `src/example.py`

**Tests Run**
- ✅ `uv run pytest tests/test_example.py`

**Issues**
- ⚠️ Intermittent timeout in `tests/test_example.py::test_flaky_case`.

**Next Steps**
- ❓ Do you want me to investigate the flaky test now?
- ☐ Run the full test suite if you want broader coverage.
```
