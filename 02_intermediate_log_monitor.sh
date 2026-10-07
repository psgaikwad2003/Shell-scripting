#!/usr/bin/env bash
# =============================================================================
# Script: 02_intermediate_log_monitor.sh
# Problem Statement: Continuously monitor system log files in real-time, detecting critical error keywords and sending instant alerts.
# =============================================================================

set -euo pipefail

timestamp_prefix() {
    printf "[%s]" "$(date --iso-8601=seconds 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')"
}

WATCH_LOG="${1:-/var/log/syslog}"
REPORT_DIR="./log_reports"
MAX_LOG_SIZE_MB=50
ALERT_KEYWORDS=("ERROR" "CRITICAL" "FATAL" "FAILED" "panic" "OOM")
SCRIPT_LOG="./monitor_activity.log"

RED="\033[0;31m";    GREEN="\033[0;32m";   YELLOW="\033[1;33m"
CYAN="\033[0;36m";   BLUE="\033[0;34m";    BOLD="\033[1m";   RESET="\033[0m"

write_log() {
    local LEVEL="$1"
    local MESSAGE="$2"
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${TIMESTAMP}] [${LEVEL}] ${MESSAGE}" | tee -a "$SCRIPT_LOG"
}

cleanup() {
    echo ""
    write_log "INFO" "Script exiting. All background jobs will be stopped."
    jobs -p | xargs -r kill 2>/dev/null || true
    echo -e "${CYAN}Cleanup done. Goodbye!${RESET}"
}

trap cleanup EXIT INT TERM

validate_inputs() {
    write_log "INFO" "Validating inputs..."

    if [[ ! -f "$WATCH_LOG" ]]; then
        write_log "ERROR" "Log file not found: $WATCH_LOG"
        echo -e "${RED}Creating a demo log file for practice...${RESET}"

        mkdir -p "$(dirname "$WATCH_LOG")" 2>/dev/null || true
        WATCH_LOG="./demo_app.log"
        generate_demo_log
    fi

    local REQUIRED_TOOLS=("grep" "awk" "sed" "wc" "du" "tail")

    for TOOL in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$TOOL" &>/dev/null; then
            write_log "ERROR" "Required tool not found: $TOOL"
            exit 1
        fi
    done

    write_log "INFO" "All inputs validated successfully."
}

generate_demo_log() {
    write_log "INFO" "Generating demo log: $WATCH_LOG"

    local LOG_LINES=(
        "INFO  nginx: Request GET /api/users 200 OK in 45ms"
        "INFO  nginx: Request POST /api/login 200 OK in 102ms"
        "WARN  database: Slow query detected — took 3200ms"
        "ERROR nginx: Connection refused to backend on port 3000"
        "INFO  app: User 'admin' logged in from 192.168.1.10"
        "CRITICAL systemd: Service 'app.service' failed. Restarting..."
        "ERROR disk: /dev/sda1 filesystem error — I/O error on block 4829"
        "INFO  cron: Backup job started at 02:00"
        "FAILED auth: SSH login attempt from 45.33.32.156 — blocked"
        "INFO  app: Cache cleared successfully"
        "WARN  memory: Available memory below 200MB"
        "ERROR app: Unhandled exception in /api/orders — NullPointerException"
        "INFO  nginx: Request GET /health 200 OK in 2ms"
        "OOM   kernel: Out of memory: Killing process 4521 (node) score 890"
        "INFO  cron: Backup completed — 2.3GB archived"
        "ERROR database: Max connection pool reached (100/100)"
        "WARN  ssl: Certificate expires in 14 days for domain example.com"
        "FATAL app: Cannot connect to Redis — restart required"
        "INFO  app: Graceful shutdown initiated"
        "panic kernel: BUG: unable to handle kernel paging request at ffffffff"
    )

    > "$WATCH_LOG"
    for LINE in "${LOG_LINES[@]}"; do
        echo "$(date '+%b %d %H:%M:%S') $(hostname) ${LINE}" >> "$WATCH_LOG"
        sleep 0.05
    done

    write_log "INFO" "Demo log created with ${#LOG_LINES[@]} entries."
}

