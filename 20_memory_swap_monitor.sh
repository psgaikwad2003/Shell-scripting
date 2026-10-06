#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 20_memory_swap_monitor.sh
#  LEVEL  : Intermediate
#  PURPOSE: RAM & Swap Memory Diagnostic Tool with Consumption Profiling
#  USAGE  : bash 20_memory_swap_monitor.sh [WARN_MEM_PCT] [WARN_SWAP_PCT]
#
#  CONCEPTS COVERED:
#    - Parsing /proc/meminfo or free command
#    - Calculating percentage utilization in awk
#    - Top memory-consuming processes breakdown
#    - Swap usage threshold detection
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

WARN_MEM_PCT="${1:-80}"
WARN_SWAP_PCT="${2:-50}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🧠  RAM & SWAP MEMORY DIAGNOSTIC MONITOR             "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Memory Warning Threshold : ${WARN_MEM_PCT}%"
    echo "Swap Warning Threshold   : ${WARN_SWAP_PCT}%"
    echo "Timestamp                : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

analyze_memory() {
    if command -v free &>/dev/null; then
        echo -e "${BOLD}Current Memory Statistics (MB):${RESET}"
        free -m
        echo "------------------------------------------------------------"

        local mem_used mem_total mem_pct
        mem_total=$(free -m | awk '/^Mem:/ {print $2}')
        mem_used=$(free -m | awk '/^Mem:/ {print $3}')
        mem_pct=$(( mem_used * 100 / (mem_total > 0 ? mem_total : 1) ))

        local swap_total swap_used swap_pct
        swap_total=$(free -m | awk '/^Swap:/ {print $2}')
        swap_used=$(free -m | awk '/^Swap:/ {print $3}')
        if (( swap_total > 0 )); then
            swap_pct=$(( swap_used * 100 / swap_total ))
        else
            swap_pct=0
        fi

        echo -e "RAM Utilization  : ${BOLD}${mem_pct}%${RESET} (${mem_used}MB / ${mem_total}MB)"
        echo -e "Swap Utilization : ${BOLD}${swap_pct}%${RESET} (${swap_used}MB / ${swap_total}MB)"

        if (( mem_pct >= WARN_MEM_PCT )); then
            echo -e "${RED}${BOLD}[CRITICAL] RAM usage is above ${WARN_MEM_PCT}%!${RESET}"
        else
            echo -e "${GREEN}[OK] RAM usage is within safe operating parameters.${RESET}"
        fi

        if (( swap_pct >= WARN_SWAP_PCT )); then
            echo -e "${YELLOW}${BOLD}[WARNING] High swap usage detected (${swap_pct}%). System may be thrashing.${RESET}"
        fi
    else
        echo -e "${YELLOW}'free' command not available. Simulated memory report.${RESET}"
        echo "RAM: 4096MB Total | 1850MB Used (45%) | Status: OK"
    fi
}

show_top_consumers() {
    echo -e "\n${BOLD}Top 5 Memory-Consuming Processes:${RESET}"
    printf "%-8s %-10s %-8s %-35s\n" "PID" "RSS (KB)" "%MEM" "COMMAND"
    echo "------------------------------------------------------------"
    ps -eo pid,rss,%mem,comm --sort=-rss 2>/dev/null | awk 'NR>1 && NR<=6 {printf "%-8s %-10s %-8s %-35s\n", $1, $2, $3, $4}' || true
}

main() {
    print_header
    analyze_memory
    show_top_consumers
    echo "------------------------------------------------------------"
    echo -e "${GREEN}✔ Memory audit complete.${RESET}"
}

main "$@"
