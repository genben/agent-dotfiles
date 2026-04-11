#!/bin/bash
#
# Migration script for agent-dotfiles
# Removes legacy symlinks (commands, agents, scripts, templates) that are
# no longer installed after the move to skills-only.
#
# Only removes symlinks pointing to this repository. Regular directories
# or symlinks pointing elsewhere are left untouched.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Convert absolute path to use ~/ if under home directory
to_display_path() {
    local path="$1"
    if [[ "$path" == "$HOME"/* ]]; then
        echo "~${path#$HOME}"
    else
        echo "$path"
    fi
}

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BOLD=''
    NC=''
fi

# Legacy symlinks to clean up: "source_dir:dest_path"
LEGACY=(
    "templates:${HOME}/.agents/templates"
    "scripts:${HOME}/.agents/scripts"
    "commands:${HOME}/.claude/commands"
    "agents:${HOME}/.claude/agents"
    "commands:${HOME}/.codex/prompts"
)

removed=()
skipped_not_symlink=()
skipped_different_target=()
skipped_not_exist=()
errors=()

echo -e "${BOLD}Cleaning up legacy symlinks...${NC}"
echo ""

for entry in "${LEGACY[@]}"; do
    src_dir="${entry%%:*}"
    dest="${entry#*:}"
    src="${SCRIPT_DIR}/${src_dir}"
    dest_display="$(to_display_path "$dest")"

    # Does not exist — nothing to do
    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${dest_display}: does not exist"
        skipped_not_exist+=("$dest_display")
        continue
    fi

    # Exists but is not a symlink — leave it alone
    if [[ ! -L "$dest" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${dest_display}: not a symlink (regular directory/file)"
        skipped_not_symlink+=("$dest_display")
        continue
    fi

    # Symlink exists but points somewhere else — leave it alone
    current_target="$(readlink "$dest")"
    if [[ "$current_target" != "$src" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${dest_display}: symlink points to ${current_target}"
        skipped_different_target+=("$dest_display")
        continue
    fi

    # Symlink points to our repo — remove it
    if rm "$dest" 2>/dev/null; then
        echo -e "  ${GREEN}[DONE]${NC} ${dest_display}: removed"
        removed+=("$dest_display")
    else
        echo -e "  ${RED}[ERROR]${NC} ${dest_display}: failed to remove"
        errors+=("$dest_display")
    fi
done

echo ""
echo "────────────────────────────────────────"
echo ""

# Summary
if [[ ${#removed[@]} -gt 0 ]]; then
    echo -e "${GREEN}Removed:${NC}"
    for item in "${removed[@]}"; do
        echo -e "  ${GREEN}${item}${NC}"
    done
fi

if [[ ${#skipped_not_symlink[@]} -gt 0 || ${#skipped_different_target[@]} -gt 0 ]]; then
    if [[ ${#removed[@]} -gt 0 ]]; then
        echo ""
    fi
    echo -e "${YELLOW}Skipped (not managed by this repo):${NC}"
    for item in "${skipped_not_symlink[@]}"; do
        echo -e "  ${YELLOW}${item}${NC} (not a symlink)"
    done
    for item in "${skipped_different_target[@]}"; do
        echo -e "  ${YELLOW}${item}${NC} (points elsewhere)"
    done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed to remove:${NC}"
    for item in "${errors[@]}"; do
        echo -e "  ${RED}${item}${NC}"
    done
    exit 1
fi

if [[ ${#removed[@]} -eq 0 && ${#skipped_not_symlink[@]} -eq 0 && ${#skipped_different_target[@]} -eq 0 && ${#skipped_not_exist[@]} -eq 0 ]]; then
    echo "Nothing to clean up."
fi
