# agent-dotfiles

Custom configurations for AI coding agents (Claude Code, Codex, PI). This repository contains skills and agent-specific config files that extend agent capabilities.

## Supported Agents

| Agent | Config Location | Status |
|-------|-----------------|--------|
| Claude Code | `~/.claude/` | Full support |
| Codex | `~/.codex/` | Partial |
| PI | `~/.pi/agent/` | Extensions & themes |

## Installation

macOS / Linux:

```bash
# Clone the repository
git clone https://github.com/yourusername/agent-dotfiles.git
cd agent-dotfiles

# Install for an agent
./install.sh claude
./install.sh codex
./install.sh pi

# Non-interactive mode (for automation)
./install.sh claude -n
```

Windows (PowerShell):

```powershell
git clone https://github.com/yourusername/agent-dotfiles.git
cd agent-dotfiles

.\install.ps1 claude
.\install.ps1 codex
.\install.ps1 pi

# Non-interactive mode (for automation)
.\install.ps1 claude -n
```

The install script creates symlinks from this repository to the agent's config directory. Skills are installed to `~/.agents/skills/` (shared across all agents), and agent-specific config files are installed to the respective agent's config directory.

## Uninstallation

```bash
./uninstall.sh claude    # Remove Claude Code symlinks
./uninstall.sh codex     # Remove Codex symlinks
./uninstall.sh pi        # Remove PI symlinks
./uninstall.sh shared    # Remove shared resource symlinks
```

```powershell
.\uninstall.ps1 claude   # Same targets on Windows
```

Only links pointing to this repository are removed. Existing directories are left unchanged.

### Windows notes

**Enable Developer Mode** (Settings → System → For developers) to get real symlinks without running as administrator. The script reports which kind of link it created for each entry.

Windows PowerShell 5.1 predates Developer Mode: its `New-Item -ItemType SymbolicLink` never passes `SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE` and fails with *"Administrator privilege required"* even when Developer Mode is on. `install.ps1` works around this by falling back to `mklink`, which does pass the flag.

If symlinks are unavailable entirely (Developer Mode off and not elevated), it degrades further:

| Item | Preferred | Fallback |
|------|-----------|----------|
| Directories (`skills`, `extensions`, `themes`) | Symlink | Directory junction (never needs elevation) |
| Files (`CLAUDE.md`, `AGENTS.md`) | Symlink | Hard link on the same volume |

Both fallbacks work without elevation, but a hard link breaks when git replaces the source file (`pull`, `checkout`, `stash`) — the destination silently keeps the old content. Re-run `.\install.ps1 <agent>` after updating the repository; it sees the stale file and offers to back it up and re-link.

Note that the destination is the *same file* as the one in the repo, whichever link type is used — editing `~\.claude\CLAUDE.md` edits `claude\CLAUDE.md` in this repository.

If PowerShell refuses to run the script, either unblock it once with `Unblock-File .\install.ps1` or run it as `powershell -ExecutionPolicy Bypass -File .\install.ps1 claude`.

## Directory Structure

| Directory | Description | Destination |
|-----------|-------------|-------------|
| `skills/` | Skill definitions (shared across agents) | `~/.agents/skills/` |
| `claude/` | Claude Code config (e.g. `CLAUDE.md`) | `~/.claude/` |
| `codex/` | Codex config (e.g. `AGENTS.md`) | `~/.codex/` |
| `pi/` | PI extensions and themes | `~/.pi/agent/` |
| `_archive/` | Archived commands, agents, scripts, templates | Not installed |

## Available Skills

| Skill | Description |
|-------|-------------|
| `address-pr-comments` | Process and address GitHub Pull Request review comments |
| `circleci` | Troubleshoot CircleCI pipelines and jobs using the CircleCI CLI and API |
| `describe-pr` | Generate comprehensive PR descriptions |
| `playwright` | Automate a real browser from the terminal (navigation, snapshots, screenshots, data extraction) |

To invoke a skill, ask the agent to use it (e.g. "use circleci skill to check build status") or use the slash command shorthand (e.g. `/describe-pr`).

## Archived Commands

Previously, this repository contained custom slash commands, sub-agents, templates, and helper scripts. These have been archived in `_archive/` in favor of skills, which are a well-supported standard that works across multiple coding agents from a single location (`~/.agents/skills/`).

See [docs/ArchivedCommands.md](docs/ArchivedCommands.md) for the full list of archived commands and workflows. These can be migrated to skills if the need arises.

## License

MIT
