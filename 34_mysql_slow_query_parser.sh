#!/usr/bin/env bash
# =============================================================================
# Script: 34_mysql_slow_query_parser.sh
# Problem Statement: Parse MySQL/MariaDB slow query logs to identify queries violating execution time SLAs and examine row scan ratios.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

SLOW_LOG="/tmp/mysql_slow.log"
THRESHOLD="1.5"
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
    echo "       🐬  MYSQL / MARIADB SLOW QUERY LOG PARSER            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Slow Log : $SLOW_LOG"
    echo "SLA Threshold   : >= ${THRESHOLD}s"
    echo "Timestamp       : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$OUTPUT_REPORT" ]] && echo "Report Output   : $OUTPUT_REPORT"
    echo "------------------------------------------------------------"
}

seed_sample_if_missing() {
    if [[ ! -f "$SLOW_LOG" ]]; then
        log_info "No slow log file found at $SLOW_LOG. Seeding synthetic demo queries..."
        cat << 'EOF' > "$SLOW_LOG"
# Time: 2026-10-07T09:12:01.000000Z
# User@Host: app_user[app] @ localhost [127.0.0.1]
# Query_time: 4.250100  Lock_time: 0.000100 Rows_sent: 1000  Rows_examined: 500000
SET timestamp=1791364321;
SELECT * FROM orders WHERE status = 'pending' ORDER BY created_at DESC;

# Time: 2026-10-07T09:14:22.000000Z
# User@Host: app_user[app] @ localhost [127.0.0.1]
# Query_time: 0.210000  Lock_time: 0.000050 Rows_sent: 1  Rows_examined: 1
SET timestamp=1791364462;
SELECT id, username FROM users WHERE id = 42;

# Time: 2026-10-07T09:18:45.000000Z
# User@Host: report_cron[report] @ localhost [127.0.0.1]
# Query_time: 8.841200  Lock_time: 0.001200 Rows_sent: 50  Rows_examined: 1200000
SET timestamp=1791364725;
SELECT category, count(*), sum(amount) FROM transactions GROUP BY category;
EOF
    fi
}

parse_slow_log() {
    log_info "Parsing slow query log (threshold >= ${THRESHOLD}s)..."

    local slow_results
    slow_results=$(awk -v thresh="$THRESHOLD" '
    BEGIN { slow_count = 0; }
    /# Query_time:/ {
        qtime = $3;
        lock_t = $5;
        rows_sent = $7;
        rows_exam = $9;
        if (qtime + 0 >= thresh + 0) {
            slow_count++;
            printf "SLOW_EVENT|%s|%s|%s|%d\n", qtime, rows_exam, rows_sent, slow_count;
            getline;
            getline;
            printf "QUERY_TEXT|%s\n", $0;
        }
    }
    END {
        printf "SUMMARY_COUNT|%d\n", slow_count;
    }
    ' "$SLOW_LOG")

    local count=0
    while IFS='|' read -r type f1 f2 f3 f4; do
        if [[ "$type" == "SLOW_EVENT" ]]; then
            log_warn "Slow query detected: runtime=${f1}s, examined=${f2} rows, returned=${f3} rows"
        elif [[ "$type" == "QUERY_TEXT" ]]; then
            log_info "  SQL: $f1"
        elif [[ "$type" == "SUMMARY_COUNT" ]]; then
            count="$f1"
        fi
    done <<< "$slow_results"

    if (( count > 0 )); then
        log_warn "Total slow queries violating SLA: $count"
    else
        log_info "No queries exceeded the ${THRESHOLD}s latency threshold."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input|--log)
                SLOW_LOG="$2"
                shift 2
                ;;
            -t|--threshold)
                THRESHOLD="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                OUTPUT_REPORT="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [SLOW_LOG] [THRESHOLD]"
                echo "Options:"
                echo "  -i, --input FILE                     Slow query log file to parse"
                echo "  -t, --threshold SECONDS              Query execution time threshold (default: 1.5)"
                echo "  -o, --output FILE, --log-file FILE   Write parsed query findings to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ -z "${1_pos:-}" ]]; then
                    SLOW_LOG="$1"
                    1_pos=1
                elif [[ -z "${2_pos:-}" ]]; then
                    THRESHOLD="$1"
                    2_pos=1
                fi
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
    seed_sample_if_missing
    parse_slow_log
    log_info "MySQL slow query parsing completed."
}

main "$@"
