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

SLOW_LOG="${1:-/tmp/mysql_slow.log}"
THRESHOLD="${2:-1.5}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🐬  MYSQL / MARIADB SLOW QUERY LOG PARSER            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Slow Log : $SLOW_LOG"
    echo "SLA Threshold   : >= ${THRESHOLD}s"
    echo "Timestamp       : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

seed_sample_if_missing() {
    if [[ ! -f "$SLOW_LOG" ]]; then
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
    echo -e "${BOLD}Scanning for queries exceeding ${THRESHOLD} seconds...${RESET}\n"

    awk -v thresh="$THRESHOLD" '
    BEGIN { slow_count = 0; }
    /# Query_time:/ {
        qtime = $3;
        lock_t = $5;
        rows_sent = $7;
        rows_exam = $9;
        if (qtime + 0 >= thresh + 0) {
            slow_count++;
            printf "\033[0;31m[SLOW QUERY #%d]\033[0m Execution Time: \033[1;33m%s s\033[0m | Rows Examined: %s | Rows Sent: %s\n", slow_count, qtime, rows_exam, rows_sent;
            getline;
            getline;
            printf "  \033[0;36mQuery:\033[0m %s\n\n", $0;
        }
    }
    END {
        printf "\033[1mTotal slow queries identified: %d\033[0m\n", slow_count;
    }
    ' "$SLOW_LOG"
}

print_banner
seed_sample_if_missing
parse_slow_log
