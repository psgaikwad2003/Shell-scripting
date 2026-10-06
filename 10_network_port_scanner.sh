#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 10_network_port_scanner.sh
#  LEVEL  : Intermediate
#  PURPOSE: Pure Bash TCP Port Scanner & Connectivity Checker
#  USAGE  : bash 10_network_port_scanner.sh [HOST] [START_PORT] [END_PORT]
#           bash 10_network_port_scanner.sh 127.0.0.1 20 85
#
#  CONCEPTS COVERED:
#    - Bash pseudo-device /dev/tcp/<host>/<port> redirection
#    - Subshell timeout execution with timeout command
#    - Numerical sequence iteration with seq / brace expansion
#    - Well-known service port mapping
#    - Error redirection (2>/dev/null) and status codes
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

TARGET_HOST="${1:-127.0.0.1}"
START_PORT="${2:-20}"
END_PORT="${3:-100}"
TIMEOUT_SEC=1

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🔍  PURE BASH TCP NETWORK PORT SCANNER               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Host   : $TARGET_HOST"
    echo "Port Range    : $START_PORT -> $END_PORT"
    echo "Timeout       : ${TIMEOUT_SEC}s per probe"
    echo "------------------------------------------------------------"
}

get_service_name() {
    local port="$1"
    case "$port" in
        21)  echo "FTP" ;;
        22)  echo "SSH" ;;
        23)  echo "Telnet" ;;
        25)  echo "SMTP" ;;
        53)  echo "DNS" ;;
        80)  echo "HTTP" ;;
        110) echo "POP3" ;;
        143) echo "IMAP" ;;
        443) echo "HTTPS" ;;
        3306) echo "MySQL" ;;
        5432) echo "PostgreSQL" ;;
        6379) echo "Redis" ;;
        8080) echo "HTTP-Proxy / Alt" ;;
        *)   echo "Unknown" ;;
    esac
}

scan_port() {
    local host="$1"
    local port="$2"

    # Attempt connection using /dev/tcp pseudo-filesystem with 1-second timeout
    if timeout "$TIMEOUT_SEC" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        local svc
        svc=$(get_service_name "$port")
        printf "  Port %-6d [%sOPEN%s]     Service: %s\n" "$port" "${GREEN}${BOLD}" "${RESET}" "$svc"
        return 0
    else
        return 1
    fi
}

run_scan() {
    local open_count=0
    echo -e "Scanning ports on ${BOLD}${TARGET_HOST}${RESET}...\n"

    for ((port=START_PORT; port<=END_PORT; port++)); do
        if scan_port "$TARGET_HOST" "$port"; then
            ((open_count++))
        fi
    done

    echo "------------------------------------------------------------"
    if (( open_count > 0 )); then
        echo -e "${GREEN}Scan complete: Discovered $open_count open TCP port(s).${RESET}"
    else
        echo -e "${YELLOW}Scan complete: No open TCP ports detected in range $START_PORT-$END_PORT.${RESET}"
    fi
}

main() {
    print_header
    run_scan
}

main "$@"
