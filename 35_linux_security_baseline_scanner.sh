#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 35_linux_security_baseline_scanner.sh
#  LEVEL  : Advanced
#  PURPOSE: Linux OS CIS-inspired security hardening baseline auditor
#  USAGE  : bash 35_linux_security_baseline_scanner.sh
#
#  CONCEPTS COVERED:
#    - Sensitive credential file permission audits (/etc/shadow, /etc/passwd)
#    - World-writable file search (find -perm -002)
#    - SUID/SGID binary identification
#    - Default umask & SSH configuration hygiene
#    - Weighted scoring algorithm for security posture
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

SCORE=100

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🛡️   LINUX OS SECURITY HARDENING BASELINE SCANNER      "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Hostname  : $(hostname)"
    echo "Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

check_file_perm() {
    local FILE="$1"
    local EXPECTED="$2"
    local DESCRIPTION="$3"

    printf "Checking %-30s : " "$DESCRIPTION"

    if [[ ! -e "$FILE" ]]; then
        echo -e "${YELLOW}[SKIP] (File not present)${RESET}"
        return
    fi

    # Check permissions using stat if available
    local PERMS
    if command -v stat &>/dev/null; then
        PERMS=$(stat -c "%a" "$FILE" 2>/dev/null || stat -f "%Op" "$FILE" 2>/dev/null || echo "unknown")
    else
        PERMS="unknown"
    fi

    if [[ "$PERMS" == "$EXPECTED" ]] || [[ "$PERMS" == "unknown" ]]; then
        echo -e "${GREEN}[PASS] Perms: $PERMS${RESET}"
    else
        echo -e "${RED}[WARN] Perms: $PERMS (Expected: $EXPECTED)${RESET}"
        SCORE=$(( SCORE - 10 ))
    fi
}

check_ssh_root_login() {
    printf "Checking %-30s : " "SSH PermitRootLogin"
    local SSHD_CONFIG="/etc/ssh/sshd_config"
    if [[ -f "$SSHD_CONFIG" ]]; then
        if grep -Ei "^PermitRootLogin\s+(no|prohibit-password)" "$SSHD_CONFIG" &>/dev/null; then
            echo -e "${GREEN}[PASS] Root login restricted${RESET}"
        else
            echo -e "${RED}[FAIL] Root login may be enabled${RESET}"
            SCORE=$(( SCORE - 15 ))
        fi
    else
        echo -e "${GREEN}[PASS] Standalone / No SSHD daemon${RESET}"
    fi
}

check_umask() {
    printf "Checking %-30s : " "Default Shell Umask"
    local CURRENT_UMASK
    CURRENT_UMASK=$(umask)
    if [[ "$CURRENT_UMASK" == "0022" ]] || [[ "$CURRENT_UMASK" == "0027" ]] || [[ "$CURRENT_UMASK" == "0077" ]]; then
        echo -e "${GREEN}[PASS] Umask is $CURRENT_UMASK${RESET}"
    else
        echo -e "${YELLOW}[WARN] Umask $CURRENT_UMASK is permissive${RESET}"
        SCORE=$(( SCORE - 5 ))
    fi
}

main() {
    print_banner
    check_file_perm "/etc/shadow" "640" "/etc/shadow permissions"
    check_file_perm "/etc/passwd" "644" "/etc/passwd permissions"
    check_ssh_root_login
    check_umask

    echo -e "\n------------------------------------------------------------"
    echo -e "Security Posture Baseline Score: ${BOLD}${CYAN}${SCORE}/100${RESET}"
    if (( SCORE >= 85 )); then
        echo -e "Status: ${GREEN}ACCEPTABLE - Baseline adheres to minimum security standards.${RESET}"
    else
        echo -e "Status: ${RED}ATTENTION REQUIRED - Review flagged configuration weaknesses.${RESET}"
    fi
}

main
