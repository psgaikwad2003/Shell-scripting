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

LOG_FILE="${REPORT_LOG_FILE:-}"

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

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ⚙️   SYSTEMD UNIT HEALTH & BOOT AUDITOR               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Hostname  : $(hostname 2>/dev/null || echo 'localhost')"
    echo "Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target: $LOG_FILE"
    echo "------------------------------------------------------------"
}

audit_systemd() {
    if ! command -v systemctl &>/dev/null; then
        log_warn "Non-systemd or container environment detected. Displaying baseline checks."
        local proc_count
        proc_count=$(ps -e 2>/dev/null | wc -l || echo 0)
        log_info "Active processes count: $proc_count"
        log_info "Generic process subsystem operational."
        return 0
    fi

    log_info "Checking for degraded or failed systemd units..."
    local FAILED_UNITS
    FAILED_UNITS=$(systemctl --failed --no-legend 2>/dev/null || true)

    if [[ -z "$FAILED_UNITS" ]]; then
        log_info "Zero failed systemd units detected. System state: HEALTHY"
    else
        log_error "Failed systemd units detected:"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            log_error "  ↳ $line"
        done <<< "$FAILED_UNITS"
    fi

    log_info "Evaluating boot startup times..."
    if command -v systemd-analyze &>/dev/null; then
        systemd-analyze blame 2>/dev/null | head -n 5 | while read -r line; do
            [[ -z "$line" ]] && continue
            log_info "  Blame: $line"
        done
    else
        log_info "systemd-analyze command not available."
    fi

    log_info "Scanning critical system journal alerts (priority <= 3)..."
    if command -v journalctl &>/dev/null; then
        local ERRORS
        ERRORS=$(journalctl -p 3 -xb --since "1 hour ago" --no-pager -n 5 2>/dev/null || true)
        if [[ -z "$ERRORS" ]]; then
            log_info "No emergency, alert, or critical journal entries in the last hour."
        else
            while IFS= read -r err; do
                [[ -z "$err" ]] && continue
                log_warn "  Journal: $err"
            done <<< "$ERRORS"
        fi
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -o, --output FILE, --log-file FILE   Write systemd audit report to file"
                echo "  -h, --help                           Show this help message and exit"
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
    print_banner
    audit_systemd
    log_info "Systemd audit inspection complete."
}

main "$@"
