#!/usr/bin/env bash
# =============================================================================
# Script: 06_disk_space_alert.sh
# Problem Statement: Monitor filesystem disk usage against predefined capacity thresholds and trigger high-priority alerts when limits are breached.
# =============================================================================

set -euo pipefail

EXCLUDED_FSTYPES="tmpfs|devtmpfs|squashfs|overlay"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

THRESHOLD="${1:-80}"
SPECIFIC_MOUNT="${2:-}"
LOG_FILE="/tmp/disk_alerts.log"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       💾  FILESYSTEM DISK USAGE MONITOR & ALERTER          "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Configured Warning Threshold: ${THRESHOLD}%"
    echo "Scan Time                   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
    printf "%-25s %-10s %-10s %-10s %-10s %-10s\n" "Filesystem" "Size" "Used" "Avail" "Use%" "Status"
    echo "------------------------------------------------------------"
}

check_disk_usage() {
    local alert_count=0

    while read -r fs size used avail use_pct mount; do
        local usage_num="${use_pct%\%}"

        if [[ -n "$SPECIFIC_MOUNT" && "$mount" != "$SPECIFIC_MOUNT" ]]; then
            continue
        fi

        if ! [[ "$usage_num" =~ ^[0-9]+$ ]]; then
            continue
        fi

        local status_label
        if (( usage_num >= THRESHOLD + 10 )); then
            status_label="${RED}${BOLD}[CRITICAL]${RESET}"
            ((alert_count++))
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRITICAL] Filesystem '$fs' mounted on '$mount' at ${usage_num}%" >> "$LOG_FILE" 2>/dev/null || true
        elif (( usage_num >= THRESHOLD )); then
            status_label="${YELLOW}${BOLD}[WARNING]${RESET}"
            ((alert_count++))
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] Filesystem '$fs' mounted on '$mount' at ${usage_num}%" >> "$LOG_FILE" 2>/dev/null || true
        else
            status_label="${GREEN}[OK]${RESET}"
        fi

        printf "%-25s %-10s %-10s %-10s %-10s %b\n" "$fs" "$size" "$used" "$avail" "$use_pct" "$status_label"
    done < <(df -h -P | awk 'NR>1 {print $1, $2, $3, $4, $5, $6}')

    echo "------------------------------------------------------------"
    if (( alert_count > 0 )); then
        echo -e "${YELLOW}⚠️  Alert: ${alert_count} partition(s) exceeded the ${THRESHOLD}% threshold!${RESET}"
    else
        echo -e "${GREEN}✔ All monitored filesystems are healthy and within limits.${RESET}"
    fi
}

main() {
    print_header
    check_disk_usage
}

main "$@"
