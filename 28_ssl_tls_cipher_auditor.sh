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

TARGET_HOST="github.com"
TARGET_PORT="443"
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
    echo "       🔒  SSL/TLS CIPHER SUITE & PROTOCOL AUDITOR          "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Host : ${TARGET_HOST}:${TARGET_PORT}"
    echo "Timestamp   : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Report Log  : $LOG_FILE"
    echo "------------------------------------------------------------"
}

check_dependencies() {
    if ! command -v openssl &>/dev/null; then
        log_error "openssl command is required but not installed."
        exit 1
    fi
}

test_protocol() {
    local PROTOCOL="$1"
    local PROTO_FLAG="$2"
    local RISK_LEVEL="$3"

    if openssl s_client -connect "${TARGET_HOST}:${TARGET_PORT}" "$PROTO_FLAG" </dev/null &>/dev/null; then
        if [[ "$RISK_LEVEL" == "INSECURE" ]]; then
            log_error "Protocol $PROTOCOL: [VULNERABLE] Supported ($RISK_LEVEL)"
        elif [[ "$RISK_LEVEL" == "LEGACY" ]]; then
            log_warn "Protocol $PROTOCOL: [WARNING] Supported ($RISK_LEVEL)"
        else
            log_info "Protocol $PROTOCOL: [OK] Supported ($RISK_LEVEL)"
        fi
    else
        log_info "Protocol $PROTOCOL: [SECURE] Rejected / Unsupported"
    fi
}

inspect_current_cipher() {
    log_info "Evaluating active TLS handshake details..."

    local HANDSHAKE_INFO
    HANDSHAKE_INFO=$(echo | openssl s_client -connect "${TARGET_HOST}:${TARGET_PORT}" -servername "${TARGET_HOST}" 2>/dev/null || true)

    if [[ -z "$HANDSHAKE_INFO" ]]; then
        log_warn "Could not establish connection to ${TARGET_HOST}:${TARGET_PORT}"
        return
    fi

    local PROTOCOL
    local CIPHER
    PROTOCOL=$(echo "$HANDSHAKE_INFO" | grep -m1 "Protocol  :" | awk '{print $3}' || echo "Unknown")
    CIPHER=$(echo "$HANDSHAKE_INFO" | grep -m1 "Cipher    :" | awk '{print $3}' || echo "Unknown")

    log_info "Protocol in Use : $PROTOCOL"
    log_info "Negotiated Suite: $CIPHER"

    if [[ "$CIPHER" == *"ECDHE"* ]] || [[ "$CIPHER" == *"DHE"* ]]; then
        log_info "Forward Secrecy : Perfect Forward Secrecy (PFS) Active"
    else
        log_warn "Forward Secrecy : Forward Secrecy Not Detected"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--host)
                TARGET_HOST="$2"
                shift 2
                ;;
            -p|--port)
                TARGET_PORT="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS] [HOST] [PORT]"
                echo "Options:"
                echo "  -h, --host HOST                      Target hostname or domain (default: github.com)"
                echo "  -p, --port PORT                      Target SSL/TLS port (default: 443)"
                echo "  -o, --output FILE, --log-file FILE   Write cryptographic audit summary to file"
                echo "      --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ -z "${1_pos:-}" ]]; then
                    TARGET_HOST="$1"
                    1_pos=1
                elif [[ -z "${2_pos:-}" ]]; then
                    TARGET_PORT="$1"
                    2_pos=1
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
    check_dependencies

    log_info "Testing protocol support matrix for ${TARGET_HOST}:${TARGET_PORT}..."
    test_protocol "SSLv3" "-ssl3" "INSECURE"
    test_protocol "TLS 1.0" "-tls1" "LEGACY"
    test_protocol "TLS 1.1" "-tls1_1" "LEGACY"
    test_protocol "TLS 1.2" "-tls1_2" "SECURE"
    test_protocol "TLS 1.3" "-tls1_3" "SECURE"

    inspect_current_cipher
    log_info "SSL/TLS cryptographic audit finished."
}

main "$@"
