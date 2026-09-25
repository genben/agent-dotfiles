This repository contains AI coding agent configurations (skills, config files) that can be symlinked to `~/.claude/`, `~/.codex/`, `~/.agents/` and `~/.pi/` for use with various coding agents (Claude Code, Codex, PI).

## Repository Structure

- `skills/` - Skills, installed into `~/.agents/skills`. This location is recognized by all coding agents.
- `claude/` - Claude Code config files (e.g. `CLAUDE.md`, installed into `~/.claude/`)
- `codex/` - Codex config files (e.g. `AGENTS.md`, installed into `~/.codex/`)
- `pi/` - PI extensions and themes (installed into `~/.pi/agent/`)
- `_archive/` - Archived commands, agents, scripts, and templates (not installed). Can be migrated to skills as needed.

## Installation

```bash
./install.sh claude               # Install for Claude Code
./install.sh codex                # Install for Codex
./install.sh pi                   # Install for PI
./install.sh claude -n            # Non-interactive mode (for CI/automation)
./uninstall.sh claude             # Remove symlinks
./uninstall.sh codex              # Remove symlinks
./uninstall.sh pi                 # Remove symlinks
```

`install.ps1` / `uninstall.ps1` are the Windows PowerShell equivalents, with the same
arguments (`.\install.ps1 claude -n`). Keep the two versions in sync when changing the
mappings. On Windows, directories fall back to junctions and files to hard links when
symlink creation is not permitted.

All scripts are idempotent and can be safely re-run.
