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
    echo "  pi        Install for PI (~/.pi/)"
    echo ""
    echo "Skills are installed to ~/.agents/skills/ regardless of which agent is selected."
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
        claude|codex|pi)
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

# Shared configuration (installed for all agents)
SHARED_HOME="${HOME}/.agents"
SHARED_MAPPINGS=("skills")

# Agent-specific configuration
# Format: "source_dir:dest_dir" (dest_dir optional, defaults to source_dir)
case $AGENT in
    claude)
        AGENT_HOME="${HOME}/.claude"
        MAPPINGS=()
        FILE_MAPPINGS=("claude/CLAUDE.md:CLAUDE.md")
        AGENT_DISPLAY="Claude Code"
        ;;
    codex)
        AGENT_HOME="${HOME}/.codex"
        MAPPINGS=()
        FILE_MAPPINGS=("codex/AGENTS.md:AGENTS.md")
        AGENT_DISPLAY="Codex"
        ;;
    pi)
        AGENT_HOME="${HOME}/.pi/agent"
        MAPPINGS=("pi/extensions:extensions" "pi/themes:themes")
        FILE_MAPPINGS=()
        AGENT_DISPLAY="PI"
        ;;
esac

AGENT_HOME_DISPLAY="$(to_display_path "$AGENT_HOME")"
SHARED_HOME_DISPLAY="$(to_display_path "$SHARED_HOME")"
SCRIPT_DIR_DISPLAY="$(to_display_path "$SCRIPT_DIR")"

skipped=()
installed=()
already_linked=()
errors=()

