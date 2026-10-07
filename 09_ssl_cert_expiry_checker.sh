#!/usr/bin/env bash
# =============================================================================
# Script: 09_ssl_cert_expiry_checker.sh
# Problem Statement: Inspect TLS/SSL certificates on remote domains and trigger warnings before certificate expiration thresholds.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

TARGET="${1:-google.com}"
WARN_DAYS="${2:-30}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🔒  SSL/TLS CERTIFICATE EXPIRY CHECKER               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Host       : $TARGET"
    echo "Warning Threshold : $WARN_DAYS days"
    echo "Audit Timestamp   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

check_cert_expiry() {
    local host_port="$1"
    local host="${host_port%%:*}"
    local port="${host_port##*:}"
    [[ "$port" == "$host" ]] && port=443

    echo -e "Inspecting SSL Certificate for ${BOLD}${host}:${port}${RESET}..."

    if ! command -v openssl &>/dev/null; then
        echo -e "${RED}[ERROR] 'openssl' command is not available on this system.${RESET}"
        return 1
    fi

    local cert_output
    cert_output=$(echo | openssl s_client -servername "$host" -connect "${host}:${port}" 2>/dev/null || true)

    if [[ -z "$cert_output" || ! "$cert_output" =~ "BEGIN CERTIFICATE" ]]; then
        echo -e "${RED}[ERROR] Failed to establish TLS handshake with ${host}:${port}${RESET}"
        return 1
    fi

    local end_date
    end_date=$(echo "$cert_output" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    local issuer
    issuer=$(echo "$cert_output" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')

    local expiry_epoch current_epoch seconds_diff days_left
    if date --version &>/dev/null; then
        expiry_epoch=$(date -d "$end_date" +%s)
    else
        expiry_epoch=$(date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null || date +%s)
    fi

    current_epoch=$(date +%s)
    seconds_diff=$(( expiry_epoch - current_epoch ))
    days_left=$(( seconds_diff / 86400 ))

    echo "  - Certificate Issuer : $issuer"
    echo "  - Expiration Date    : $end_date"
    echo "  - Days Remaining     : $days_left day(s)"

    if (( days_left < 0 )); then
        echo -e "  - Status: ${RED}${BOLD}[EXPIRED] Certificate expired $(( -days_left )) days ago!${RESET}"
    elif (( days_left <= WARN_DAYS )); then
        echo -e "  - Status: ${YELLOW}${BOLD}[EXPIRING SOON] Renew within $days_left days!${RESET}"
    else
        echo -e "  - Status: ${GREEN}${BOLD}[VALID] Certificate is healthy.${RESET}"
    fi
}

main() {
    print_header
    check_cert_expiry "$TARGET"
}

main "$@"
