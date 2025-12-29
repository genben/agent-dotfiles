#!/bin/bash
#
# Install script for agent-dotfiles
# Symlinks commands, agents, and skills directories to ~/.claude/
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
INTERACTIVE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive|-n)
            INTERACTIVE=false
            shift
            ;;
        --help|-h)
            echo "Install agent-dotfiles for Claude Code CLI"
            echo ""
            echo "This script creates symlinks from this repository to ~/.claude/, making"
            echo "custom commands, agents, and skills available in Claude Code CLI."
            echo ""
            echo "Symlinks created:"
            echo "  claude/commands/ -> ~/.claude/commands/"
            echo "  claude/agents/   -> ~/.claude/agents/"
            echo "  claude/skills/   -> ~/.claude/skills/"
            echo ""
            echo "The script is idempotent: running it multiple times is safe. Existing"
            echo "symlinks pointing to the correct location are left unchanged."
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -n, --non-interactive  Run without prompts. Exits with error on conflicts"
            echo "                         instead of asking the user. Useful for CI/automation."
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Conflict handling:"
            echo "  If a destination directory already exists (not as a symlink), the script"
            echo "  will ask whether to skip it. In non-interactive mode, it exits with an error."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

DIRECTORIES=("commands" "agents" "skills")

echo "Installing agent-dotfiles to ${CLAUDE_HOME}..."
echo ""

# Ensure ~/.claude exists
if [[ ! -d "$CLAUDE_HOME" ]]; then
    echo "Creating ${CLAUDE_HOME}..."
    mkdir -p "$CLAUDE_HOME"
fi

skipped=()
installed=()
already_linked=()
errors=()

for dir in "${DIRECTORIES[@]}"; do
    src="${SCRIPT_DIR}/claude/${dir}"
    dest="${CLAUDE_HOME}/${dir}"

    # Check if source directory exists
    if [[ ! -d "$src" ]]; then
        echo "  [SKIP] ${dir}: source directory does not exist"
        skipped+=("$dir")
        continue
    fi

    # Check if destination is already a symlink
    if [[ -L "$dest" ]]; then
        # Check if it points to the correct location
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            echo "  [OK] ${dir}: symlink already exists"
            already_linked+=("$dir")
            continue
        else
            echo "  [WARN] ${dir}: symlink exists but points to ${current_target}"
            if [[ "$INTERACTIVE" == true ]]; then
                read -p "  Replace symlink? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$dest"
                    ln -s "$src" "$dest"
                    echo "  [DONE] ${dir}: symlink updated"
                    installed+=("$dir")
                else
                    echo "  [SKIP] ${dir}: skipped by user"
                    skipped+=("$dir")
                fi
            else
                echo "  [ERROR] ${dir}: symlink conflict (non-interactive mode)"
                errors+=("$dir")
            fi
            continue
        fi
    fi

    # Check if destination is a regular directory
    if [[ -d "$dest" ]]; then
        echo "  [CONFLICT] ${dir}: directory already exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip this directory and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "  [SKIP] ${dir}: skipped by user"
                skipped+=("$dir")
            else
                echo ""
                echo "Aborted. Please remove or rename ${dest} and try again."
                exit 1
            fi
        else
            echo "  [ERROR] ${dir}: cannot create symlink (non-interactive mode)"
            errors+=("$dir")
        fi
        continue
    fi

    # Check if destination is a file
    if [[ -e "$dest" ]]; then
        echo "  [CONFLICT] ${dir}: file exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "  [SKIP] ${dir}: skipped by user"
                skipped+=("$dir")
            else
                echo ""
                echo "Aborted. Please remove ${dest} and try again."
                exit 1
            fi
        else
            echo "  [ERROR] ${dir}: cannot create symlink (non-interactive mode)"
            errors+=("$dir")
        fi
        continue
    fi

    # Create symlink
    ln -s "$src" "$dest"
    echo "  [DONE] ${dir}: symlink created"
    installed+=("$dir")
done

echo ""

# Exit with error if there were conflicts in non-interactive mode
if [[ ${#errors[@]} -gt 0 ]]; then
    echo "Failed to install: ${errors[*]}"
    echo "Run in interactive mode or resolve conflicts manually."
    exit 1
fi

# Summary
if [[ ${#installed[@]} -gt 0 ]]; then
    echo "Installed: ${installed[*]}"
fi
if [[ ${#already_linked[@]} -gt 0 ]]; then
    echo "Already installed: ${already_linked[*]}"
fi
if [[ ${#skipped[@]} -gt 0 ]]; then
    echo "Skipped: ${skipped[*]}"
fi

echo ""
echo "Done! Your custom commands and skills are now available in Claude Code CLI."
echo "Restart Claude Code or start a new session to use them."
