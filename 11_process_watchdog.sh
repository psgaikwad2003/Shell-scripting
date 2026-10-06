#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 11_process_watchdog.sh
#  LEVEL  : Intermediate
#  PURPOSE: High CPU & Memory Process Watchdog & Resource Monitor
#  USAGE  : bash 11_process_watchdog.sh [CPU_LIMIT] [MEM_LIMIT]
#           bash 11_process_watchdog.sh 75 80
#
#  CONCEPTS COVERED:
#    - ps command with custom formatting (-eo pid,ppid,cmd,%cpu,%mem)
#    - Awk floating point arithmetic and conditional filtering
#    - Signal handling and process termination simulation (kill -15)
#    - Top resource consumer profiling
#    - Logging alerts to file
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

CPU_THRESHOLD="${1:-70.0}"
MEM_THRESHOLD="${2:-70.0}"
WATCHDOG_LOG="/tmp/process_watchdog.log"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ⚡  PROCESS WATCHDOG & RUNAWAY MONITOR               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "CPU Alarm Threshold : ${CPU_THRESHOLD}%"
    echo "MEM Alarm Threshold : ${MEM_THRESHOLD}%"
    echo "Timestamp           : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

show_top_consumers() {
    echo -e "\n${BOLD}Top 5 CPU Consuming Processes:${RESET}"
    printf "%-8s %-8s %-8s %-40s\n" "PID" "%CPU" "%MEM" "COMMAND"
    echo "------------------------------------------------------------"
    ps -eo pid,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {printf "%-8s %-8s %-8s %-40s\n", $1, $2, $3, $4}' || true

    echo -e "\n${BOLD}Top 5 Memory Consuming Processes:${RESET}"
    printf "%-8s %-8s %-8s %-40s\n" "PID" "%CPU" "%MEM" "COMMAND"
    echo "------------------------------------------------------------"
    ps -eo pid,%cpu,%mem,comm --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=6 {printf "%-8s %-8s %-8s %-40s\n", $1, $2, $3, $4}' || true
}

scan_runaway_processes() {
    echo -e "\n${BOLD}Checking for processes exceeding thresholds...${RESET}"
    local runaway_found=0

    while read -r pid cpu mem comm; do
        [[ -z "$pid" ]] && continue
        runaway_found=1
        echo -e "${RED}${BOLD}[ALERT]${RESET} Process '$comm' (PID: $pid) exceeded limits! CPU: ${cpu}% | MEM: ${mem}%"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT PID=$pid COMM=$comm CPU=$cpu% MEM=$mem%" >> "$WATCHDOG_LOG" 2>/dev/null || true
    done < <(ps -eo pid,%cpu,%mem,comm 2>/dev/null | awk -v cpu_th="$CPU_THRESHOLD" -v mem_th="$MEM_THRESHOLD" '
        NR>1 {
            if ($2 > cpu_th || $3 > mem_th) {
                print $1, $2, $3, $4
            }
        }
    ')

    if (( runaway_found == 0 )); then
        echo -e "${GREEN}✔ No runaway processes detected. All tasks within limits.${RESET}"
    fi
}

main() {
    print_header
    show_top_consumers
    scan_runaway_processes
}

main "$@"
