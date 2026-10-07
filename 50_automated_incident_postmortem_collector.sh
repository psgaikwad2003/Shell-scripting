#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 50_automated_incident_postmortem_collector.sh
#  LEVEL  : Advanced / SRE
#  PURPOSE: Automated SRE incident triage diagnostics collector & artifact bundle
#  USAGE  : bash 50_automated_incident_postmortem_collector.sh [OUTPUT_DIR]
#           bash 50_automated_incident_postmortem_collector.sh /tmp/triage
#
#  CONCEPTS COVERED:
#    - Comprehensive incident telemetry bundling (dmesg, top, ps, df, netstat)
#    - Ephemeral diagnostic directory creation
#    - Archive compression & timestamping for SRE RCA (Root Cause Analysis)
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

OUTPUT_BASE="${1:-/tmp/sre_incidents}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🚨  SRE INCIDENT POST-MORTEM DIAGNOSTICS BUNDLER     "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Collector Target : $OUTPUT_BASE"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

collect_diagnostics() {
    local STAMP
    STAMP=$(date '+%Y%m%d_%H%M%S')
    local BUNDLE_DIR="${OUTPUT_BASE}/incident_${STAMP}"
    mkdir -p "$BUNDLE_DIR"

    echo -e "${BOLD}1. Collecting System Vital Statistics...${RESET}"
    uname -a > "$BUNDLE_DIR/kernel_version.txt" 2>&1 || true
    uptime > "$BUNDLE_DIR/uptime_load.txt" 2>&1 || true
    df -h > "$BUNDLE_DIR/disk_usage.txt" 2>&1 || true
    ps aux --sort=-%cpu 2>/dev/null | head -n 25 > "$BUNDLE_DIR/top_cpu_processes.txt" || ps aux | head -n 25 > "$BUNDLE_DIR/top_cpu_processes.txt"

    echo -e "${BOLD}2. Collecting Network & Socket Telemetry...${RESET}"
    if command -v netstat &>/dev/null; then
        netstat -tulnp > "$BUNDLE_DIR/listening_sockets.txt" 2>&1 || true
    fi

    echo -e "${BOLD}3. Packaging Incident Archive...${RESET}"
    local TAR_FILE="${OUTPUT_BASE}/incident_bundle_${STAMP}.tar.gz"
    tar -czf "$TAR_FILE" -C "$OUTPUT_BASE" "incident_${STAMP}"

    echo -e "\n${GREEN}✔ Post-mortem diagnostic bundle successfully packaged:${RESET}"
    echo -e "  Archive: ${CYAN}${TAR_FILE}${RESET}"
}

print_banner
collect_diagnostics
