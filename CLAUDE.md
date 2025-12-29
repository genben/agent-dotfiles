# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains AI coding agent configurations (commands, skills, templates) that can be symlinked to `~/.claude/` for use with Claude Code.

## Repository Structure

- `commands/` - Custom slash commands (mapped to `prompts/` for Codex)
- `agents/` - Agent definitions
- `skills/` - Skill definitions
- `templates/` - Reusable templates
- `scripts/` - Helper scripts

## Installation

```bash
./install.sh claude               # Install for Claude Code
./install.sh codex                # Install for Codex
./install.sh claude -n            # Non-interactive mode (for CI/automation)
./uninstall.sh claude             # Remove symlinks
./uninstall.sh codex              # Remove symlinks
```

All scripts are idempotent and can be safely re-run.
