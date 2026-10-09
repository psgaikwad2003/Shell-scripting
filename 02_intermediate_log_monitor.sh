#!/usr/bin/env bash
# =============================================================================
# Script: 02_intermediate_log_monitor.sh
# Problem Statement: Continuously monitor system log files in real-time, detecting critical error keywords and sending instant alerts.
# =============================================================================

set -euo pipefail

WATCH_LOG="/var/log/syslog"
REPORT_DIR="./log_reports"
MAX_LOG_SIZE_MB=50
ALERT_KEYWORDS=("ERROR" "CRITICAL" "FATAL" "FAILED" "panic" "OOM")
SCRIPT_LOG="./monitor_activity.log"
LOG_FILE="${REPORT_LOG_FILE:-}"
MODE="menu"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BLUE="\033[0;34m"
BOLD="\033[1m"
RESET="\033[0m"

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${RESET} [${ts}] ${msg}"
    echo "[INFO] [${ts}] ${msg}" >> "$SCRIPT_LOG" 2>/dev/null || true
    [[ -n "$LOG_FILE" ]] && echo "[INFO] [${ts}] ${msg}" >> "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${RESET} [${ts}] ${msg}"
    echo "[WARN] [${ts}] ${msg}" >> "$SCRIPT_LOG" 2>/dev/null || true
    [[ -n "$LOG_FILE" ]] && echo "[WARN] [${ts}] ${msg}" >> "$LOG_FILE"
}

log_error() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${RESET} [${ts}] ${msg}" >&2
    echo "[ERROR] [${ts}] ${msg}" >> "$SCRIPT_LOG" 2>/dev/null || true
    [[ -n "$LOG_FILE" ]] && echo "[ERROR] [${ts}] ${msg}" >> "$LOG_FILE"
}

write_log() {
    local level="$1"
    local msg="$2"
    case "$level" in
        ERROR|CRITICAL|FATAL) log_error "$msg" ;;
        WARN|WARNING) log_warn "$msg" ;;
        *) log_info "$msg" ;;
    esac
}

cleanup() {
    echo ""
    log_info "Script exiting. Stopping background tasks."
    jobs -p | xargs -r kill 2>/dev/null || true
    echo -e "${CYAN}Cleanup completed.${RESET}"
}

trap cleanup EXIT INT TERM

generate_demo_log() {
    log_info "Generating synthetic demo log: $WATCH_LOG"

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

    : > "$WATCH_LOG"
    for LINE in "${LOG_LINES[@]}"; do
        echo "$(date '+%b %d %H:%M:%S') $(hostname) ${LINE}" >> "$WATCH_LOG"
    done

    log_info "Demo log created with ${#LOG_LINES[@]} entries."
}

validate_inputs() {
    log_info "Validating monitor environment and dependencies..."

    if [[ ! -f "$WATCH_LOG" ]]; then
        log_warn "Target log file not found: $WATCH_LOG"
        WATCH_LOG="./demo_app.log"
        mkdir -p "$(dirname "$WATCH_LOG")" 2>/dev/null || true
        generate_demo_log
    fi

    local REQUIRED_TOOLS=("grep" "awk" "sed" "wc" "du" "tail")
    for TOOL in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$TOOL" &>/dev/null; then
            log_error "Required tool not found: $TOOL"
            exit 1
        fi
    done

    log_info "Environment validated successfully."
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
    log_warn "Log size exceeds threshold (${MAX_LOG_SIZE_MB}MB). Rotating to: $ARCHIVE_NAME"

    mv "$WATCH_LOG" "$ARCHIVE_NAME"
    touch "$WATCH_LOG"
    gzip "$ARCHIVE_NAME" &
    local GZIP_PID=$!
    disown "$GZIP_PID" 2>/dev/null || true

    log_info "Rotation complete. Compressing archive in background (PID: ${GZIP_PID})."
}

analyze_log() {
    mkdir -p "$REPORT_DIR"
    local REPORT="${REPORT_DIR}/report_$(date '+%Y%m%d_%H%M%S').txt"
    local TOTAL_LINES ERROR_COUNT WARN_COUNT

    log_info "Starting log analysis on: $WATCH_LOG"

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
        echo "  KEYWORD BREAKDOWN"
        echo "  -----------------"
        for KEYWORD in "${ALERT_KEYWORDS[@]}"; do
            local COUNT
            COUNT=$(grep -i "$KEYWORD" "$WATCH_LOG" 2>/dev/null | wc -l | tr -d ' ') || true
            COUNT=${COUNT:-0}
            printf "  %-12s : %d occurrences\n" "$KEYWORD" "$COUNT"
        done
        echo ""
        echo "  ALL ERROR/CRITICAL LINES"
        echo "  ------------------------"
        grep -iE "error|critical|fatal|failed|panic|oom" "$WATCH_LOG" 2>/dev/null \
            | awk '{print NR". "$0}' || echo "  None found."
        echo ""
        echo "  TOP 5 LOG SOURCES"
        echo "  -----------------"
        awk '{print $4}' "$WATCH_LOG" 2>/dev/null \
            | sort \
            | uniq -c \
            | sort -rn \
            | head -5 \
            | awk '{printf "  %-5s hits : %s\n", $1, $2}' || true
        echo ""
        echo "  END OF REPORT"
        echo "========================================================"
    } > "$REPORT"

    log_info "Analysis complete. Total: ${TOTAL_LINES}, Errors: ${ERROR_COUNT}, Warnings: ${WARN_COUNT}."
    log_info "Detailed report saved to: ${REPORT}"

    if [[ -n "$LOG_FILE" ]]; then
        cat "$REPORT" >> "$LOG_FILE"
    fi
}

live_tail() {
    log_info "Initiating live stream monitoring on: ${WATCH_LOG}"
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

        if ! read -r CHOICE; then
            break
        fi

        case "$CHOICE" in
            1) analyze_log ;;
            2) live_tail ;;
            3)
                if check_log_size; then
                    rotate_log
                else
                    local SIZE
                    SIZE=$(du -m "$WATCH_LOG" | awk '{print $1}')
                    log_info "Log size within limits: ${SIZE}MB (limit: ${MAX_LOG_SIZE_MB}MB)"
                fi
                ;;
            4)
                echo ""
                echo -e "${CYAN}Last 20 lines of ${WATCH_LOG}:${RESET}"
                echo "──────────────────────────────────────────"
                tail -n 20 "$WATCH_LOG"
                ;;
            5)
                log_info "User requested exit."
                break
                ;;
            *)
                log_warn "Invalid option '$CHOICE'. Select 1-5."
                ;;
        esac
    done
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                WATCH_LOG="$2"
                shift 2
                ;;
            -a|--analyze)
                MODE="analyze"
                shift
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [LOG_FILE]"
                echo "Options:"
                echo "  -f, --file FILE                      Log file path to monitor"
                echo "  -a, --analyze                        Run non-interactive audit analysis directly"
                echo "  -o, --output FILE, --log-file FILE   Write monitoring metrics and output to log file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    WATCH_LOG="$1"
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
    echo -e "${BOLD}${GREEN}"
    echo "  ╔════════════════════════════════════════════════╗"
    echo "  ║   🔍  Intermediate Log Monitor Script v1.0    ║"
    echo "  ╚════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target: $LOG_FILE"
}

main() {
    parse_args "$@"

    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        : > "$LOG_FILE"
    fi

    print_header
    validate_inputs

    if [[ "$MODE" == "analyze" ]] || [[ ! -t 0 ]]; then
        analyze_log
    else
        show_menu
    fi
}

main "$@"
