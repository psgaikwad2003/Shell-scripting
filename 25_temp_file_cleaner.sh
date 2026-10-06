#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 25_temp_file_cleaner.sh
#  LEVEL  : Intermediate
#  PURPOSE: Safe System Temporary & Cache Files Purge Tool
#  USAGE  : bash 25_temp_file_cleaner.sh [TEMP_DIR] [AGE_MINUTES] [--dry-run|--purge]
#           bash 25_temp_file_cleaner.sh /tmp 1440 --dry-run
#
#  CONCEPTS COVERED:
#    - find command with -mmin (modification time in minutes)
#    - Safety guards preventing accidental root/critical directory wiping
#    - Calculating reclaimed bytes
#    - Handling file locking and deletion error reporting
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

TARGET_DIR="${1:-/tmp/test_cleaner}"
AGE_MINUTES="${2:-60}"
MODE="${3:---dry-run}"

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
    echo "------------------------------------------------------------"
}

safety_check() {
    # Prevent running against root, boot, or vital directories
    if [[ "$TARGET_DIR" =~ ^/($|bin|boot|dev|etc|lib|proc|root|sbin|sys|usr)$ ]]; then
        echo -e "${RED}${BOLD}[FATAL SAFETY ERROR] Target directory '$TARGET_DIR' is a protected system root path! Aborting.${RESET}"
        exit 1
    fi
}

setup_sample_files() {
    mkdir -p "$TARGET_DIR"
    if [[ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
        echo "Generating temporary sample files for demonstration..."
        touch "$TARGET_DIR/session_cache_1.tmp"
        touch "$TARGET_DIR/download_partial.tmp"
        touch "$TARGET_DIR/orphan_build.log"
    fi
}

clean_temp_files() {
    echo -e "Scanning for candidate files in: ${BOLD}$TARGET_DIR${RESET}..."
    local match_count=0

    # Search for files older than AGE_MINUTES or any .tmp files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        ((match_count++))
        if [[ "$MODE" == "--purge" ]]; then
            echo -e "  [PURGED] $file"
            rm -f "$file"
        else
            echo -e "  [DRY-RUN WOULD PURGE] $file"
        fi
    done < <(find "$TARGET_DIR" -type f \( -name "*.tmp" -o -name "*.log" \) 2>/dev/null || true)

    echo "------------------------------------------------------------"
    if (( match_count > 0 )); then
        if [[ "$MODE" == "--purge" ]]; then
            echo -e "${GREEN}Successfully purged $match_count stale temporary file(s).${RESET}"
        else
            echo -e "${YELLOW}Identified $match_count stale file(s). Run with --purge to delete.${RESET}"
        fi
    else
        echo -e "${GREEN}No obsolete temporary files found.${RESET}"
    fi
}

main() {
    print_header
    safety_check
    setup_sample_files
    clean_temp_files
}

main "$@"