check_log_size() {
    local SIZE_MB
    SIZE_MB=$(du -m "$WATCH_LOG" 2>/dev/null | awk '{print $1}')

    if [[ "$SIZE_MB" -ge "$MAX_LOG_SIZE_MB" ]]; then
        return 0
    else
        return 1
    fi
}

rotate_log() {
    local ARCHIVE_NAME="${WATCH_LOG}.$(date '+%Y%m%d_%H%M%S').bak"
    write_log "WARN" "Log file is large. Rotating to: $ARCHIVE_NAME"

    mv "$WATCH_LOG" "$ARCHIVE_NAME"
    touch "$WATCH_LOG"
    gzip "$ARCHIVE_NAME" &
    local GZIP_PID=$!
    disown "$GZIP_PID" 2>/dev/null || true

    write_log "INFO" "Rotation complete. Compressing old log in background (PID: ${GZIP_PID})."
}

analyze_log() {
    mkdir -p "$REPORT_DIR"
    local REPORT="${REPORT_DIR}/report_$(date '+%Y%m%d_%H%M%S').txt"
    local TOTAL_LINES ERROR_COUNT WARN_COUNT

    write_log "INFO" "Starting analysis of: $WATCH_LOG"

    TOTAL_LINES=$(wc -l < "$WATCH_LOG")

    ERROR_COUNT=$(grep -icE "error|critical|fatal|failed|panic|oom" "$WATCH_LOG" 2>/dev/null || true)
    ERROR_COUNT=${ERROR_COUNT:-0}
    WARN_COUNT=$(grep -ic "warn" "$WATCH_LOG" 2>/dev/null || true)
    WARN_COUNT=${WARN_COUNT:-0}

    {
        echo "========================================================"
        echo "  LOG ANALYSIS REPORT"
        echo "  File    : $WATCH_LOG"
        echo "  Date    : $(date '+%A, %d %B %Y — %H:%M:%S')"
        echo "========================================================"
        echo ""
        echo "  SUMMARY"
        echo "  -------"
        printf "  %-25s : %d\n" "Total log lines"   "$TOTAL_LINES"
        printf "  %-25s : %d\n" "Error/Critical lines" "$ERROR_COUNT"
        printf "  %-25s : %d\n" "Warning lines"     "$WARN_COUNT"
        echo ""
    } > "$REPORT"

    echo "  KEYWORD BREAKDOWN" >> "$REPORT"
    echo "  -----------------" >> "$REPORT"

    for KEYWORD in "${ALERT_KEYWORDS[@]}"; do
        local COUNT
        COUNT=$(grep -i "$KEYWORD" "$WATCH_LOG" 2>/dev/null | wc -l | tr -d ' ') || true
        COUNT=${COUNT:-0}
        printf "  %-12s : %d occurrences\n" "$KEYWORD" "$COUNT" >> "$REPORT"
    done

    echo "" >> "$REPORT"

    echo "  ALL ERROR/CRITICAL LINES" >> "$REPORT"
    echo "  ------------------------" >> "$REPORT"

    grep -iE "error|critical|fatal|failed|panic|oom" "$WATCH_LOG" 2>/dev/null \
        | awk '{print NR". "$0}' \
        >> "$REPORT" || echo "  None found." >> "$REPORT"

    echo "" >> "$REPORT"

    echo "  TOP 5 LOG SOURCES (by 4th field)" >> "$REPORT"
    echo "  ---------------------------------" >> "$REPORT"

    awk '{print $4}' "$WATCH_LOG" \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -5 \
        | awk '{printf "  %-5s hits : %s\n", $1, $2}' \
        >> "$REPORT"

    echo "" >> "$REPORT"
    echo "  END OF REPORT" >> "$REPORT"
    echo "========================================================"  >> "$REPORT"

    echo ""
    echo -e "${BOLD}${CYAN}📊  ANALYSIS COMPLETE${RESET}"
    echo -e "  Total Lines  : ${BOLD}${TOTAL_LINES}${RESET}"

    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        echo -e "  Errors Found : ${RED}${BOLD}${ERROR_COUNT}${RESET}"
    else
        echo -e "  Errors Found : ${GREEN}${BOLD}0 — All clean!${RESET}"
    fi

    echo -e "  Warnings     : ${YELLOW}${WARN_COUNT}${RESET}"
    echo -e "  Report saved : ${CYAN}${REPORT}${RESET}"
}

