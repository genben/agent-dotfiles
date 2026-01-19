#!/bin/bash
#
# Install script for agent-dotfiles
# Symlinks directories to the appropriate agent config location
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERACTIVE=true
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
    echo "Install agent-dotfiles for AI coding agents"
    echo ""
    echo "Usage: $0 <agent> [OPTIONS]"
    echo ""
    echo "Agents:"
    echo "  claude    Install for Claude Code CLI (~/.claude/)"
    echo "  codex     Install for Codex CLI (~/.codex/)"
    echo ""
    echo "Options:"
    echo "  -n, --non-interactive  Run without prompts. Exits with error on conflicts"
    echo "                         instead of asking the user. Useful for CI/automation."
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 claude              Install for Claude Code"
    echo "  $0 codex -n            Install for Codex (non-interactive)"
    echo ""
    echo "The script is idempotent: running it multiple times is safe. Existing"
    echo "symlinks pointing to the correct location are left unchanged."
    echo ""
    echo "Conflict handling:"
    echo "  If a destination directory already exists (not as a symlink), the script"
    echo "  will ask whether to skip it. In non-interactive mode, it exits with an error."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        claude|codex)
            AGENT="$1"
            shift
            ;;
        --non-interactive|-n)
            INTERACTIVE=false
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

# Set agent-specific configuration
# Format: "source_dir:dest_dir" (dest_dir optional, defaults to source_dir)
case $AGENT in
    claude)
        AGENT_HOME="${HOME}/.claude"
        MAPPINGS=("commands" "agents" "skills" "templates" "scripts")
        FILE_MAPPINGS=("claude/CLAUDE.md:CLAUDE.md")
        AGENT_DISPLAY="Claude Code"
        ;;
    codex)
        AGENT_HOME="${HOME}/.codex"
        MAPPINGS=("commands:prompts" "skills" "templates" "scripts")
        FILE_MAPPINGS=("codex/AGENTS.md:AGENTS.md")
        AGENT_DISPLAY="Codex"
        ;;
esac

AGENT_HOME_DISPLAY="$(to_display_path "$AGENT_HOME")"
SCRIPT_DIR_DISPLAY="$(to_display_path "$SCRIPT_DIR")"

echo -e "${BOLD}Installing agent-dotfiles for ${AGENT_DISPLAY} to ${AGENT_HOME_DISPLAY}...${NC}"
echo ""

# Ensure agent home exists
if [[ ! -d "$AGENT_HOME" ]]; then
    echo "Creating ${AGENT_HOME_DISPLAY}..."
    mkdir -p "$AGENT_HOME"
fi

skipped=()
installed=()
already_linked=()
errors=()

