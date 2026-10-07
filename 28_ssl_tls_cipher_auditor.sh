#!/usr/bin/env bash
# =============================================================================
# Script: 28_ssl_tls_cipher_auditor.sh
# Problem Statement: Audit remote SSL/TLS endpoints to identify deprecated protocol versions (SSLv3, TLS 1.0/1.1) and insecure cipher suites.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

TARGET_HOST="${1:-github.com}"
TARGET_PORT="${2:-443}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🔒  SSL/TLS CIPHER SUITE & PROTOCOL AUDITOR          "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Host : ${TARGET_HOST}:${TARGET_PORT}"
    echo "Timestamp   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

check_dependencies() {
    if ! command -v openssl &>/dev/null; then
        echo -e "${RED}[ERROR] openssl command is required but not installed.${RESET}" >&2
        exit 1
    fi
}

test_protocol() {
    local PROTOCOL="$1"
    local PROTO_FLAG="$2"
    local RISK_LEVEL="$3"

    printf "Testing %-12s : " "$PROTOCOL"

    if openssl s_client -connect "${TARGET_HOST}:${TARGET_PORT}" "$PROTO_FLAG" </dev/null &>/dev/null; then
        if [[ "$RISK_LEVEL" == "INSECURE" ]]; then
            echo -e "${RED}[VULNERABLE] Supported (${RISK_LEVEL})${RESET}"
        elif [[ "$RISK_LEVEL" == "LEGACY" ]]; then
            echo -e "${YELLOW}[WARNING] Supported (${RISK_LEVEL})${RESET}"
        else
            echo -e "${GREEN}[OK] Supported (${RISK_LEVEL})${RESET}"
        fi
    else
        echo -e "${GREEN}[SECURE] Rejected / Unsupported${RESET}"
    fi
}

inspect_current_cipher() {
    echo -e "\n${BOLD}🔍 Current Active Handshake Details:${RESET}"

    local HANDSHAKE_INFO
    HANDSHAKE_INFO=$(echo | openssl s_client -connect "${TARGET_HOST}:${TARGET_PORT}" -servername "${TARGET_HOST}" 2>/dev/null || true)

    if [[ -z "$HANDSHAKE_INFO" ]]; then
        echo -e "${RED}[WARN] Could not establish connection to ${TARGET_HOST}:${TARGET_PORT}${RESET}"
        return
    fi

    local PROTOCOL
    local CIPHER
    PROTOCOL=$(echo "$HANDSHAKE_INFO" | grep -m1 "Protocol  :" | awk '{print $3}' || echo "Unknown")
    CIPHER=$(echo "$HANDSHAKE_INFO" | grep -m1 "Cipher    :" | awk '{print $3}' || echo "Unknown")

    echo "  Protocol in Use : ${CYAN}${PROTOCOL}${RESET}"
    echo "  Negotiated Suite: ${CYAN}${CIPHER}${RESET}"

    if [[ "$CIPHER" == *"ECDHE"* ]] || [[ "$CIPHER" == *"DHE"* ]]; then
        echo -e "  Forward Secrecy : ${GREEN}✓ Perfect Forward Secrecy (PFS) Active${RESET}"
    else
        echo -e "  Forward Secrecy : ${YELLOW}⚠ Forward Secrecy Not Detected${RESET}"
    fi
}

main() {
    print_banner
    check_dependencies

    echo -e "${BOLD}Protocol Support Matrix:${RESET}"
    test_protocol "SSLv3" "-ssl3" "INSECURE"
    test_protocol "TLS 1.0" "-tls1" "LEGACY"
    test_protocol "TLS 1.1" "-tls1_1" "LEGACY"
    test_protocol "TLS 1.2" "-tls1_2" "SECURE"
    test_protocol "TLS 1.3" "-tls1_3" "SECURE"

    inspect_current_cipher
    echo -e "\n${GREEN}✔ SSL/TLS cryptographic audit finished.${RESET}"
}

main "$@"