live_tail() {
    echo -e "\n${BOLD}${CYAN}👁  Live Log Watch${RESET} — ${WATCH_LOG}"
    echo -e "${YELLOW}  Press Ctrl+C to stop watching.${RESET}\n"

    tail -f "$WATCH_LOG" 2>/dev/null | sed \
        -e "s/ERROR/${RED}ERROR${RESET}/gI" \
        -e "s/CRITICAL/${RED}CRITICAL${RESET}/gI" \
        -e "s/FATAL/${RED}FATAL${RESET}/gI" \
        -e "s/FAILED/${RED}FAILED${RESET}/gI" \
        -e "s/WARN/${YELLOW}WARN${RESET}/gI" \
        -e "s/INFO/${GREEN}INFO${RESET}/gI" \
        -e "s/panic/${RED}panic${RESET}/g" \
        -e "s/OOM/${RED}OOM${RESET}/gI"
}

show_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${BLUE}║    🔍  Log Monitor — Main Menu       ║${RESET}"
        echo -e "${BOLD}${BLUE}╠══════════════════════════════════════╣${RESET}"
        echo -e "${BOLD}${BLUE}║${RESET}  1) Analyze log file                 ${BOLD}${BLUE}║${RESET}"
        echo -e "${BOLD}${BLUE}║${RESET}  2) Watch log in real-time (live)    ${BOLD}${BLUE}║${RESET}"
        echo -e "${BOLD}${BLUE}║${RESET}  3) Check if log needs rotation      ${BOLD}${BLUE}║${RESET}"
        echo -e "${BOLD}${BLUE}║${RESET}  4) Show last 20 lines of log        ${BOLD}${BLUE}║${RESET}"
        echo -e "${BOLD}${BLUE}║${RESET}  5) Exit                             ${BOLD}${BLUE}║${RESET}"
        echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "${YELLOW}Watching: ${WATCH_LOG}${RESET}"
        echo -ne "  Enter your choice [1-5]: "

        read -r CHOICE

        case "$CHOICE" in
            1)
                analyze_log
                ;;
            2)
                live_tail
                ;;
            3)
                if check_log_size; then
                    echo -e "${RED}  Log is too large (>= ${MAX_LOG_SIZE_MB}MB). Rotating...${RESET}"
                    rotate_log
                else
                    SIZE=$(du -m "$WATCH_LOG" | awk '{print $1}')
                    echo -e "${GREEN}  Log size is fine: ${SIZE}MB (limit: ${MAX_LOG_SIZE_MB}MB)${RESET}"
                fi
                ;;
            4)
                echo ""
                echo -e "${CYAN}  Last 20 lines of ${WATCH_LOG}:${RESET}"
                echo "  ──────────────────────────────────────────"
                tail -n 20 "$WATCH_LOG"
                ;;
            5)
                write_log "INFO" "User chose to exit."
                break
                ;;
            *)
                echo -e "${RED}  Invalid option '$CHOICE'. Please choose 1-5.${RESET}"
                ;;
        esac
    done
}

main() {
    clear
    echo -e "${BOLD}${GREEN}"
    echo "  ╔════════════════════════════════════════════════╗"
    echo "  ║   🔍  Intermediate Log Monitor Script v1.0    ║"
    echo "  ╚════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    if [[ $# -gt 0 ]]; then
        write_log "INFO" "Custom log file provided: $1"
    else
        write_log "INFO" "No log file specified. Using default: $WATCH_LOG"
    fi

    validate_inputs
    show_menu
}

main "$@"
