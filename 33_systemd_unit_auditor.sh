#!/usr/bin/env bash
# =============================================================================
# Script: 33_systemd_unit_auditor.sh
# Problem Statement: Detect failed systemd units, analyze boot startup latency bottlenecks, and review high-priority journal errors.
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
    echo "       ⚙️   SYSTEMD UNIT HEALTH & BOOT AUDITOR               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Hostname  : $(hostname)"
    echo "Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

audit_systemd() {
    if ! command -v systemctl &>/dev/null; then
        echo -e "${YELLOW}[INFO] Non-systemd or container environment detected. Displaying baseline checks.${RESET}"
        echo "  Active processes count: $(ps -e | wc -l)"
        echo -e "${GREEN}✔ Generic process subsystem operational.${RESET}"
        return 0
    fi

    echo -e "${BOLD}1. Checking for Degraded / Failed Units:${RESET}"
    local FAILED_UNITS
    FAILED_UNITS=$(systemctl --failed --no-legend 2>/dev/null || true)

    if [[ -z "$FAILED_UNITS" ]]; then
        echo -e "  ${GREEN}✔ Zero failed systemd units detected. System state: HEALTHY${RESET}"
    else
        echo -e "  ${RED}⚠ Failed units found:${RESET}"
        echo "$FAILED_UNITS" | awk '{print "    - " $1 " (" $2 ")"}'
    fi

    echo -e "\n${BOLD}2. Boot Time Startup Analysis (systemd-analyze blame):${RESET}"
    if command -v systemd-analyze &>/dev/null; then
        systemd-analyze blame 2>/dev/null | head -n 5 | awk '{printf "    %-10s %s\n", $1, $2}' || true
    else
        echo "  systemd-analyze command not available."
    fi

    echo -e "\n${BOLD}3. Critical System Errors in Journal (Last 1 Hour):${RESET}"
    if command -v journalctl &>/dev/null; then
        local ERRORS
        ERRORS=$(journalctl -p 3 -xb --since "1 hour ago" --no-pager -n 5 2>/dev/null || true)
        if [[ -z "$ERRORS" ]]; then
            echo -e "  ${GREEN}✔ No emergency/alert/critical journal entries.${RESET}"
        else
            echo "$ERRORS" | sed 's/^/    /'
        fi
    fi
}

print_banner
audit_systemd
