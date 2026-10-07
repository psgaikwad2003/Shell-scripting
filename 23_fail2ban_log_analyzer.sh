#!/usr/bin/env bash
# =============================================================================
# Script: 23_fail2ban_log_analyzer.sh
# Problem Statement: Analyze authentication logs to detect SSH brute-force attempts and summarize IP ban activities.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

LOG_FILE="${1:-/tmp/sample_auth.log}"
THRESHOLD="${2:-3}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🚨  SSH AUTH LOG & BRUTE-FORCE INTRUSION ANALYZER    "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Log Target : $LOG_FILE"
    echo "Threshold  : >= $THRESHOLD failed attempts"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

seed_demo_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        cat << 'EOF' > "$LOG_FILE"
Oct 06 04:12:01 srv sshd[1234]: Failed password for root from 192.168.1.100 port 45231 ssh2
Oct 06 04:12:05 srv sshd[1235]: Failed password for root from 192.168.1.100 port 45233 ssh2
Oct 06 04:12:09 srv sshd[1236]: Failed password for invalid user admin from 192.168.1.100 port 45235 ssh2
Oct 06 04:12:12 srv sshd[1237]: Failed password for invalid user test from 192.168.1.100 port 45237 ssh2
Oct 06 04:15:20 srv sshd[1240]: Failed password for root from 10.0.0.50 port 51221 ssh2
Oct 06 04:15:24 srv sshd[1241]: Failed password for root from 10.0.0.50 port 51223 ssh2
Oct 06 04:20:01 srv sshd[1250]: Accepted publickey for dev from 192.168.1.20 port 58901 ssh2
EOF
    fi
}

analyze_logs() {
    seed_demo_log
    echo -e "${BOLD}Aggregating Failed Authentication Attempts by IP:${RESET}\n"

    local offenders
    offenders=$(grep "Failed password" "$LOG_FILE" 2>/dev/null | awk '{
        for (i=1; i<=NF; i++) {
            if ($i == "from") {
                print $(i+1)
            }
        }
    }' | sort | uniq -c | sort -nr || true)

    if [[ -z "$offenders" ]]; then
        echo -e "${GREEN}No failed login attempts detected in $LOG_FILE.${RESET}"
        return
    fi

    printf "%-10s %-20s %-25s\n" "Attempts" "IP Address" "Suggested Action"
    echo "------------------------------------------------------------"

    while read -r count ip; do
        [[ -z "$count" ]] && continue
        if (( count >= THRESHOLD )); then
            printf "%-10s %-20s %b\n" "$count" "$ip" "${RED}${BOLD}[BLOCK / BAN]${RESET}"
        else
            printf "%-10s %-20s %b\n" "$count" "$ip" "${YELLOW}[MONITOR]${RESET}"
        fi
    done <<< "$offenders"

    echo "------------------------------------------------------------"
    echo -e "${CYAN}Generated Ban Command:${RESET}"
    while read -r count ip; do
        [[ -z "$count" ]] && continue
        if (( count >= THRESHOLD )); then
            echo "  iptables -A INPUT -s $ip -j DROP"
        fi
    done <<< "$offenders"
}

main() {
    print_header
    analyze_logs
}

main "$@"
