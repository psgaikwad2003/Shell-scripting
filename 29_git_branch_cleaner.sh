#!/usr/bin/env bash
# =============================================================================
# Script: 29_git_branch_cleaner.sh
# Problem Statement: Identify and prune merged local Git branches safely while protecting primary production branches.
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
LOG_FILE="${REPORT_LOG_FILE:-}"

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${RESET} [${ts}] ${msg}"
    [[ -n "$LOG_FILE" ]] && echo "[INFO] [${ts}] ${msg}" >> "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${RESET} [${ts}] ${msg}"
    [[ -n "$LOG_FILE" ]] && echo "[WARN] [${ts}] ${msg}" >> "$LOG_FILE"
}

log_error() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${RESET} [${ts}] ${msg}" >&2
    [[ -n "$LOG_FILE" ]] && echo "[ERROR] [${ts}] ${msg}" >> "$LOG_FILE"
}

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
    echo "Timestamp         : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target        : $LOG_FILE"
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
        log_error "Current directory is not a Git repository."
        exit 1
    fi

    log_info "Fetching latest remote state with prune..."
    git fetch --prune &>/dev/null || true

    local CURRENT_BRANCH
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    log_info "Scanning branches merged into $BASE_BRANCH (current branch: $CURRENT_BRANCH)..."

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
        log_info "No stale merged branches found. Working repository is clean."
        return 0
    fi

    log_warn "Found ${#MERGED_BRANCHES[@]} candidate branch(es) to prune:"
    for b in "${MERGED_BRANCHES[@]}"; do
        log_info "  - $b"
    done

    if [[ "$MODE" == "dry-run" ]]; then
        log_info "[DRY-RUN] No branches deleted. Re-run with --force to execute deletion."
    else
        log_warn "Proceeding with branch deletion..."
        for b in "${MERGED_BRANCHES[@]}"; do
            git branch -d "$b" && log_info "Deleted local branch: $b"
        done
        log_info "Branch pruning complete."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                MODE="force"
                shift
                ;;
            --dry-run)
                MODE="dry-run"
                shift
                ;;
            -b|--base)
                BASE_BRANCH="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [BASE_BRANCH]"
                echo "Options:"
                echo "  -b, --base BRANCH                    Base branch to check merged status against (default: main)"
                echo "      --dry-run | --force              Preview mode vs actual deletion"
                echo "  -o, --output FILE, --log-file FILE   Write branch pruning log to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                BASE_BRANCH="$1"
                shift
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        : > "$LOG_FILE"
    fi
    print_banner
    clean_branches
    log_info "Git branch audit complete."
}

main "$@"