# Install a directory symlink: install_dir_link <src> <dest> <display_label>
install_dir_link() {
    local src="$1" dest="$2" label="$3"
    local display="$(to_display_path "$dest") => $(to_display_path "$src")"

    # Check if source directory exists
    if [[ ! -d "$src" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${label}: source directory does not exist"
        skipped+=("$display")
        return
    fi

    # Check if destination is already a symlink
    if [[ -L "$dest" ]]; then
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            echo -e "  ${BLUE}[OK]${NC} ${label}: symlink already exists"
            already_linked+=("$display")
            return
        else
            echo -e "  ${YELLOW}[WARN]${NC} ${label}: symlink exists but points to ${current_target}"
            if [[ "$INTERACTIVE" == true ]]; then
                read -p "  Replace symlink? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$dest"
                    ln -s "$src" "$dest"
                    echo -e "  ${GREEN}[DONE]${NC} ${label}: symlink updated"
                    installed+=("$display")
                else
                    echo -e "  ${YELLOW}[SKIP]${NC} ${label}: skipped by user"
                    skipped+=("$display")
                fi
            else
                echo -e "  ${RED}[ERROR]${NC} ${label}: symlink conflict (non-interactive mode)"
                errors+=("$label")
            fi
            return
        fi
    fi

    # Check if destination is a regular directory
    if [[ -d "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${label}: directory already exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip this directory and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${label}: skipped by user"
                skipped+=("$display")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove or rename ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${label}: cannot create symlink (non-interactive mode)"
            errors+=("$label")
        fi
        return
    fi

    # Check if destination is a file
    if [[ -e "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${label}: file exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${label}: skipped by user"
                skipped+=("$display")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${label}: cannot create symlink (non-interactive mode)"
            errors+=("$label")
        fi
        return
    fi

    # Create symlink
    ln -s "$src" "$dest"
    echo -e "  ${GREEN}[DONE]${NC} ${label}: symlink created"
    installed+=("$display")
}

# Install a file symlink: install_file_link <src> <dest> <display_label>
install_file_link() {
    local src="$1" dest="$2" label="$3"
    local display="$(to_display_path "$dest") => $(to_display_path "$src")"

    # Check if source file exists
    if [[ ! -f "$src" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${label}: source file does not exist"
        skipped+=("$display")
        return
    fi

    # Check if destination is already a symlink
    if [[ -L "$dest" ]]; then
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$src" ]]; then
            echo -e "  ${BLUE}[OK]${NC} ${label}: symlink already exists"
            already_linked+=("$display")
            return
        else
            echo -e "  ${YELLOW}[WARN]${NC} ${label}: symlink exists but points to ${current_target}"
            if [[ "$INTERACTIVE" == true ]]; then
                read -p "  Replace symlink? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$dest"
                    ln -s "$src" "$dest"
                    echo -e "  ${GREEN}[DONE]${NC} ${label}: symlink updated"
                    installed+=("$display")
                else
                    echo -e "  ${YELLOW}[SKIP]${NC} ${label}: skipped by user"
                    skipped+=("$display")
                fi
            else
                echo -e "  ${RED}[ERROR]${NC} ${label}: symlink conflict (non-interactive mode)"
                errors+=("$label")
            fi
            return
        fi
    fi

    # Check if destination is a regular file
    if [[ -f "$dest" ]]; then
        echo -e "  ${YELLOW}[CONFLICT]${NC} ${label}: file already exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Replace file? (existing file will be backed up) [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                backup_suffix=".backup_$(date +%Y_%m_%d).md"
                backup_file="${dest%.md}${backup_suffix}"
                mv "$dest" "$backup_file"
                backup_display="$(to_display_path "$backup_file")"
                echo -e "  ${BLUE}[BACKUP]${NC} ${label}: backed up to ${backup_display}"
                ln -s "$src" "$dest"
                echo -e "  ${GREEN}[DONE]${NC} ${label}: symlink created"
                installed+=("$display")
            else
                echo -e "  ${YELLOW}[SKIP]${NC} ${label}: skipped by user"
                skipped+=("$display")
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${label}: file conflict (non-interactive mode)"
            errors+=("$label")
        fi
        return
    fi

    # Check if destination is a directory
    if [[ -d "$dest" ]]; then
        echo -e "  ${RED}[CONFLICT]${NC} ${label}: directory exists at ${dest}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "  Skip and continue? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "  ${YELLOW}[SKIP]${NC} ${label}: skipped by user"
                skipped+=("$display")
            else
                echo ""
                echo -e "${RED}Aborted.${NC} Please remove ${dest} and try again."
                exit 1
            fi
        else
            echo -e "  ${RED}[ERROR]${NC} ${label}: cannot create symlink (non-interactive mode)"
            errors+=("$label")
        fi
        return
    fi

    # Create symlink
    ln -s "$src" "$dest"
    echo -e "  ${GREEN}[DONE]${NC} ${label}: symlink created"
    installed+=("$display")
}

echo -e "${BOLD}Installing agent-dotfiles for ${AGENT_DISPLAY}...${NC}"
echo ""

# Ensure directories exist
for dir in "$SHARED_HOME" "$AGENT_HOME"; do
    if [[ ! -d "$dir" ]]; then
        dir_display="$(to_display_path "$dir")"
        echo "Creating ${dir_display}..."
        mkdir -p "$dir"
    fi
done

# Install shared symlinks (skills) to ~/.agents/
echo -e "${BOLD}Shared resources (${SHARED_HOME_DISPLAY}):${NC}"
for entry in "${SHARED_MAPPINGS[@]}"; do
    src="${SCRIPT_DIR}/${entry}"
    dest="${SHARED_HOME}/${entry}"
    install_dir_link "$src" "$dest" "${entry}"
done
echo ""

# Install agent-specific directory symlinks
echo -e "${BOLD}${AGENT_DISPLAY}-specific (${AGENT_HOME_DISPLAY}):${NC}"
for entry in "${MAPPINGS[@]}"; do
    src_dir="${entry%%:*}"
    dest_dir="${entry#*:}"
    [[ "$dest_dir" == "$entry" ]] && dest_dir="$src_dir"

    src="${SCRIPT_DIR}/${src_dir}"
    dest="${AGENT_HOME}/${dest_dir}"
    install_dir_link "$src" "$dest" "${dest_dir}"
done

# Install agent-specific file symlinks
for entry in "${FILE_MAPPINGS[@]}"; do
    src_file="${entry%%:*}"
    dest_file="${entry#*:}"

    src="${SCRIPT_DIR}/${src_file}"
    dest="${AGENT_HOME}/${dest_file}"
    install_file_link "$src" "$dest" "${dest_file}"
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
    for item in "${installed[@]}"; do
        echo -e "  ${GREEN}${item}${NC}"
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
    for item in "${already_linked[@]}"; do
        echo -e "  ${BLUE}${item}${NC}"
    done
fi

if [[ ${#skipped[@]} -gt 0 ]]; then
    if [[ ${#installed[@]} -gt 0 || ${#already_linked[@]} -gt 0 ]]; then
        echo ""
        echo "────────────────────────────────────────"
    fi
    echo ""
    echo -e "${RED}NOT INSTALLED (skipped):${NC}"
    echo ""
    for item in "${skipped[@]}"; do
        echo -e "  ${RED}${item}${NC}"
    done
fi
