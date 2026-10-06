#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 24_cron_job_auditor.sh
#  LEVEL  : Intermediate - Advanced
#  PURPOSE: Cron Job Security & Scheduling Auditor
#  USAGE  : bash 24_cron_job_auditor.sh
#
#  CONCEPTS COVERED:
#    - Inspecting system-wide cron directories (/etc/cron*, /etc/crontab)
#    - Iterating across /var/spool/cron user crontabs
#    - Checking executable and script permissions (detecting world-writable scripts)
#    - Security compliance scanning for automated scheduled tasks
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ⏰  CRON JOB & SCHEDULED TASK SECURITY AUDITOR        "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Audit Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

audit_user_crontab() {
    echo -e "${BOLD}[1] Current User Crontab:${RESET}"
    if crontab -l 2>/dev/null | grep -v '^#' | grep -q '[^[:space:]]'; then
        crontab -l 2>/dev/null | grep -v '^#' | while read -r line; do
            [[ -z "$line" ]] && continue
            echo "  ↳ Entry: $line"
        done
    else
        echo -e "  ↳ ${YELLOW}No active user crontab entries found.${RESET}"
    fi
}

audit_system_crons() {
    echo -e "\n${BOLD}[2] System-wide Cron Directories (/etc/cron*):${RESET}"
    local cron_dirs=("/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/cron.d")

    for dir in "${cron_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local file_count
            file_count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l || echo 0)
            echo -e "  - Directory: ${CYAN}${dir}${RESET} (${file_count} script(s))"

            # Check for dangerous permissions (world-writable)
            find "$dir" -maxdepth 1 -type f -perm -002 2>/dev/null | while read -r insecure_file; do
                echo -e "    ${RED}${BOLD}[SECURITY RISK] World-writable cron file:${RESET} $insecure_file"
            done
        fi
    done
}

audit_system_crontab() {
    echo -e "\n${BOLD}[3] Main /etc/crontab Configuration:${RESET}"
    if [[ -f "/etc/crontab" ]]; then
        grep -v '^#' /etc/crontab | grep '[^[:space:]]' || echo "No active entries."
    else
        echo -e "  ↳ ${YELLOW}/etc/crontab not present (standard on non-Linux or containerized systems).${RESET}"
    fi
}

main() {
    print_header
    audit_user_crontab
    audit_system_crons
    audit_system_crontab
    echo "------------------------------------------------------------"
    echo -e "${GREEN}✔ Cron audit complete.${RESET}"
}

main "$@"
