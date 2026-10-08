#!/usr/bin/env bash
# =============================================================================
# Script: 32_nginx_log_analyzer.sh
# Problem Statement: Parse Nginx/Apache access logs to extract top client IPs, top requested endpoints, and HTTP status code distributions.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

ACCESS_LOG="/tmp/sample_nginx_access.log"
OUTPUT_REPORT="${REPORT_LOG_FILE:-}"

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${RESET} [${ts}] ${msg}"
    [[ -n "$OUTPUT_REPORT" ]] && echo "[INFO] [${ts}] ${msg}" >> "$OUTPUT_REPORT"
}

log_warn() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${RESET} [${ts}] ${msg}"
    [[ -n "$OUTPUT_REPORT" ]] && echo "[WARN] [${ts}] ${msg}" >> "$OUTPUT_REPORT"
}

log_error() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${RESET} [${ts}] ${msg}" >&2
    [[ -n "$OUTPUT_REPORT" ]] && echo "[ERROR] [${ts}] ${msg}" >> "$OUTPUT_REPORT"
}

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       📊  NGINX / APACHE ACCESS LOG TRAFFIC ANALYZER       "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Log Target    : $ACCESS_LOG"
    echo "Timestamp     : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$OUTPUT_REPORT" ]] && echo "Report Output : $OUTPUT_REPORT"
    echo "------------------------------------------------------------"
}

seed_sample_log_if_missing() {
    if [[ ! -f "$ACCESS_LOG" ]]; then
        log_warn "Creating synthetic demo access log at $ACCESS_LOG."
        cat << 'EOF' > "$ACCESS_LOG"
192.168.1.105 - - [07/Oct/2026:10:00:01 +0000] "GET /api/v1/users HTTP/1.1" 200 4523
192.168.1.105 - - [07/Oct/2026:10:00:05 +0000] "GET /api/v1/users HTTP/1.1" 200 4523
10.0.0.12 - - [07/Oct/2026:10:00:10 +0000] "POST /login HTTP/1.1" 200 1204
10.0.0.12 - - [07/Oct/2026:10:00:12 +0000] "POST /login HTTP/1.1" 401 230
172.16.0.45 - - [07/Oct/2026:10:00:15 +0000] "GET /wp-login.php HTTP/1.1" 404 162
172.16.0.45 - - [07/Oct/2026:10:00:16 +0000] "GET /.env HTTP/1.1" 404 162
172.16.0.45 - - [07/Oct/2026:10:00:17 +0000] "GET /phpmyadmin HTTP/1.1" 404 162
192.168.1.105 - - [07/Oct/2026:10:00:20 +0000] "GET /dashboard HTTP/1.1" 200 8920
192.168.1.200 - - [07/Oct/2026:10:00:25 +0000] "GET /heavy-report HTTP/1.1" 500 532
10.0.0.12 - - [07/Oct/2026:10:00:30 +0000] "GET /api/v1/orders HTTP/1.1" 304 0
EOF
    fi
}

analyze_logs() {
    local TOTAL_REQUESTS
    TOTAL_REQUESTS=$(wc -l < "$ACCESS_LOG")
    log_info "Total Requests Logged: $TOTAL_REQUESTS"

    log_info "Top Client IP Addresses:"
    while read -r count ip; do
        [[ -z "$count" ]] && continue
        log_info "  ↳ $count requests from $ip"
    done < <(awk '{print $1}' "$ACCESS_LOG" | sort | uniq -c | sort -nr | head -n 5)

    log_info "Top Requested Endpoints / URLs:"
    while read -r count url; do
        [[ -z "$count" ]] && continue
        log_info "  ↳ $count hits on $url"
    done < <(awk '{print $7}' "$ACCESS_LOG" | sort | uniq -c | sort -nr | head -n 5)

    log_info "HTTP Response Status Code Breakdown:"
    while read -r count status; do
        [[ -z "$count" ]] && continue
        case "$status" in
            2*) log_info "  ↳ $count [$status OK]" ;;
            3*) log_info "  ↳ $count [$status REDIRECT]" ;;
            4*) log_warn "  ↳ $count [$status CLIENT ERROR]" ;;
            5*) log_error "  ↳ $count [$status SERVER ERROR]" ;;
            *)  log_info "  ↳ $count [$status OTHER]" ;;
        esac
    done < <(awk '{print $9}' "$ACCESS_LOG" | sort | uniq -c | sort -nr)
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                ACCESS_LOG="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                OUTPUT_REPORT="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [ACCESS_LOG]"
                echo "Options:"
                echo "  -i, --input FILE                     Access log file path"
                echo "  -o, --output FILE, --log-file FILE   Write traffic analytics report to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                ACCESS_LOG="$1"
                shift
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    if [[ -n "$OUTPUT_REPORT" ]]; then
        mkdir -p "$(dirname "$OUTPUT_REPORT")" 2>/dev/null || true
        : > "$OUTPUT_REPORT"
    fi
    print_banner
    seed_sample_log_if_missing
    analyze_logs
    log_info "Nginx access log analysis completed."
}

main "$@"
