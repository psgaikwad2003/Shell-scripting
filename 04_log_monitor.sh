#!/usr/bin/env bash
# =============================================================================
# Script: 04_log_monitor.sh
# Problem Statement: Tail and stream log files with dynamic pattern matching and automated incident alerting.
# =============================================================================

set -euo pipefail

LOG_TARGET="./demo.log"
OUTPUT_FILE="${REPORT_LOG_FILE:-}"
REPORT_DIR="./reports"
KEYWORDS=("ERROR" "CRITICAL" "FATAL" "FAILED" "WARN")
MODE="menu"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${RESET} [${ts}] ${msg}"
    [[ -n "$OUTPUT_FILE" ]] && echo "[INFO] [${ts}] ${msg}" >> "$OUTPUT_FILE"
}

log_warn() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${RESET} [${ts}] ${msg}"
    [[ -n "$OUTPUT_FILE" ]] && echo "[WARN] [${ts}] ${msg}" >> "$OUTPUT_FILE"
}

log_error() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${RESET} [${ts}] ${msg}" >&2
    [[ -n "$OUTPUT_FILE" ]] && echo "[ERROR] [${ts}] ${msg}" >> "$OUTPUT_FILE"
}

create_demo_log() {
    log_info "Creating sample test log at: $LOG_TARGET"
    mkdir -p "$(dirname "$LOG_TARGET")" 2>/dev/null || true
    cat > "$LOG_TARGET" <<EOF
$(date) INFO  nginx: GET /api/users 200 OK
$(date) WARN  database: Slow query 3200ms
$(date) ERROR nginx: Connection refused on port 3000
$(date) INFO  app: User admin logged in
$(date) CRITICAL systemd: app.service failed
$(date) ERROR disk: I/O error on /dev/sda1
$(date) INFO  cron: Backup started
$(date) FATAL app: Cannot connect to Redis
$(date) WARN  ssl: Certificate expires in 14 days
$(date) ERROR database: Max connections reached
EOF
    log_info "Demo log initialized."
}

analyze() {
    mkdir -p "$REPORT_DIR"
    local REPORT="$REPORT_DIR/report_$(date '+%Y%m%d_%H%M%S').txt"

    log_info "Starting pattern analysis for: $LOG_TARGET"

    local TOTAL ERRORS WARNS
    TOTAL=$(wc -l < "$LOG_TARGET")
    ERRORS=$(grep -icE "error|critical|fatal|failed" "$LOG_TARGET" 2>/dev/null || true)
    ERRORS=${ERRORS:-0}
    WARNS=$(grep -ic "warn" "$LOG_TARGET" 2>/dev/null || true)
    WARNS=${WARNS:-0}

    {
        echo "=============================="
        echo "  LOG ANALYSIS REPORT"
        echo "  File  : $LOG_TARGET"
        echo "  Date  : $(date)"
        echo "=============================="
        echo ""
        printf "  %-20s : %d\n" "Total Lines"   "$TOTAL"
        printf "  %-20s : %d\n" "Errors Found"  "$ERRORS"
        printf "  %-20s : %d\n" "Warnings Found" "$WARNS"
        echo ""
        echo "  --- Keyword Counts ---"
        for KW in "${KEYWORDS[@]}"; do
            local COUNT
            COUNT=$(grep -ic "$KW" "$LOG_TARGET" 2>/dev/null || true)
            COUNT=${COUNT:-0}
            printf "  %-12s : %d\n" "$KW" "$COUNT"
        done
        echo ""
        echo "  --- Error Lines ---"
        grep -iE "error|critical|fatal|failed" "$LOG_TARGET" 2>/dev/null \
            | awk '{print NR". "$0}' || echo "  None found."
        echo ""
        echo "=============================="
    } | tee "$REPORT"

    log_info "Log analysis complete: ${TOTAL} lines examined, ${ERRORS} errors, ${WARNS} warnings."
    log_info "Detailed report saved to: $REPORT"

    if [[ -n "$OUTPUT_FILE" ]]; then
        cat "$REPORT" >> "$OUTPUT_FILE"
    fi
}

watch_live() {
    log_info "Streaming log file: $LOG_TARGET (Ctrl+C to stop)"
    tail -f "$LOG_TARGET" 2>/dev/null | sed \
        -e "s/ERROR/${RED}ERROR${RESET}/g" \
        -e "s/CRITICAL/${RED}CRITICAL${RESET}/g" \
        -e "s/FATAL/${RED}FATAL${RESET}/g" \
        -e "s/WARN/${YELLOW}WARN${RESET}/g" \
        -e "s/INFO/${GREEN}INFO${RESET}/g"
}

menu() {
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}=== Log Monitor Menu ===${RESET}"
        echo "  1) Analyze log"
        echo "  2) Watch log live"
        echo "  3) Show last 20 lines"
        echo "  4) Exit"
        echo -n "  Choice [1-4]: "
        if ! read -r CHOICE; then
            break
        fi

        case "$CHOICE" in
            1) analyze ;;
            2) watch_live ;;
            3)
                echo ""
                tail -n 20 "$LOG_TARGET"
                ;;
            4)
                log_info "Exiting log monitor."
                break
                ;;
            *)
                log_warn "Invalid selection: $CHOICE"
                ;;
        esac
    done
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                LOG_TARGET="$2"
                shift 2
                ;;
            -a|--analyze)
                MODE="analyze"
                shift
                ;;
            -o|--output|--log-file)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [LOG_FILE]"
                echo "Options:"
                echo "  -f, --file FILE                      Target log file to monitor"
                echo "  -a, --analyze                        Run non-interactive analysis directly"
                echo "  -o, --output FILE, --log-file FILE   Write output analysis log to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    LOG_TARGET="$1"
                    shift
                else
                    log_error "Unknown option: $1"
                    exit 1
                fi
                ;;
        esac
    done
}

print_header() {
    echo -e "${BOLD}${GREEN}=== Log Monitor Script ===${RESET}\n"
    log_info "Target file: $LOG_TARGET"
    [[ -n "$OUTPUT_FILE" ]] && log_info "Output log : $OUTPUT_FILE"
}

main() {
    parse_args "$@"

    if [[ -n "$OUTPUT_FILE" ]]; then
        mkdir -p "$(dirname "$OUTPUT_FILE")" 2>/dev/null || true
        : > "$OUTPUT_FILE"
    fi

    print_header

    if [[ ! -f "$LOG_TARGET" ]]; then
        create_demo_log
    fi

    if [[ "$MODE" == "analyze" ]] || [[ ! -t 0 ]]; then
        analyze
    else
        menu
    fi
}

main "$@"
