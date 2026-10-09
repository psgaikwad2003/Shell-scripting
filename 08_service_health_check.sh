#!/usr/bin/env bash
# =============================================================================
# Script: 08_service_health_check.sh
# Problem Statement: Monitor critical system services, verify daemon availability, and execute automated restarts upon service failure.
# =============================================================================

set -euo pipefail

SERVICES=("nginx" "sshd" "docker" "cron")
LOG_FILE="${REPORT_LOG_FILE:-}"
AUTO_RESTART=true

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
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
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🩺   SERVICE AVAILABILITY & HEALTH WATCHDOG            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Monitored Services : ${SERVICES[*]}"
    echo "Timestamp          : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target         : $LOG_FILE"
    echo "------------------------------------------------------------"
}

is_service_running() {
    local svc="$1"
    if command -v systemctl &>/dev/null; then
        systemctl is-active --quiet "$svc" 2>/dev/null && return 0
    fi
    pgrep -x "$svc" &>/dev/null && return 0
    return 1
}

restart_service() {
    local svc="$1"
    log_warn "Attempting automated restart for '$svc'..."

    if command -v systemctl &>/dev/null && [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        if systemctl restart "$svc" 2>/dev/null; then
            log_info "Service '$svc' restarted successfully via systemctl."
            return 0
        else
            log_error "Failed to restart service '$svc' via systemctl."
            return 1
        fi
    else
        log_warn "[SIMULATION] Non-root/simulated restart triggered for '$svc'."
        return 0
    fi
}

audit_services() {
    local down_count=0
    local up_count=0

    for svc in "${SERVICES[@]}"; do
        if is_service_running "$svc"; then
            echo -e "Service [${GREEN}${BOLD} UP ${RESET}] : ${svc}"
            ((up_count++))
        else
            echo -e "Service [${RED}${BOLD}DOWN${RESET}] : ${svc}"
            ((down_count++))
            log_error "Service '$svc' detected in DOWN/INACTIVE state."

            if [[ "$AUTO_RESTART" == "true" ]]; then
                if restart_service "$svc"; then
                    log_info "Service '$svc' recovery executed."
                else
                    log_error "Service '$svc' failed to recover. Manual intervention required!"
                fi
            fi
        fi
    done

    echo "------------------------------------------------------------"
    log_info "Audit Summary: $up_count Healthy | $down_count Inactive"
}

parse_args() {
    local custom_services=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--services)
                read -ra custom_services <<< "$2"
                SERVICES=("${custom_services[@]}")
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            --no-restart)
                AUTO_RESTART=false
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [SERVICE...]"
                echo "Options:"
                echo "  -s, --services 'SVC1 SVC2'           Specify list of services to audit"
                echo "  -o, --output FILE, --log-file FILE   Write health status and alert logs to file"
                echo "      --no-restart                     Do not attempt automated restarts on dead services"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    if (( ${#custom_services[@]} == 0 )); then
                        SERVICES=()
                    fi
                    SERVICES+=("$1")
                    shift
                else
                    log_error "Unknown argument: $1"
                    exit 1
                fi
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
    audit_services
}

main "$@"
