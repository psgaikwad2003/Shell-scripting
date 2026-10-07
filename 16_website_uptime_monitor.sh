#!/usr/bin/env bash
# =============================================================================
# Script: 16_website_uptime_monitor.sh
# Problem Statement: Monitor HTTP/HTTPS endpoints for status codes, latency thresholds, and uptime availability.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

URLS=("${@:-https://httpbin.org/status/200 https://github.com https://httpbin.org/status/500}")

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🌐  HTTP / HTTPS ENDPOINT UPTIME MONITOR             "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
    printf "%-35s %-10s %-12s %-10s\n" "Endpoint URL" "HTTP Code" "Response Time" "Status"
    echo "------------------------------------------------------------"
}

check_endpoint() {
    local url="$1"

    if ! command -v curl &>/dev/null; then
        echo -e "${RED}[ERROR] 'curl' is required to run this script.${RESET}"
        return 1
    fi

    local response
    response=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000 0.000")

    local http_code
    http_code=$(echo "$response" | awk '{print $1}')
    local resp_time
    resp_time=$(echo "$response" | awk '{print $2}')
    local formatted_time="${resp_time}s"

    local status_badge
    if [[ "$http_code" =~ ^[23] ]]; then
        status_badge="${GREEN}${BOLD}UP${RESET}"
    elif [[ "$http_code" =~ ^[45] ]]; then
        status_badge="${RED}${BOLD}DOWN (${http_code})${RESET}"
    else
        status_badge="${RED}${BOLD}UNREACHABLE${RESET}"
        http_code="ERR"
    fi

    printf "%-35s %-10s %-12s %b\n" "$url" "$http_code" "$formatted_time" "$status_badge"
}

run_monitor() {
    for target in "${URLS[@]}"; do
        check_endpoint "$target"
    done
    echo "------------------------------------------------------------"
}

main() {
    print_header
    run_monitor
}

main "$@"
