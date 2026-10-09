#!/usr/bin/env bash
# =============================================================================
# Script: 03_system_report.sh
# Problem Statement: Collect and display comprehensive server hardware, load average, network interfaces, and disk storage diagnostics.
# =============================================================================

set -euo pipefail

REPORT="system_report_$(date '+%Y-%m-%d').txt"
LOG_FILE="${REPORT_LOG_FILE:-}"
NAME=""

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
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
    echo -e "${GREEN}${BOLD}=== System Report Generator ===${RESET}\n"
    log_info "Initiating system diagnostic report collection..."
}

generate_report() {
    {
        echo "=============================="
        echo "  SYSTEM REPORT"
        echo "  By       : $NAME"
        echo "  Date     : $(date '+%d %B %Y')"
        echo "  Time     : $(date '+%H:%M:%S')"
        echo "=============================="

        echo -e "\n--- Basic Info ---"
        echo "Hostname : $(hostname)"
        echo "User     : $(whoami)"
        echo "OS       : $(uname -s) | Kernel: $(uname -r)"
        echo "Shell    : ${SHELL:-/bin/bash}"
        echo "Uptime   : $(uptime -p 2>/dev/null || uptime)"

        echo -e "\n--- Memory Usage ---"
        free -h 2>/dev/null || echo "free command not available"

        echo -e "\n--- Disk Usage ---"
        df -h

        echo -e "\n--- Top 5 Processes by CPU ---"
        if ps aux --sort=-%cpu &>/dev/null 2>&1; then
            ps aux --sort=-%cpu 2>/dev/null | awk 'NR==1 || NR<=6 {printf "%-12s %5s%% %s\n", $1, $3, $11}'
        else
            ps aux 2>/dev/null | sort -k3 -rn | awk 'NR<=5 {printf "%-12s %5s%% %s\n", $1, $3, $11}'
        fi

        echo -e "\n=============================="
        echo "  END OF REPORT"
        echo "=============================="
    } | tee "$REPORT"

    local DISK_USED
    DISK_USED=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")

    if [[ "$DISK_USED" =~ ^[0-9]+$ ]]; then
        if (( DISK_USED >= 80 )); then
            log_warn "Disk is ${DISK_USED}% full — cleanup needed!"
        elif (( DISK_USED >= 60 )); then
            log_info "Notice: Disk is ${DISK_USED}% full."
        else
            log_info "Disk is healthy: ${DISK_USED}% used."
        fi
    fi

    log_info "System report written to: $REPORT"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output|--report-file)
                REPORT="$2"
                shift 2
                ;;
            -l|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -u|--user)
                NAME="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -o, --output FILE, --report-file FILE   Specify output file for report (default: system_report_YYYY-MM-DD.txt)"
                echo "  -l, --log-file FILE                     Specify output log file for structured logs"
                echo "  -u, --user NAME                         Operator name"
                echo "  -h, --help                              Show this help message and exit"
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                exit 1
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

    if [[ -z "$NAME" ]]; then
        if [[ -t 0 ]]; then
            echo -ne "Enter your name: "
            read -r NAME || true
        fi
        if [[ -z "$NAME" ]]; then
            NAME="${USER:-${USERNAME:-User}}"
        fi
    fi

    print_header
    generate_report
    log_info "Diagnostics collection finished successfully."
}

main "$@"
