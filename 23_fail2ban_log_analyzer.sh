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

AUTH_LOG="/tmp/sample_auth.log"
THRESHOLD=3
OUTPUT_LOG="${REPORT_LOG_FILE:-}"

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${RESET} [${ts}] ${msg}"
    [[ -n "$OUTPUT_LOG" ]] && echo "[INFO] [${ts}] ${msg}" >> "$OUTPUT_LOG"
}

log_warn() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${RESET} [${ts}] ${msg}"
    [[ -n "$OUTPUT_LOG" ]] && echo "[WARN] [${ts}] ${msg}" >> "$OUTPUT_LOG"
}

log_error() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${RESET} [${ts}] ${msg}" >&2
    [[ -n "$OUTPUT_LOG" ]] && echo "[ERROR] [${ts}] ${msg}" >> "$OUTPUT_LOG"
}

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🚨  SSH AUTH LOG & BRUTE-FORCE INTRUSION ANALYZER    "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Log Target : $AUTH_LOG"
    echo "Threshold  : >= $THRESHOLD failed attempts"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$OUTPUT_LOG" ]] && echo "Output Log : $OUTPUT_LOG"
    echo "------------------------------------------------------------"
}

seed_demo_log() {
    if [[ ! -f "$AUTH_LOG" ]]; then
        log_info "No log detected at $AUTH_LOG. Seeding synthetic demo telemetry..."
        cat << 'EOF' > "$AUTH_LOG"
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
    log_info "Aggregating failed authentication attempts from $AUTH_LOG..."

    local offenders
    offenders=$(grep "Failed password" "$AUTH_LOG" 2>/dev/null | awk '{
        for (i=1; i<=NF; i++) {
            if ($i == "from") {
                print $(i+1)
            }
        }
    }' | sort | uniq -c | sort -nr || true)

    if [[ -z "$offenders" ]]; then
        log_info "No failed login attempts detected in $AUTH_LOG."
        return
    fi

    printf "%-10s %-20s %-25s\n" "Attempts" "IP Address" "Suggested Action"
    echo "------------------------------------------------------------"

    while read -r count ip; do
        [[ -z "$count" ]] && continue
        if (( count >= THRESHOLD )); then
            printf "%-10s %-20s %b\n" "$count" "$ip" "${RED}${BOLD}[BLOCK / BAN]${RESET}"
            log_warn "Host $ip exceeded ban threshold ($count attempts >= $THRESHOLD)"
        else
            printf "%-10s %-20s %b\n" "$count" "$ip" "${YELLOW}[MONITOR]${RESET}"
            log_info "Host $ip logged $count failed attempt(s)"
        fi
    done <<< "$offenders"

    echo "------------------------------------------------------------"
    echo -e "${CYAN}Generated Ban Command:${RESET}"
    while read -r count ip; do
        [[ -z "$count" ]] && continue
        if (( count >= THRESHOLD )); then
            echo "  iptables -A INPUT -s $ip -j DROP"
            [[ -n "$OUTPUT_LOG" ]] && echo "iptables -A INPUT -s $ip -j DROP" >> "$OUTPUT_LOG"
        fi
    done <<< "$offenders"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                AUTH_LOG="$2"
                shift 2
                ;;
            -t|--threshold)
                THRESHOLD="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                OUTPUT_LOG="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [AUTH_LOG] [THRESHOLD]"
                echo "Options:"
                echo "  -i, --input FILE                     Auth log file to inspect"
                echo "  -t, --threshold NUM                  Failed attempts ban threshold (default: 3)"
                echo "  -o, --output FILE, --log-file FILE   Write structured report and ban rules to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ -z "${1_pos:-}" ]]; then
                    AUTH_LOG="$1"
                    1_pos=1
                elif [[ -z "${2_pos:-}" ]]; then
                    THRESHOLD="$1"
                    2_pos=1
                fi
                shift
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    if [[ -n "$OUTPUT_LOG" ]]; then
        mkdir -p "$(dirname "$OUTPUT_LOG")" 2>/dev/null || true
        : > "$OUTPUT_LOG"
    fi
    print_header
    analyze_logs
    log_info "Log analysis completed successfully."
}

main "$@"
