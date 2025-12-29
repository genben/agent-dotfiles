#!/bin/bash
#
# Install script for agent-dotfiles
# Symlinks commands, agents, and skills directories to ~/.claude/
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
INTERACTIVE=true

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

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
            echo "custom commands, agents, skills, and templates available in Claude Code CLI."
            echo ""
            echo "Symlinks created:"
            echo "  claude/commands/  -> ~/.claude/commands/"
            echo "  claude/agents/    -> ~/.claude/agents/"
            echo "  claude/skills/    -> ~/.claude/skills/"
            echo "  claude/templates/ -> ~/.claude/templates/"
            echo "  claude/scripts/   -> ~/.claude/scripts/"
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

DIRECTORIES=("commands" "agents" "skills" "templates" "scripts")

echo -e "${BOLD}Installing agent-dotfiles to ${CLAUDE_HOME}...${NC}"
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
        echo -e "  ${YELLOW}[SKIP]${NC} ${dir}: source directory does not exist"
        skipped+=("$dir")
        continue
    fi

    # Check if destination is already a symlink
    if [[ -L "$dest" ]]; then
        # Check if it points to the correct location
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            echo -e "  ${GREEN}[OK]${NC} ${dir}: symlink already exists"
            already_linked+=("$dir")
            continue
        else
            echo -e "  ${YELLOW}[WARN]${NC} ${dir}: symlink exists but points to ${current_target}"
            if [[ "$INTERACTIVE" == true ]]; then
                read -p "  Replace symlink? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$dest"
                    ln -s "$src" "$dest"
                    echo -e "  ${GREEN}[DONE]${NC} ${dir}: symlink updated"
                    installed+=("$dir")
                else
                    echo -e "  ${YELLOW}[SKIP]${NC} ${dir}: skipped by user"
                    skipped+=("$dir")
                fi
            else
                echo -e "  ${RED}[ERROR]${NC} ${dir}: symlink conflict (non-interactive mode)"
                errors+=("$dir")
            fi
            continue
        fi
    fi

    # Check if destination is a regular directory
    if [[ -d "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${dir}: directory already exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip this directory and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${dir}: skipped by user"
                skipped+=("$dir")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove or rename ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${dir}: cannot create symlink (non-interactive mode)"
            errors+=("$dir")
        fi
        continue
    fi

    # Check if destination is a file
    if [[ -e "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${dir}: file exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${dir}: skipped by user"
                skipped+=("$dir")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${dir}: cannot create symlink (non-interactive mode)"
            errors+=("$dir")
        fi
        continue
    fi

    # Create symlink
    ln -s "$src" "$dest"
    echo -e "  ${GREEN}[DONE]${NC} ${dir}: symlink created"
    installed+=("$dir")
done

echo ""
echo "────────────────────────────────────────"
echo ""

# Exit with error if there were conflicts in non-interactive mode
if [[ ${#errors[@]} -gt 0 ]]; then
    echo -e "${RED}Failed to install:${NC} ${errors[*]}"
    echo "Run in interactive mode or resolve conflicts manually."
    exit 1
fi

# Summary
if [[ ${#installed[@]} -gt 0 || ${#already_linked[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully installed (symlinks):${NC}"
    echo ""
    for dir in "${installed[@]}" "${already_linked[@]}"; do
        echo -e "  ${CLAUDE_HOME}/${dir} => ${SCRIPT_DIR}/claude/${dir}"
    done
    echo ""
    echo "Restart Claude Code or start a new session to use them."
fi

if [[ ${#skipped[@]} -gt 0 ]]; then
    if [[ ${#installed[@]} -gt 0 || ${#already_linked[@]} -gt 0 ]]; then
        echo ""
        echo "────────────────────────────────────────"
    fi
    echo ""
    echo -e "${RED}NOT INSTALLED (skipped due to directories already exist):${NC}"
    echo ""
    for dir in "${skipped[@]}"; do
        echo -e "${RED}  ${CLAUDE_HOME}/${dir}${NC}"
    done
fi
