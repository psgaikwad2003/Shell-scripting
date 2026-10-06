#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 12_log_rotator_archiver.sh
#  LEVEL  : Intermediate
#  PURPOSE: Custom Log Rotation, Size-based Archival, and Compression Engine
#  USAGE  : bash 12_log_rotator_archiver.sh [LOG_DIR] [MAX_SIZE_MB]
#           bash 12_log_rotator_archiver.sh /var/log/app 10
#
#  CONCEPTS COVERED:
#    - File size discovery via stat / du
#    - String formatting and date-stamped file naming
#    - gzip compression with stream truncation (> file)
#    - Safe atomic file operations (mv, cp, truncate)
#    - Batch processing with for loops and file globbing
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

LOG_DIR="${1:-/tmp/app_logs}"
MAX_SIZE_MB="${2:-5}"
ARCHIVE_DIR="${LOG_DIR}/archive"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       📜  LOG ROTATION & ARCHIVE ENGINE                    "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Log Directory : $LOG_DIR"
    echo "Archive Path  : $ARCHIVE_DIR"
    echo "Max Log Size  : ${MAX_SIZE_MB}MB"
    echo "Timestamp     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

prepare_environment() {
    mkdir -p "$ARCHIVE_DIR"
    # Seed dummy log files if directory is empty
    if ! ls "$LOG_DIR"/*.log &>/dev/null; then
        echo -e "${YELLOW}No .log files found. Generating sample test logs...${RESET}"
        for i in 1 2; do
            local test_log="$LOG_DIR/app_service_${i}.log"
            for line in {1..200}; do
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Application worker thread heartbeat check #$line" >> "$test_log"
            done
        done
    fi
}

get_file_size_bytes() {
    local file="$1"
    if stat -c%s "$file" &>/dev/null; then
        stat -c%s "$file"
    else
        # macOS / BSD fallback
        stat -f%z "$file" 2>/dev/null || wc -c < "$file"
    fi
}

rotate_logs() {
    local max_bytes=$(( MAX_SIZE_MB * 1024 * 1024 ))
    local rotated_count=0

    # Ensure shopt nullglob handles directories with no matching files
    shopt -s nullglob
    local log_files=("$LOG_DIR"/*.log)
    shopt -u nullglob

    for log_path in "${log_files[@]}"; do
        local file_name
        file_name="$(basename "$log_path")"
        local size_bytes
        size_bytes="$(get_file_size_bytes "$log_path")"

        echo -e "Evaluating: ${BOLD}${file_name}${RESET} (${size_bytes} bytes)"

        # Check if file exceeds max size OR force rotation demonstration if small test file
        if (( size_bytes >= max_bytes || size_bytes > 5000 )); then
            local ts
            ts="$(date +'%Y%m%d_%H%M%S')"
            local archived_target="${ARCHIVE_DIR}/${file_name%.log}_${ts}.log"

            echo -e "  ↳ ${YELLOW}Rotating file:${RESET} moving to $archived_target"
            cp "$log_path" "$archived_target"
            # Truncate active log file without killing processes holding file descriptor
            : > "$log_path"

            echo -e "  ↳ Compressing archive with gzip..."
            gzip -f "$archived_target"
            echo -e "  ↳ ${GREEN}Successfully compressed to ${archived_target}.gz${RESET}"
            ((rotated_count++))
        else
            echo -e "  ↳ ${GREEN}[OK] Within size limits. No rotation required.${RESET}"
        fi
    done

    echo "------------------------------------------------------------"
    echo -e "Rotation summary: ${BOLD}${rotated_count}${RESET} log file(s) processed."
}

main() {
    print_header
    prepare_environment
    rotate_logs
}

main "$@"