for entry in "${MAPPINGS[@]}"; do
    # Parse source:dest format
    src_dir="${entry%%:*}"
    dest_dir="${entry#*:}"
    [[ "$dest_dir" == "$entry" ]] && dest_dir="$src_dir"

    src="${SCRIPT_DIR}/${src_dir}"
    dest="${AGENT_HOME}/${dest_dir}"

    # Check if source directory exists
    if [[ ! -d "$src" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${dest_dir}: source directory does not exist"
        skipped+=("$entry")
        continue
    fi

    # Check if destination is already a symlink
    if [[ -L "$dest" ]]; then
        # Check if it points to the correct location
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            echo -e "  ${BLUE}[OK]${NC} ${dest_dir}: symlink already exists"
            already_linked+=("$entry")
            continue
        else
            echo -e "  ${YELLOW}[WARN]${NC} ${dest_dir}: symlink exists but points to ${current_target}"
            if [[ "$INTERACTIVE" == true ]]; then
                read -p "  Replace symlink? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$dest"
                    ln -s "$src" "$dest"
                    echo -e "  ${GREEN}[DONE]${NC} ${dest_dir}: symlink updated"
                    installed+=("$entry")
                else
                    echo -e "  ${YELLOW}[SKIP]${NC} ${dest_dir}: skipped by user"
                    skipped+=("$entry")
                fi
            else
                echo -e "  ${RED}[ERROR]${NC} ${dest_dir}: symlink conflict (non-interactive mode)"
                errors+=("$entry")
            fi
            continue
        fi
    fi

    # Check if destination is a regular directory
    if [[ -d "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${dest_dir}: directory already exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip this directory and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${dest_dir}: skipped by user"
                skipped+=("$entry")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove or rename ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${dest_dir}: cannot create symlink (non-interactive mode)"
            errors+=("$entry")
        fi
        continue
    fi

    # Check if destination is a file
    if [[ -e "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${dest_dir}: file exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${dest_dir}: skipped by user"
                skipped+=("$entry")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${dest_dir}: cannot create symlink (non-interactive mode)"
            errors+=("$entry")
        fi
        continue
    fi

    # Create symlink
    ln -s "$src" "$dest"
    echo -e "  ${GREEN}[DONE]${NC} ${dest_dir}: symlink created"
    installed+=("$entry")
done

# Process file mappings
for entry in "${FILE_MAPPINGS[@]}"; do
    # Parse source:dest format
    src_file="${entry%%:*}"
    dest_file="${entry#*:}"

    src="${SCRIPT_DIR}/${src_file}"
    dest="${AGENT_HOME}/${dest_file}"

    # Check if source file exists
    if [[ ! -f "$src" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${dest_file}: source file does not exist"
        skipped+=("$entry")
        continue
    fi

    # Check if destination is already a symlink
    if [[ -L "$dest" ]]; then
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            echo -e "  ${BLUE}[OK]${NC} ${dest_file}: symlink already exists"
            already_linked+=("$entry")
            continue
        else
            echo -e "  ${YELLOW}[WARN]${NC} ${dest_file}: symlink exists but points to ${current_target}"
            if [[ "$INTERACTIVE" == true ]]; then
                read -p "  Replace symlink? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$dest"
                    ln -s "$src" "$dest"
                    echo -e "  ${GREEN}[DONE]${NC} ${dest_file}: symlink updated"
                    installed+=("$entry")
                else
                    echo -e "  ${YELLOW}[SKIP]${NC} ${dest_file}: skipped by user"
                    skipped+=("$entry")
                fi
            else
                echo -e "  ${RED}[ERROR]${NC} ${dest_file}: symlink conflict (non-interactive mode)"
                errors+=("$entry")
            fi
            continue
        fi
    fi

    # Check if destination is a regular file
    if [[ -f "$dest" ]]; then
        echo -e "  ${YELLOW}[CONFLICT]${NC} ${dest_file}: file already exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Replace file? (existing file will be backed up) [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                backup_suffix=".backup_$(date +%Y_%m_%d).md"
                backup_file="${dest%.md}${backup_suffix}"
                mv "$dest" "$backup_file"
                backup_display="$(to_display_path "$backup_file")"
                echo -e "  ${BLUE}[BACKUP]${NC} ${dest_file}: backed up to ${backup_display}"
                ln -s "$src" "$dest"
                echo -e "  ${GREEN}[DONE]${NC} ${dest_file}: symlink created"
                installed+=("$entry")
            else
                echo -e "  ${YELLOW}[SKIP]${NC} ${dest_file}: skipped by user"
                skipped+=("$entry")
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${dest_file}: file conflict (non-interactive mode)"
            errors+=("$entry")
        fi
        continue
    fi

    # Check if destination is a directory
    if [[ -d "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${dest_file}: directory exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${dest_file}: skipped by user"
                skipped+=("$entry")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${dest_file}: cannot create symlink (non-interactive mode)"
            errors+=("$entry")
        fi
        continue
    fi

    # Create symlink
    ln -s "$src" "$dest"
    echo -e "  ${GREEN}[DONE]${NC} ${dest_file}: symlink created"
    installed+=("$entry")
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
if [[ ${#installed[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully installed (symlinks):${NC}"
    echo ""
    for entry in "${installed[@]}"; do
        src_dir="${entry%%:*}"
        dest_dir="${entry#*:}"
        [[ "$dest_dir" == "$entry" ]] && dest_dir="$src_dir"
        echo -e "  ${GREEN}${AGENT_HOME_DISPLAY}/${dest_dir}${NC} => ${SCRIPT_DIR_DISPLAY}/${src_dir}"
    done
    echo ""
    echo "Restart ${AGENT_DISPLAY} or start a new session to use them."
fi

if [[ ${#already_linked[@]} -gt 0 ]]; then
    if [[ ${#installed[@]} -gt 0 ]]; then
        echo ""
        echo "────────────────────────────────────────"
        echo ""
    fi
    echo -e "${BLUE}Already installed (no changes):${NC}"
    echo ""
    for entry in "${already_linked[@]}"; do
        src_dir="${entry%%:*}"
        dest_dir="${entry#*:}"
        [[ "$dest_dir" == "$entry" ]] && dest_dir="$src_dir"
        echo -e "  ${BLUE}${AGENT_HOME_DISPLAY}/${dest_dir}${NC} => ${SCRIPT_DIR_DISPLAY}/${src_dir}"
    done
fi

if [[ ${#skipped[@]} -gt 0 ]]; then
    if [[ ${#installed[@]} -gt 0 || ${#already_linked[@]} -gt 0 ]]; then
        echo ""
        echo "────────────────────────────────────────"
    fi
    echo ""
    echo -e "${RED}NOT INSTALLED (skipped due to directories already exist):${NC}"
    echo ""
    for entry in "${skipped[@]}"; do
        dest_dir="${entry#*:}"
        [[ "$dest_dir" == "$entry" ]] && dest_dir="${entry%%:*}"
        echo -e "  ${RED}${AGENT_HOME_DISPLAY}/${dest_dir}${NC}"
    done
fi
