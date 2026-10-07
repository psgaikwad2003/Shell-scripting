#!/usr/bin/env bash
# =============================================================================
# Script: 36_disk_io_latency_tracker.sh
# Problem Statement: Track block device I/O operations, queue saturation, and average latency to diagnose storage performance bottlenecks.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

INTERVAL="${1:-1}"
COUNT="${2:-2}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       💽  BLOCK DISK I/O LATENCY & IOPS TRACKER            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Sampling Interval: ${INTERVAL}s (Count: ${COUNT})"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

audit_diskstats() {
    if [[ -f "/proc/diskstats" ]]; then
        echo -e "${BOLD}Current Block Device Stats (/proc/diskstats):${RESET}\n"
        printf "%-12s %-15s %-15s %-15s\n" "DEVICE" "READS_COMPLETED" "WRITES_COMPLETED" "IO_IN_PROGRESS"
        echo "------------------------------------------------------------"
        awk '$3 ~ /^(sd[a-z]|nvme[0-9]n[1-9]|vd[a-z])/ {
            printf "%-12s %-15s %-15s %-15s\n", $3, $4, $8, $12
        }' /proc/diskstats
    elif command -v iostat &>/dev/null; then
        echo -e "${BOLD}Running iostat -x sample...${RESET}\n"
        iostat -x "$INTERVAL" "$COUNT"
    else
        echo -e "${YELLOW}[SIMULATION] Running fallback disk benchmark snapshot:${RESET}\n"
        printf "%-12s %-10s %-10s %-12s %-12s\n" "DEVICE" "r/s (IOPS)" "w/s (IOPS)" "r_await(ms)" "w_await(ms)"
        echo "------------------------------------------------------------"
        printf "%-12s %-10s %-10s ${GREEN}%-12s${RESET} ${GREEN}%-12s${RESET}\n" "nvme0n1" "450.2" "120.4" "0.25" "0.41"
        printf "%-12s %-10s %-10s ${GREEN}%-12s${RESET} ${YELLOW}%-12s${RESET}\n" "sda" "35.1" "88.9" "4.12" "12.80"
    fi
}

print_banner
audit_diskstats
