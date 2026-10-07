#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 32_nginx_log_analyzer.sh
#  LEVEL  : Intermediate
#  PURPOSE: Parse web server (Nginx/Apache) access logs for traffic analytics & IP forensics
#  USAGE  : bash 32_nginx_log_analyzer.sh [LOG_FILE]
#           bash 32_nginx_log_analyzer.sh /var/log/nginx/access.log
#
#  CONCEPTS COVERED:
#    - Text streaming pipelines (awk, sort, uniq, head)
#    - Aggregating top IP requesters & top requested endpoints
#    - HTTP status code distribution (2xx, 3xx, 4xx, 5xx)
#    - Automatic synthetic sample generation for testing
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

LOG_FILE="${1:-/tmp/sample_nginx_access.log}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       📊  NGINX / APACHE ACCESS LOG TRAFFIC ANALYZER       "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Log Target : $LOG_FILE"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

seed_sample_log_if_missing() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}[INFO] Creating sample synthetic log at $LOG_FILE for demonstration.${RESET}"
        cat << 'EOF' > "$LOG_FILE"
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
    TOTAL_REQUESTS=$(wc -l < "$LOG_FILE")
    echo -e "${BOLD}Total Requests Logged:${RESET} $TOTAL_REQUESTS\n"

    echo -e "${BOLD}🌐 Top 5 Requisitioning Client IP Addresses:${RESET}"
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -n 5 | while read -r count ip; do
        printf "  %-6s requests from  %s\n" "$count" "$ip"
    done

    echo -e "\n${BOLD}🔗 Top 5 Most Requested Endpoints / URLs:${RESET}"
    awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -n 5 | while read -r count url; do
        printf "  %-6s hits        %s\n" "$count" "$url"
    done

    echo -e "\n${BOLD}📈 HTTP Response Status Code Breakdown:${RESET}"
    awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -nr | while read -r count status; do
        case "$status" in
            2*) printf "  ${GREEN}%-6s [%s OK]${RESET}\n" "$count" "$status" ;;
            3*) printf "  ${CYAN}%-6s [%s REDIRECT]${RESET}\n" "$count" "$status" ;;
            4*) printf "  ${YELLOW}%-6s [%s CLIENT ERROR]${RESET}\n" "$count" "$status" ;;
            5*) printf "  ${RED}%-6s [%s SERVER ERROR]${RESET}\n" "$count" "$status" ;;
            *)  printf "  %-6s [%s OTHER]\n" "$count" "$status" ;;
        esac
    done
}

print_banner
seed_sample_log_if_missing
analyze_logs
