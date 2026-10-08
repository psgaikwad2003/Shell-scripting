#!/usr/bin/env bash
# =============================================================================
# Script: 24_cron_job_auditor.sh
# Problem Statement: Audit scheduled cron jobs across system and user crontabs for unquoted paths, insecure permissions, and suspicious commands.
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

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ⏰  CRON JOB & SCHEDULED TASK SECURITY AUDITOR        "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Audit Time: $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target: $LOG_FILE"
    echo "------------------------------------------------------------"
}

audit_user_crontab() {
    log_info "Auditing current user crontab..."
    if crontab -l 2>/dev/null | grep -v '^#' | grep -q '[^[:space:]]'; then
        crontab -l 2>/dev/null | grep -v '^#' | while read -r line; do
            [[ -z "$line" ]] && continue
            log_info "  ↳ Entry: $line"
        done
    else
        log_warn "No active user crontab entries found."
    fi
}

audit_system_crons() {
    log_info "Auditing system-wide cron directories (/etc/cron*)..."
    local cron_dirs=("/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/cron.d")

    for dir in "${cron_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local file_count
            file_count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l || echo 0)
            log_info "Directory: ${dir} (${file_count} script(s))"

            find "$dir" -maxdepth 1 -type f -perm -002 2>/dev/null | while read -r insecure_file; do
                log_error "[SECURITY RISK] World-writable cron file: $insecure_file"
            done
        fi
    done
}

audit_system_crontab() {
    log_info "Auditing main /etc/crontab configuration..."
    if [[ -f "/etc/crontab" ]]; then
        grep -v '^#' /etc/crontab | grep '[^[:space:]]' || log_info "No active entries in /etc/crontab."
    else
        log_warn "/etc/crontab not present (standard on non-Linux or containerized systems)."
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
                echo "  -o, --output FILE, --log-file FILE   Write structured cron audit findings to file"
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
    print_header
    audit_user_crontab
    audit_system_crons
    audit_system_crontab
    echo "------------------------------------------------------------"
    log_info "Cron audit completed successfully."
}

main "$@"
