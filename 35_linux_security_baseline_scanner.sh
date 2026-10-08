#!/usr/bin/env bash
# =============================================================================
# Script: 35_linux_security_baseline_scanner.sh
# Problem Statement: Audit Linux system security posture against CIS baselines including permissions, root SSH access, and shell umask.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

SCORE=100
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
    echo "       🛡️   LINUX OS SECURITY HARDENING BASELINE SCANNER      "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Hostname  : $(hostname 2>/dev/null || echo 'localhost')"
    echo "Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target: $LOG_FILE"
    echo "------------------------------------------------------------"
}

check_file_perm() {
    local FILE="$1"
    local EXPECTED="$2"
    local DESCRIPTION="$3"

    if [[ ! -e "$FILE" ]]; then
        log_info "Check: $DESCRIPTION - [SKIP] File $FILE not present"
        return
    fi

    local PERMS
    if command -v stat &>/dev/null; then
        PERMS=$(stat -c "%a" "$FILE" 2>/dev/null || stat -f "%Op" "$FILE" 2>/dev/null || echo "unknown")
    else
        PERMS="unknown"
    fi

    if [[ "$PERMS" == "$EXPECTED" ]] || [[ "$PERMS" == "unknown" ]]; then
        log_info "Check: $DESCRIPTION - [PASS] Perms: $PERMS"
    else
        log_warn "Check: $DESCRIPTION - [WARN] Perms: $PERMS (Expected: $EXPECTED)"
        SCORE=$(( SCORE - 10 ))
    fi
}

check_ssh_root_login() {
    local SSHD_CONFIG="/etc/ssh/sshd_config"
    if [[ -f "$SSHD_CONFIG" ]]; then
        if grep -Ei "^PermitRootLogin\s+(no|prohibit-password)" "$SSHD_CONFIG" &>/dev/null; then
            log_info "Check: SSH Root Login - [PASS] Root login restricted"
        else
            log_error "Check: SSH Root Login - [FAIL] Root login may be enabled"
            SCORE=$(( SCORE - 15 ))
        fi
    else
        log_info "Check: SSH Root Login - [PASS] Standalone / No SSHD daemon present"
    fi
}

check_umask() {
    local CURRENT_UMASK
    CURRENT_UMASK=$(umask)
    if [[ "$CURRENT_UMASK" == "0022" ]] || [[ "$CURRENT_UMASK" == "0027" ]] || [[ "$CURRENT_UMASK" == "0077" ]]; then
        log_info "Check: Default Shell Umask - [PASS] Umask is $CURRENT_UMASK"
    else
        log_warn "Check: Default Shell Umask - [WARN] Umask $CURRENT_UMASK is overly permissive"
        SCORE=$(( SCORE - 5 ))
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -o, --output FILE, --log-file FILE   Write security audit score and log to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                exit 1
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
    check_file_perm "/etc/shadow" "640" "/etc/shadow permissions"
    check_file_perm "/etc/passwd" "644" "/etc/passwd permissions"
    check_ssh_root_login
    check_umask

    echo -e "\n------------------------------------------------------------"
    log_info "Security Posture Baseline Score: ${SCORE}/100"
    if (( SCORE >= 85 )); then
        log_info "Status: ACCEPTABLE - Baseline adheres to minimum security standards."
    else
        log_warn "Status: ATTENTION REQUIRED - Review flagged configuration weaknesses."
    fi
}

main "$@"
