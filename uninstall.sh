#!/bin/bash
#
# Uninstall script for agent-dotfiles
# Removes symlinks from the appropriate agent config location
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT=""

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

usage() {
    echo "Uninstall agent-dotfiles for AI coding agents"
    echo ""
    echo "Usage: $0 <agent> [OPTIONS]"
    echo ""
    echo "Targets:"
    echo "  claude    Uninstall from Claude Code CLI (~/.claude/)"
    echo "  codex     Uninstall from Codex CLI (~/.codex/)"
    echo "  shared    Uninstall shared resources (~/.agents/)"
    echo ""
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 claude   Uninstall from Claude Code"
    echo "  $0 codex    Uninstall from Codex"
    echo "  $0 shared   Uninstall shared resources only"
    echo ""
    echo "Only symlinks pointing to this repository are removed."
    echo "Symlinks pointing elsewhere are left unchanged."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        claude|codex|shared)
            AGENT="$1"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
done

# Validate agent is specified
if [[ -z "$AGENT" ]]; then
    echo "Error: No agent specified."
    echo ""
    usage
    exit 1
fi

# Configuration
# Format: "source_dir:dest_dir" (dest_dir optional, defaults to source_dir)
case $AGENT in
    shared)
        AGENT_HOME="${HOME}/.agents"
        MAPPINGS=("skills" "templates" "scripts")
        FILE_MAPPINGS=()
        AGENT_DISPLAY="shared resources"
        ;;
    claude)
        AGENT_HOME="${HOME}/.claude"
        MAPPINGS=("commands" "agents")
        FILE_MAPPINGS=("claude/CLAUDE.md:CLAUDE.md")
        AGENT_DISPLAY="Claude Code"
        ;;
    codex)
        AGENT_HOME="${HOME}/.codex"
        MAPPINGS=("commands:prompts")
        FILE_MAPPINGS=("codex/AGENTS.md:AGENTS.md")
        AGENT_DISPLAY="Codex"
        ;;
esac

AGENT_HOME_DISPLAY="$(to_display_path "$AGENT_HOME")"

removed=()
skipped_not_symlink=()
skipped_different_target=()
skipped_not_exist=()
errors=()

# Remove a symlink if it points to our repo: unlink_symlink <src> <dest> <label>
unlink_symlink() {
    local src="$1" dest="$2" label="$3"
    local dest_display="$(to_display_path "$dest")"

    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        echo -e "  ${BLUE}[SKIP]${NC} ${label}: does not exist"
        skipped_not_exist+=("$dest_display")
        return
    fi

    if [[ ! -L "$dest" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${label}: not a symlink (regular directory/file)"
        skipped_not_symlink+=("$dest_display")
        return
    fi

    current_target="$(readlink "$dest")"
    if [[ "$current_target" != "$src" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${label}: symlink points to ${current_target}"
        skipped_different_target+=("$dest_display")
        return
    fi

    if rm "$dest" 2>/dev/null; then
        echo -e "  ${GREEN}[DONE]${NC} ${label}: symlink removed"
        removed+=("$dest_display")
    else
        echo -e "  ${RED}[ERROR]${NC} ${label}: failed to remove symlink"
        errors+=("$dest_display")
    fi
}

echo -e "${BOLD}Uninstalling agent-dotfiles for ${AGENT_DISPLAY} from ${AGENT_HOME_DISPLAY}...${NC}"
echo ""

# Remove directory symlinks
for entry in "${MAPPINGS[@]}"; do
    src_dir="${entry%%:*}"
    dest_dir="${entry#*:}"
    [[ "$dest_dir" == "$entry" ]] && dest_dir="$src_dir"

    src="${SCRIPT_DIR}/${src_dir}"
    dest="${AGENT_HOME}/${dest_dir}"
    unlink_symlink "$src" "$dest" "${dest_dir}"
done

# Remove agent-specific file symlinks
for entry in "${FILE_MAPPINGS[@]}"; do
    src_file="${entry%%:*}"
    dest_file="${entry#*:}"

    src="${SCRIPT_DIR}/${src_file}"
    dest="${AGENT_HOME}/${dest_file}"
    unlink_symlink "$src" "$dest" "${dest_file}"
done

echo ""
echo "────────────────────────────────────────"
echo ""

# Summary
if [[ ${#removed[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully removed:${NC}"
    echo ""
    for item in "${removed[@]}"; do
        echo -e "  ${GREEN}${item}${NC}"
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
    for item in "${skipped_not_symlink[@]}"; do
        echo -e "  ${YELLOW}${item}${NC} (not a symlink)"
    done
    for item in "${skipped_different_target[@]}"; do
        echo -e "  ${YELLOW}${item}${NC} (points elsewhere)"
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
    for item in "${errors[@]}"; do
        echo -e "  ${RED}${item}${NC}"
    done
    exit 1
fi

if [[ ${#removed[@]} -eq 0 && ${#skipped_not_symlink[@]} -eq 0 && ${#skipped_different_target[@]} -eq 0 ]]; then
    echo "Nothing to uninstall."
fi
