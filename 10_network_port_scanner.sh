#!/usr/bin/env bash
# =============================================================================
# Script: 10_network_port_scanner.sh
# Problem Statement: Scan TCP ports on target hosts to verify listening network services and audit perimeter connectivity.
# =============================================================================

set -euo pipefail

TARGET_HOST="127.0.0.1"
START_PORT=20
END_PORT=100
TIMEOUT_SEC=1
LOG_FILE="${REPORT_LOG_FILE:-}"

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
    echo "       🔍   PURE BASH TCP NETWORK PORT SCANNER               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Host   : $TARGET_HOST"
    echo "Port Range    : $START_PORT -> $END_PORT"
    echo "Timeout       : ${TIMEOUT_SEC}s per probe"
    [[ -n "$LOG_FILE" ]] && echo "Log Target    : $LOG_FILE"
    echo "------------------------------------------------------------"
}

get_service_name() {
    local port="$1"
    case "$port" in
        21)   echo "FTP" ;;
        22)   echo "SSH" ;;
        23)   echo "Telnet" ;;
        25)   echo "SMTP" ;;
        53)   echo "DNS" ;;
        80)   echo "HTTP" ;;
        110)  echo "POP3" ;;
        143)  echo "IMAP" ;;
        443)  echo "HTTPS" ;;
        3306) echo "MySQL" ;;
        5432) echo "PostgreSQL" ;;
        6379) echo "Redis" ;;
        8080) echo "HTTP-Proxy / Alt" ;;
        *)    echo "Unknown" ;;
    esac
}

scan_port() {
    local host="$1"
    local port="$2"

    if timeout "$TIMEOUT_SEC" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        local svc
        svc=$(get_service_name "$port")
        log_info "Port ${port} [OPEN] - Service: ${svc}"
        return 0
    else
        return 1
    fi
}

run_scan() {
    local open_count=0
    log_info "Scanning TCP ports on ${TARGET_HOST} (${START_PORT}-${END_PORT})..."

    for ((port=START_PORT; port<=END_PORT; port++)); do
        if scan_port "$TARGET_HOST" "$port"; then
            ((open_count++))
        fi
    done

    echo "------------------------------------------------------------"
    if (( open_count > 0 )); then
        log_info "Scan complete: Discovered $open_count open TCP port(s)."
    else
        log_info "Scan complete: No open TCP ports detected in range $START_PORT-$END_PORT."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target|--host)
                TARGET_HOST="$2"
                shift 2
                ;;
            -s|--start-port)
                START_PORT="$2"
                shift 2
                ;;
            -e|--end-port)
                END_PORT="$2"
                shift 2
                ;;
            -w|--timeout)
                TIMEOUT_SEC="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [TARGET_HOST] [START_PORT] [END_PORT]"
                echo "Options:"
                echo "  -t, --target HOST                    Target IP address or domain (default: 127.0.0.1)"
                echo "  -s, --start-port PORT                Starting port number (default: 20)"
                echo "  -e, --end-port PORT                  Ending port number (default: 100)"
                echo "  -w, --timeout SEC                    Connection timeout per probe (default: 1)"
                echo "  -o, --output FILE, --log-file FILE   Write scan results to log file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    if [[ -z "${HOST_SET:-}" ]]; then
                        TARGET_HOST="$1"
                        HOST_SET=1
                    elif [[ -z "${START_SET:-}" ]]; then
                        START_PORT="$1"
                        START_SET=1
                    elif [[ -z "${END_SET:-}" ]]; then
                        END_PORT="$1"
                        END_SET=1
                    fi
                    shift
                else
                    log_error "Unknown option: $1"
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
    run_scan
}

main "$@"
