# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains AI coding agent configurations (commands, skills, templates) that can be symlinked to `~/.claude/` for use with Claude Code.

## Repository Structure

- `claude/commands/` - Custom slash commands
- `claude/agents/` - Agent definitions
- `claude/skills/` - Skill definitions
- `claude/templates/` - Reusable templates
- `claude/scripts/` - Helper scripts

## Installation

Run the install script to symlink directories to `~/.claude/`:

```bash
./install-for-claude.sh           # Interactive mode
./install-for-claude.sh -n        # Non-interactive mode (for CI/automation)
./uninstall-for-claude.sh         # Remove symlinks
```

Both scripts are idempotent and can be safely re-run.
