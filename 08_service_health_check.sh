#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 08_service_health_check.sh
#  LEVEL  : Intermediate
#  PURPOSE: Service Availability Monitor & Auto-Restart Watchdog
#  USAGE  : bash 08_service_health_check.sh [SERVICE_1] [SERVICE_2] ...
#
#  CONCEPTS COVERED:
#    - systemctl / service / pgrep process detection
#    - Array iteration (${SERVICES[@]})
#    - Automatic service recovery / restart mechanism
#    - Exit code verification ($?)
#    - Syslog logging simulation & incident reporting
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

SERVICES=("${@:-nginx sshd docker cron}")
ALERT_LOG="/tmp/service_watchdog.log"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🩺  SERVICE AVAILABILITY & HEALTH WATCHDOG            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Monitored Services: ${SERVICES[*]}"
    echo "Timestamp          : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

is_service_running() {
    local svc="$1"
    if command -v systemctl &>/dev/null; then
        systemctl is-active --quiet "$svc" 2>/dev/null && return 0
    fi
    # Fallback: check via pgrep
    pgrep -x "$svc" &>/dev/null && return 0
    return 1
}

restart_service() {
    local svc="$1"
    echo -e "${YELLOW}Attempting to restart '$svc'...${RESET}"
    if command -v systemctl &>/dev/null && [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        systemctl restart "$svc" 2>/dev/null && return 0
    else
        echo -e "${YELLOW}[DRY-RUN / UNPRIVILEGED] Restart simulation for '$svc' triggered.${RESET}"
        return 0
    fi
    return 1
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
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service '$svc' detected DOWN." >> "$ALERT_LOG" 2>/dev/null || true
            
            # Trigger recovery
            if restart_service "$svc"; then
                echo -e "${GREEN}  ↳ Service '$svc' restarted successfully.${RESET}"
            else
                echo -e "${RED}  ↳ Failed to restart service '$svc'. Manual intervention required!${RESET}"
            fi
        fi
    done

    echo "------------------------------------------------------------"
    echo -e "Summary: ${GREEN}$up_count Healthy${RESET} | ${RED}$down_count Inactive${RESET}"
}

main() {
    print_header
    audit_services
}

main "$@"
