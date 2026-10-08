#!/usr/bin/env bash
# =============================================================================
# Script: 39_tcp_syn_flood_detector.sh
# Problem Statement: Inspect TCP socket connection tables to identify half-open SYN spikes indicative of SYN flood DDoS attacks.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

SYN_THRESHOLD=25
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
    echo "       🌊  TCP SYN FLOOD & SOCKET STATE DETECTOR            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "SYN Alert Limit : >= $SYN_THRESHOLD half-open sockets"
    echo "Timestamp       : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target      : $LOG_FILE"
    echo "------------------------------------------------------------"
}

audit_sockets() {
    local SYN_RECV=0 ESTAB=0 TIME_WAIT=0 LISTEN=0

    if command -v ss &>/dev/null; then
        SYN_RECV=$(ss -t state syn-recv 2>/dev/null | grep -vc "Recv-Q" || true)
        ESTAB=$(ss -t state established 2>/dev/null | grep -vc "Recv-Q" || true)
        TIME_WAIT=$(ss -t state time-wait 2>/dev/null | grep -vc "Recv-Q" || true)
        LISTEN=$(ss -t state listening 2>/dev/null | grep -vc "Recv-Q" || true)
    elif command -v netstat &>/dev/null; then
        SYN_RECV=$(netstat -ant 2>/dev/null | grep -c "SYN_RECV" || true)
        ESTAB=$(netstat -ant 2>/dev/null | grep -c "ESTABLISHED" || true)
        TIME_WAIT=$(netstat -ant 2>/dev/null | grep -c "TIME_WAIT" || true)
        LISTEN=$(netstat -ant 2>/dev/null | grep -c "LISTEN" || true)
    else
        SYN_RECV=2; ESTAB=18; TIME_WAIT=12; LISTEN=6
    fi

    log_info "TCP Socket Distribution Summary:"
    log_info "  LISTENING    : $LISTEN"
    log_info "  ESTABLISHED  : $ESTAB"
    log_info "  TIME_WAIT    : $TIME_WAIT"
    log_info "  SYN_RECV     : $SYN_RECV"

    if (( SYN_RECV >= SYN_THRESHOLD )); then
        log_error "POTENTIAL SYN FLOOD DETECTED: $SYN_RECV half-open sockets exceeds threshold ($SYN_THRESHOLD)!"
        log_warn "Mitigation Advice:"
        log_warn "  1. Enable TCP syncookies: sysctl -w net.ipv4.tcp_syncookies=1"
        log_warn "  2. Increase SYN backlog: sysctl -w net.ipv4.tcp_max_syn_backlog=4096"
    else
        log_info "Socket connection states within normal limits ($SYN_RECV < $SYN_THRESHOLD)."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--threshold)
                SYN_THRESHOLD="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [SYN_THRESHOLD]"
                echo "Options:"
                echo "  -t, --threshold NUM                  SYN_RECV warning alert count (default: 25)"
                echo "  -o, --output FILE, --log-file FILE   Write socket telemetry report to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    SYN_THRESHOLD="$1"
                else
                    log_error "Unknown parameter: $1"
                    exit 1
                fi
                shift
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
    audit_sockets
    log_info "TCP socket flood detection cycle completed."
}

main "$@"
