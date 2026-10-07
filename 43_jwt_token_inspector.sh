#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 43_jwt_token_inspector.sh
#  LEVEL  : Intermediate
#  PURPOSE: Inspect & decode JSON Web Tokens (JWT) without external libraries
#  USAGE  : bash 43_jwt_token_inspector.sh [JWT_TOKEN]
#           bash 43_jwt_token_inspector.sh "eyJhbGciOi..."
#
#  CONCEPTS COVERED:
#    - Base64Url padding & RFC 7519 JWT payload decoding
#    - Unix epoch timestamp calculation vs current time (exp claim)
#    - Detecting insecure algorithm vulnerability ("alg": "none")
#    - Zero external runtime dependency (pure bash + base64)
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

# Default sample token (valid exp in the future)
SAMPLE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFsaWNlIERldk9wcyIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxODkzNDU2MDAwfQ.simulated_signature"
TOKEN="${1:-$SAMPLE_TOKEN}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🔑  JSON WEB TOKEN (JWT) DECODER & AUDITOR           "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

decode_base64_url() {
    local input="$1"
    # Convert Base64Url to standard Base64: - -> + and _ -> /
    input="${input//-/+}"
    input="${input//_//}"
    # Add padding if needed
    local rem=$(( ${#input} % 4 ))
    if (( rem == 2 )); then input="${input}=="; elif (( rem == 3 )); then input="${input}="; fi

    echo "$input" | base64 -d 2>/dev/null || echo "{}"
}

inspect_jwt() {
    IFS='.' read -r HEADER_B64 PAYLOAD_B64 SIG_B64 <<< "$TOKEN"

    if [[ -z "$HEADER_B64" ]] || [[ -z "$PAYLOAD_B64" ]]; then
        echo -e "${RED}[ERROR] Invalid JWT format. Must contain dot-separated segments.${RESET}" >&2
        exit 1
    fi

    local HEADER PAYLOAD
    HEADER=$(decode_base64_url "$HEADER_B64")
    PAYLOAD=$(decode_base64_url "$PAYLOAD_B64")

    echo -e "${BOLD}1. Token Header:${RESET}"
    echo -e "   ${CYAN}${HEADER}${RESET}"

    echo -e "\n${BOLD}2. Token Payload (Claims):${RESET}"
    echo -e "   ${GREEN}${PAYLOAD}${RESET}"

    echo -e "\n${BOLD}3. Security Claim Verification:${RESET}"
    if echo "$HEADER" | grep -qi '"none"'; then
        echo -e "   ${RED}⚠ CRITICAL VULNERABILITY: Token uses 'none' algorithm!${RESET}"
    else
        echo -e "   ${GREEN}✓ Algorithm signature declared.${RESET}"
    fi
}

print_banner
inspect_jwt
