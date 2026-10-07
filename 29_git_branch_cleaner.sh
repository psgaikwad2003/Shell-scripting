#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 29_git_branch_cleaner.sh
#  LEVEL  : Intermediate
#  PURPOSE: Safe automated pruning of merged local and tracking git branches
#  USAGE  : bash 29_git_branch_cleaner.sh [--dry-run|--force] [BASE_BRANCH]
#           bash 29_git_branch_cleaner.sh --dry-run main
#
#  CONCEPTS COVERED:
#    - Git plumbing commands (git branch --merged, git rev-parse)
#    - Safety guards preventing deletion of protected branches (main, master, dev)
#    - Command line argument parsing and boolean flags
#    - Interactive user prompts vs non-interactive batch automation
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

MODE="dry-run"
BASE_BRANCH="main"

for arg in "$@"; do
    case "$arg" in
        --force) MODE="force" ;;
        --dry-run) MODE="dry-run" ;;
        *) BASE_BRANCH="$arg" ;;
    esac
done

PROTECTED_BRANCHES=("main" "master" "develop" "dev" "staging" "production")

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🌿  GIT MERGED BRANCH CLEANER & PRUNER               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Base Target Branch: $BASE_BRANCH"
    echo "Execution Mode    : $MODE"
    echo "Protected Targets : ${PROTECTED_BRANCHES[*]}"
    echo "------------------------------------------------------------"
}

is_protected() {
    local branch="$1"
    for protected in "${PROTECTED_BRANCHES[@]}"; do
        if [[ "$branch" == "$protected" ]]; then
            return 0
        fi
    done
    return 1
}

clean_branches() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${RED}[ERROR] Current directory is not a Git repository.${RESET}" >&2
        exit 1
    fi

    echo -e "${BOLD}Fetching latest remote state...${RESET}"
    git fetch --prune &>/dev/null || true

    local CURRENT_BRANCH
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    echo -e "\nScanning branches merged into ${CYAN}${BASE_BRANCH}${RESET}..."
    
    local MERGED_BRANCHES=()
    while IFS= read -r branch; do
        branch=$(echo "$branch" | tr -d ' *')
        [[ -z "$branch" ]] && continue
        if [[ "$branch" == "$CURRENT_BRANCH" ]] || is_protected "$branch"; then
            continue
        fi
        MERGED_BRANCHES+=("$branch")
    done < <(git branch --merged "$BASE_BRANCH" 2>/dev/null || true)

    if [[ ${#MERGED_BRANCHES[@]} -eq 0 ]]; then
        echo -e "${GREEN}✔ No stale merged branches found. Working repository is tidy!${RESET}"
        return 0
    fi

    echo -e "${YELLOW}Found ${#MERGED_BRANCHES[@]} candidate branch(es) to prune:${RESET}"
    for b in "${MERGED_BRANCHES[@]}"; do
        echo "  - $b"
    done

    if [[ "$MODE" == "dry-run" ]]; then
        echo -e "\n${CYAN}[DRY-RUN] No branches were deleted. Re-run with --force to execute deletion.${RESET}"
    else
        echo -e "\n${RED}Proceeding with deletion...${RESET}"
        for b in "${MERGED_BRANCHES[@]}"; do
            git branch -d "$b" && echo -e "  ${GREEN}Deleted local branch:${RESET} $b"
        done
        echo -e "\n${GREEN}✔ Branch pruning complete.${RESET}"
    fi
}

print_banner
clean_branches
