#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 17_git_repo_syncer.sh
#  LEVEL  : Intermediate
#  PURPOSE: Multi-Repository Git Status & Auto-Sync Auditor
#  USAGE  : bash 17_git_repo_syncer.sh [PARENT_DIRECTORY] [--fetch|--status-only]
#           bash 17_git_repo_syncer.sh ~/projects --fetch
#
#  CONCEPTS COVERED:
#    - Discovering .git repositories with find -type d -name ".git"
#    - Subshell execution within repository directories (cd & git)
#    - Git plumbing commands: git status --porcelain, git branch --show-current
#    - Handling dirty working trees and ahead/behind branch states
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

PARENT_DIR="${1:-.}"
MODE="${2:---status-only}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🐙  MULTI-REPOSITORY GIT SYNC & STATUS AUDITOR       "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Search Root : $PARENT_DIR"
    echo "Mode        : $MODE"
    echo "Timestamp   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

scan_repositories() {
    local repo_count=0

    while IFS= read -r git_dir; do
        local repo_path
        repo_path="$(dirname "$git_dir")"
        ((repo_count++))

        (
            cd "$repo_path"
            local repo_name
            repo_name="$(basename "$repo_path")"
            local current_branch
            current_branch="$(git branch --show-current 2>/dev/null || echo "DETACHED")"

            echo -e "\n📁 Repository: ${BOLD}${repo_name}${RESET} [Branch: ${CYAN}${current_branch}${RESET}]"

            # Check dirty working tree
            local dirty
            dirty="$(git status --porcelain 2>/dev/null || true)"
            if [[ -n "$dirty" ]]; then
                echo -e "  ↳ Tree Status : ${YELLOW}Dirty (uncommitted changes present)${RESET}"
            else
                echo -e "  ↳ Tree Status : ${GREEN}Clean${RESET}"
            fi

            # Optionally fetch remote
            if [[ "$MODE" == "--fetch" ]]; then
                echo -e "  ↳ Fetching updates from origin..."
                git fetch origin --quiet 2>/dev/null || echo -e "    ${YELLOW}(Remote fetch skipped or failed)${RESET}"
            fi

            # Check ahead/behind count
            local upstream
            upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
            if [[ -n "$upstream" ]]; then
                local ahead behind
                ahead="$(git rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)"
                behind="$(git rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)"
                echo -e "  ↳ Sync State  : Ahead by $ahead, Behind by $behind"
            fi
        )
    done < <(find "$PARENT_DIR" -maxdepth 3 -type d -name ".git" 2>/dev/null || true)

    echo -e "\n------------------------------------------------------------"
    echo -e "Total repositories audited: ${BOLD}${repo_count}${RESET}"
}

main() {
    print_header
    scan_repositories
}

main "$@"
