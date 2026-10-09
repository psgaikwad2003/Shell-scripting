#!/usr/bin/env bash
# =============================================================================
# Script: 06_disk_space_alert.sh
# Problem Statement: Monitor filesystem disk usage against predefined capacity thresholds and trigger high-priority alerts when limits are breached.
# =============================================================================

set -euo pipefail

THRESHOLD=80
SPECIFIC_MOUNT=""
LOG_FILE="${REPORT_LOG_FILE:-}"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

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
    echo "       💾   FILESYSTEM DISK USAGE MONITOR & ALERTER          "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Configured Warning Threshold: ${THRESHOLD}%"
    [[ -n "$SPECIFIC_MOUNT" ]] && echo "Target Mount                : $SPECIFIC_MOUNT"
    echo "Scan Time                   : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target                  : $LOG_FILE"
    echo "------------------------------------------------------------"
    printf "%-25s %-10s %-10s %-10s %-10s %-10s\n" "Filesystem" "Size" "Used" "Avail" "Use%" "Status"
    echo "------------------------------------------------------------"
}

check_disk_usage() {
    local alert_count=0
    local raw_data
    raw_data=$(df -h -P 2>/dev/null | awk 'NR>1 {print $1, $2, $3, $4, $5, $6}' || true)

    while read -r fs size used avail use_pct mount; do
        [[ -z "$fs" ]] && continue

        if [[ -n "$SPECIFIC_MOUNT" && "$mount" != "$SPECIFIC_MOUNT" ]]; then
            continue
        fi

        local usage_num="${use_pct%\%}"
        if ! [[ "$usage_num" =~ ^[0-9]+$ ]]; then
            continue
        fi

        local status_label
        if (( usage_num >= THRESHOLD + 10 )); then
            status_label="${RED}${BOLD}[CRITICAL]${RESET}"
            ((alert_count++))
            log_error "Filesystem '$fs' mounted on '$mount' at ${usage_num}% capacity (CRITICAL)"
        elif (( usage_num >= THRESHOLD )); then
            status_label="${YELLOW}${BOLD}[WARNING]${RESET}"
            ((alert_count++))
            log_warn "Filesystem '$fs' mounted on '$mount' at ${usage_num}% capacity (WARNING)"
        else
            status_label="${GREEN}[OK]${RESET}"
        fi

        printf "%-25s %-10s %-10s %-10s %-10s %b\n" "$fs" "$size" "$used" "$avail" "$use_pct" "$status_label"
    done <<< "$raw_data"

    echo "------------------------------------------------------------"
    if (( alert_count > 0 )); then
        log_warn "Alert: ${alert_count} partition(s) exceeded the ${THRESHOLD}% threshold!"
    else
        log_info "All monitored filesystems are healthy and within capacity limits."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--threshold)
                THRESHOLD="$2"
                shift 2
                ;;
            -m|--mount)
                SPECIFIC_MOUNT="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [THRESHOLD] [MOUNT]"
                echo "Options:"
                echo "  -t, --threshold PERCENT              Disk usage alert trigger percentage (default: 80)"
                echo "  -m, --mount PATH                     Specific mount point to inspect (e.g. / or /home)"
                echo "  -o, --output FILE, --log-file FILE   Write alerts and summary metrics to specified log"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    if [[ -z "${THRESHOLD_SET:-}" ]]; then
                        THRESHOLD="$1"
                        THRESHOLD_SET=1
                    elif [[ -z "${MOUNT_SET:-}" ]]; then
                        SPECIFIC_MOUNT="$1"
                        MOUNT_SET=1
                    fi
                    shift
                else
                    log_error "Unknown option: $1"
                    exit 1
                fi
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
    check_disk_usage
}

main "$@"
