#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 18_firewall_hardening_rules.sh
#  LEVEL  : Advanced
#  PURPOSE: Baseline Security Firewall Hardening & Rule Configurator
#  USAGE  : bash 18_firewall_hardening_rules.sh [--apply|--show]
#
#  CONCEPTS COVERED:
#    - UFW (Uncomplicated Firewall) and iptables management
#    - Principle of least privilege: default deny incoming, allow outgoing
#    - State tracking: ESTABLISHED, RELATED connection preservation
#    - Protecting SSH port with connection rate limiting
#    - Unprivileged simulation mode
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

MODE="${1:---show}"
SSH_PORT=22

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🧱  BASELINE FIREWALL HARDENING CONFIGURATOR         "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Operation Mode : $MODE"
    echo "Timestamp      : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

check_privileges() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo -e "${YELLOW}[NOTE] Non-root environment detected. Firewall changes will be simulated.${RESET}"
        IS_SIMULATED=true
    else
        IS_SIMULATED=false
    fi
}

display_planned_rules() {
    echo -e "${BOLD}Recommended Hardening Rules Blueprint:${RESET}"
    echo "  1. Default Policy Incoming : DROP (Deny all unsolicited incoming)"
    echo "  2. Default Policy Outgoing : ACCEPT (Allow system updates / requests)"
    echo "  3. Loopback (lo)           : ACCEPT (Localhost communications)"
    echo "  4. Established/Related     : ACCEPT (Preserve ongoing sessions)"
    echo "  5. SSH (Port $SSH_PORT)           : LIMIT (Rate-limit brute force attempts)"
    echo "  6. HTTP/HTTPS (80/443)     : ACCEPT (Web server accessibility)"
    echo "  7. ICMP Ping Echo          : RATE-LIMIT (Prevent ping flood)"
}

apply_firewall_rules() {
    echo -e "\nApplying baseline rules..."
    if [[ "$IS_SIMULATED" == "true" ]]; then
        echo -e "${GREEN}[SIMULATION] The following commands would be executed:${RESET}"
        echo "  - ufw default deny incoming"
        echo "  - ufw default allow outgoing"
        echo "  - ufw limit ${SSH_PORT}/tcp comment 'Rate limit SSH'"
        echo "  - ufw allow 80/tcp comment 'HTTP'"
        echo "  - ufw allow 443/tcp comment 'HTTPS'"
        echo "  - ufw enable"
    else
        if command -v ufw &>/dev/null; then
            ufw default deny incoming
            ufw default allow outgoing
            ufw limit "${SSH_PORT}/tcp"
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw --force enable
            echo -e "${GREEN}✔ UFW rules configured and activated.${RESET}"
        else
            echo -e "${YELLOW}UFW not installed. Please install ufw or configure iptables directly.${RESET}"
        fi
    fi
}

main() {
    print_header
    check_privileges
    display_planned_rules
    if [[ "$MODE" == "--apply" ]]; then
        apply_firewall_rules
    else
        echo -e "\n${YELLOW}To apply these rules, run with: $0 --apply${RESET}"
    fi
}

main "$@"
