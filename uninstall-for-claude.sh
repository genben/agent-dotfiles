#!/bin/bash
#
# Uninstall script for agent-dotfiles
# Removes symlinks from ~/.claude/ that point to this repository
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"

# Convert absolute path to use ~/ if under home directory
to_display_path() {
    local path="$1"
    if [[ "$path" == "$HOME"/* ]]; then
        echo "~${path#$HOME}"
    else
        echo "$path"
    fi
}

CLAUDE_HOME_DISPLAY="$(to_display_path "$CLAUDE_HOME")"

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
        --help|-h)
            echo "Uninstall agent-dotfiles for Claude Code CLI"
            echo ""
            echo "This script removes symlinks from ~/.claude/ that were created by"
            echo "the install script and point to this repository."
            echo ""
            echo "Symlinks removed (if they point to this repo):"
            echo "  ~/.claude/commands/"
            echo "  ~/.claude/agents/"
            echo "  ~/.claude/skills/"
            echo "  ~/.claude/templates/"
            echo "  ~/.claude/scripts/"
            echo ""
            echo "Symlinks pointing elsewhere are left unchanged."
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help  Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

DIRECTORIES=("commands" "agents" "skills" "templates" "scripts")

echo -e "${BOLD}Uninstalling agent-dotfiles from ${CLAUDE_HOME}...${NC}"
echo ""

removed=()
skipped_not_symlink=()
skipped_different_target=()
skipped_not_exist=()
errors=()

for dir in "${DIRECTORIES[@]}"; do
    src="${SCRIPT_DIR}/claude/${dir}"
    dest="${CLAUDE_HOME}/${dir}"

    # Check if destination exists
    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        echo -e "  ${BLUE}[SKIP]${NC} ${dir}: does not exist"
        skipped_not_exist+=("$dir")
        continue
    fi

    # Check if destination is a symlink
    if [[ ! -L "$dest" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${dir}: not a symlink (regular directory/file)"
        skipped_not_symlink+=("$dir")
        continue
    fi

    # Check if symlink points to our directory
    current_target="$(readlink "$dest")"
    if [[ "$current_target" != "$src" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${dir}: symlink points to ${current_target}"
        skipped_different_target+=("$dir")
        continue
    fi

    # Remove symlink
    if rm "$dest" 2>/dev/null; then
        echo -e "  ${GREEN}[DONE]${NC} ${dir}: symlink removed"
        removed+=("$dir")
    else
        echo -e "  ${RED}[ERROR]${NC} ${dir}: failed to remove symlink"
        errors+=("$dir")
    fi
done

echo ""
echo "────────────────────────────────────────"
echo ""

# Summary
if [[ ${#removed[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully removed:${NC}"
    echo ""
    for dir in "${removed[@]}"; do
        echo -e "  ${GREEN}${CLAUDE_HOME_DISPLAY}/${dir}${NC}"
    done
fi

if [[ ${#skipped_not_symlink[@]} -gt 0 || ${#skipped_different_target[@]} -gt 0 ]]; then
    if [[ ${#removed[@]} -gt 0 ]]; then
        echo ""
        echo "────────────────────────────────────────"
    fi
    echo ""
    echo -e "${YELLOW}Skipped (not managed by this repo):${NC}"
    echo ""
    for dir in "${skipped_not_symlink[@]}"; do
        echo -e "  ${YELLOW}${CLAUDE_HOME_DISPLAY}/${dir}${NC} (not a symlink)"
    done
    for dir in "${skipped_different_target[@]}"; do
        echo -e "  ${YELLOW}${CLAUDE_HOME_DISPLAY}/${dir}${NC} (points elsewhere)"
    done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    if [[ ${#removed[@]} -gt 0 || ${#skipped_not_symlink[@]} -gt 0 || ${#skipped_different_target[@]} -gt 0 ]]; then
        echo ""
        echo "────────────────────────────────────────"
    fi
    echo ""
    echo -e "${RED}Failed to remove:${NC}"
    echo ""
    for dir in "${errors[@]}"; do
        echo -e "  ${RED}${CLAUDE_HOME_DISPLAY}/${dir}${NC}"
    done
    exit 1
fi

if [[ ${#removed[@]} -eq 0 && ${#skipped_not_symlink[@]} -eq 0 && ${#skipped_different_target[@]} -eq 0 ]]; then
    echo "Nothing to uninstall."
fi
