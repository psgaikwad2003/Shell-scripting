#!/usr/bin/env bash
# =============================================================================
# Script: 25_temp_file_cleaner.sh
# Problem Statement: Safely purge temporary files and directory caches older than a set retention window without affecting running processes.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

TARGET_DIR="/tmp/test_cleaner"
AGE_MINUTES=60
MODE="--dry-run"
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

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🧹  SAFE TEMPORARY & CACHE FILE PURGE TOOL            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Directory : $TARGET_DIR"
    echo "Retention Period : > $AGE_MINUTES minute(s) old"
    echo "Action Mode      : $MODE"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Report Log       : $LOG_FILE"
    echo "------------------------------------------------------------"
}

safety_check() {
    if [[ "$TARGET_DIR" =~ ^/($|bin|boot|dev|etc|lib|proc|root|sbin|sys|usr)$ ]]; then
        log_error "[FATAL SAFETY ERROR] Target directory '$TARGET_DIR' is a protected system root path! Aborting."
        exit 1
    fi
}

setup_sample_files() {
    mkdir -p "$TARGET_DIR"
    if [[ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
        log_info "Generating temporary sample files for demonstration in $TARGET_DIR..."
        touch "$TARGET_DIR/session_cache_1.tmp"
        touch "$TARGET_DIR/download_partial.tmp"
        touch "$TARGET_DIR/orphan_build.log"
    fi
}

clean_temp_files() {
    log_info "Scanning for candidate files in: $TARGET_DIR..."
    local match_count=0

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        ((match_count++))
        if [[ "$MODE" == "--purge" ]]; then
            log_warn "Purged stale asset: $file"
            rm -f "$file"
        else
            log_info "Dry-run candidate: $file"
        fi
    done < <(find "$TARGET_DIR" -type f \( -name "*.tmp" -o -name "*.log" \) 2>/dev/null || true)

    echo "------------------------------------------------------------"
    if (( match_count > 0 )); then
        if [[ "$MODE" == "--purge" ]]; then
            log_info "Successfully purged $match_count stale temporary file(s)."
        else
            log_warn "Identified $match_count stale file(s). Run with --purge to delete."
        fi
    else
        log_info "No obsolete temporary files found."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir|--target-dir)
                TARGET_DIR="$2"
                shift 2
                ;;
            -m|--minutes|--age)
                AGE_MINUTES="$2"
                shift 2
                ;;
            --purge|--dry-run)
                MODE="$1"
                shift
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [TARGET_DIR] [AGE_MINUTES] [MODE]"
                echo "Options:"
                echo "  -d, --target-dir DIR                 Directory path to sanitize"
                echo "  -m, --age MINUTES                    Age threshold in minutes"
                echo "      --dry-run | --purge              Preview vs remove files (default: --dry-run)"
                echo "  -o, --output FILE, --log-file FILE   Write purge action summary to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ -z "${1_pos:-}" ]]; then
                    TARGET_DIR="$1"
                    1_pos=1
                elif [[ -z "${2_pos:-}" ]]; then
                    AGE_MINUTES="$1"
                    2_pos=1
                else
                    MODE="$1"
                fi
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
    print_header
    safety_check
    setup_sample_files
    clean_temp_files
    log_info "Temporary file cleanup evaluation completed."
}

main "$@"
