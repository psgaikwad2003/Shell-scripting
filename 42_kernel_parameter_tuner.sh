#!/usr/bin/env bash
# =============================================================================
# Script: 42_kernel_parameter_tuner.sh
# Problem Statement: Inspect Linux sysctl kernel parameters and recommend optimizations for network socket queues and virtual memory.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🏎️   LINUX SYSCTL KERNEL PERFORMANCE TUNER            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Hostname  : $(hostname)"
    echo "Kernel    : $(uname -r)"
    echo "Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

check_param() {
    local PARAM="$1"
    local MIN_RECOMMENDED="$2"
    local DESCRIPTION="$3"

    printf "%-32s : " "$PARAM"

    local CURRENT_VAL
    if command -v sysctl &>/dev/null; then
        CURRENT_VAL=$(sysctl -n "$PARAM" 2>/dev/null || echo "N/A")
    else
        CURRENT_VAL="N/A"
    fi

    if [[ "$CURRENT_VAL" == "N/A" ]]; then
        echo -e "${YELLOW}[UNAVAILABLE] (Container/Non-Linux)${RESET}"
        return
    fi

    if (( CURRENT_VAL >= MIN_RECOMMENDED )); then
        echo -e "${GREEN}[OPTIMIZED]${RESET} $CURRENT_VAL ($DESCRIPTION)"
    else
        echo -e "${YELLOW}[LOW]${RESET} $CURRENT_VAL (Recommended >= $MIN_RECOMMENDED for high throughput)"
    fi
}

main() {
    print_banner
    check_param "net.core.somaxconn" 1024 "Socket connection backlog"
    check_param "net.ipv4.tcp_max_syn_backlog" 2048 "SYN backlog queue"
    check_param "fs.file-max" 65536 "Maximum open file descriptors"

    echo -e "\n${BOLD}Virtual Memory Strategy:${RESET}"
    if command -v sysctl &>/dev/null; then
        local SWAP
        SWAP=$(sysctl -n vm.swappiness 2>/dev/null || echo "N/A")
        echo "  vm.swappiness : $SWAP (Production recommendation: 10 - 20)"
    fi
    echo -e "\n${GREEN}✔ Kernel parameter audit complete.${RESET}"
}

main
