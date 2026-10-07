#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 02_intermediate_log_monitor.sh
#  LEVEL  : Intermediate
#  PURPOSE: Monitor a log file for errors, send alerts, and auto-rotate it
#  USAGE  : bash 02_intermediate_log_monitor.sh [/path/to/file.log]
#
#  CONCEPTS COVERED:
#    - Functions with return values
#    - Loops (for, while)
#    - Arrays
#    - String manipulation (grep, awk, sed, cut)
#    - Exit codes & error handling (trap)
#    - Process management (background jobs)
#    - Regular expressions
#    - Argument parsing ($1, $#)
#    - File size checks & log rotation
#    - Writing logs with timestamps
# =============================================================================

set -euo pipefail

# Enhanced ISO-8601 logging timestamp prefix helper
timestamp_prefix() {
    printf "[%s]" "$(date --iso-8601=seconds 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')"
}
# set -e  → exit immediately on any error
# set -u  → treat unset variables as errors
# set -o pipefail → catch errors inside pipes

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIGURATION  (change these to fit your environment)
# ─────────────────────────────────────────────────────────────────────────────

WATCH_LOG="${1:-/var/log/syslog}"     # File to monitor (default: syslog)
REPORT_DIR="./log_reports"            # Directory to store analysis reports
MAX_LOG_SIZE_MB=50                    # Rotate log if bigger than this
ALERT_KEYWORDS=("ERROR" "CRITICAL" "FATAL" "FAILED" "panic" "OOM")
SCRIPT_LOG="./monitor_activity.log"  # This script's own log

# ─────────────────────────────────────────────────────────────────────────────
#  COLOUR CODES
# ─────────────────────────────────────────────────────────────────────────────

RED="\033[0;31m";    GREEN="\033[0;32m";   YELLOW="\033[1;33m"
CYAN="\033[0;36m";   BLUE="\033[0;34m";    BOLD="\033[1m";   RESET="\033[0m"

# ─────────────────────────────────────────────────────────────────────────────
#  LOGGING FUNCTION  — writes to terminal AND to a log file with timestamps
# ─────────────────────────────────────────────────────────────────────────────

# This function uses local variables (scoped only inside the function)
# and appends structured entries to SCRIPT_LOG.

write_log() {
    local LEVEL="$1"         # INFO / WARN / ERROR
    local MESSAGE="$2"
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Tee writes to both stdout and the file at the same time
    echo "[${TIMESTAMP}] [${LEVEL}] ${MESSAGE}" | tee -a "$SCRIPT_LOG"
}

# ─────────────────────────────────────────────────────────────────────────────
#  TRAP — run cleanup when the script exits (even on Ctrl+C or errors)
# ─────────────────────────────────────────────────────────────────────────────
# 'trap' catches signals:
#   EXIT  → always runs when the script ends
#   INT   → Ctrl+C
#   TERM  → kill command

cleanup() {
    echo ""
    write_log "INFO" "Script exiting. All background jobs will be stopped."
    # Kill all background jobs started by this script
    jobs -p | xargs -r kill 2>/dev/null || true
    echo -e "${CYAN}Cleanup done. Goodbye!${RESET}"
}

trap cleanup EXIT INT TERM

# ─────────────────────────────────────────────────────────────────────────────
#  FUNCTION: validate_inputs
#  Checks that required files/tools exist before we start
# ─────────────────────────────────────────────────────────────────────────────

validate_inputs() {
    write_log "INFO" "Validating inputs..."

    # Check if the log file exists
    # [[ -f file ]]  → true if file exists and is a regular file
    if [[ ! -f "$WATCH_LOG" ]]; then
        write_log "ERROR" "Log file not found: $WATCH_LOG"
        echo -e "${RED}Creating a demo log file for practice...${RESET}"

        # Create a sample log file with realistic entries for demo purposes
        mkdir -p "$(dirname "$WATCH_LOG")" 2>/dev/null || true
        WATCH_LOG="./demo_app.log"
        generate_demo_log
    fi

    # Check required tools using a for loop over an array
    local REQUIRED_TOOLS=("grep" "awk" "sed" "wc" "du" "tail")

    for TOOL in "${REQUIRED_TOOLS[@]}"; do     # Loop through each item in array
        if ! command -v "$TOOL" &>/dev/null; then
            write_log "ERROR" "Required tool not found: $TOOL"
            exit 1
        fi
    done

    write_log "INFO" "All inputs validated successfully."
}

# ─────────────────────────────────────────────────────────────────────────────
#  FUNCTION: generate_demo_log
#  Creates a realistic fake log file for users who don't have /var/log/syslog
# ─────────────────────────────────────────────────────────────────────────────

generate_demo_log() {
    write_log "INFO" "Generating demo log: $WATCH_LOG"

    # An array of realistic log lines
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

    # Write each log line with a simulated timestamp
    # 'printf' formats time, then we redirect to file
    > "$WATCH_LOG"    # clear/create the file
    for LINE in "${LOG_LINES[@]}"; do
        echo "$(date '+%b %d %H:%M:%S') $(hostname) ${LINE}" >> "$WATCH_LOG"
        sleep 0.05    # tiny delay to make timestamps slightly different
    done

    write_log "INFO" "Demo log created with ${#LOG_LINES[@]} entries."   # ${#array[@]} = array length
}

# ─────────────────────────────────────────────────────────────────────────────
#  FUNCTION: check_log_size
#  Returns 0 (true) if log needs rotation, 1 (false) if it's fine
# ─────────────────────────────────────────────────────────────────────────────

check_log_size() {
    # du -m gives size in Megabytes; awk extracts first column (the number)
    local SIZE_MB
    SIZE_MB=$(du -m "$WATCH_LOG" 2>/dev/null | awk '{print $1}')

    if [[ "$SIZE_MB" -ge "$MAX_LOG_SIZE_MB" ]]; then
        return 0    # 0 = success/true in bash (counterintuitive but standard!)
    else
        return 1    # 1 = false
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  FUNCTION: rotate_log
#  Renames the log and creates a fresh one
# ─────────────────────────────────────────────────────────────────────────────

rotate_log() {
    local ARCHIVE_NAME="${WATCH_LOG}.$(date '+%Y%m%d_%H%M%S').bak"
    write_log "WARN" "Log file is large. Rotating to: $ARCHIVE_NAME"

    mv "$WATCH_LOG" "$ARCHIVE_NAME"
    touch "$WATCH_LOG"    # create fresh empty log
    gzip "$ARCHIVE_NAME" &    # compress in the background (&)
    local GZIP_PID=$!
    disown "$GZIP_PID" 2>/dev/null || true   # detach so the EXIT trap won't kill it

    write_log "INFO" "Rotation complete. Compressing old log in background (PID: ${GZIP_PID})."
    # $! holds the PID of the last background command
}

# ─────────────────────────────────────────────────────────────────────────────
#  FUNCTION: analyze_log
#  Core analysis: counts errors, extracts patterns, builds report
# ─────────────────────────────────────────────────────────────────────────────

analyze_log() {
    mkdir -p "$REPORT_DIR"
    local REPORT="${REPORT_DIR}/report_$(date '+%Y%m%d_%H%M%S').txt"
    local TOTAL_LINES ERROR_COUNT WARN_COUNT

    write_log "INFO" "Starting analysis of: $WATCH_LOG"

    # wc -l counts lines; awk/tr strip whitespace
    TOTAL_LINES=$(wc -l < "$WATCH_LOG")

    # grep -c counts matching lines (-i = case insensitive)
    # Use '|| true' so grep exit-1 (no match) does not abort the script
    # under 'set -e'. Default to 0 when the result is empty.
    ERROR_COUNT=$(grep -icE "error|critical|fatal|failed|panic|oom" "$WATCH_LOG" 2>/dev/null || true)
    ERROR_COUNT=${ERROR_COUNT:-0}
    WARN_COUNT=$(grep -ic "warn" "$WATCH_LOG" 2>/dev/null || true)
    WARN_COUNT=${WARN_COUNT:-0}

    # ── Write report header ──
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

    # ── Loop through each keyword and find matches ──
    echo "  KEYWORD BREAKDOWN" >> "$REPORT"
    echo "  -----------------" >> "$REPORT"

    for KEYWORD in "${ALERT_KEYWORDS[@]}"; do    # iterate over the config array
        # grep -i ignores case; wc -l counts; tr removes whitespace
        local COUNT
        COUNT=$(grep -i "$KEYWORD" "$WATCH_LOG" 2>/dev/null | wc -l | tr -d ' ') || true
        COUNT=${COUNT:-0}
        printf "  %-12s : %d occurrences\n" "$KEYWORD" "$COUNT" >> "$REPORT"
    done

    echo "" >> "$REPORT"

    # ── Extract all ERROR lines using grep + awk ──
    echo "  ALL ERROR/CRITICAL LINES" >> "$REPORT"
    echo "  ------------------------" >> "$REPORT"

    # grep -iE uses extended regex; we pipe result into awk to add line numbers
    grep -iE "error|critical|fatal|failed|panic|oom" "$WATCH_LOG" 2>/dev/null \
        | awk '{print NR". "$0}' \
        >> "$REPORT" || echo "  None found." >> "$REPORT"

    echo "" >> "$REPORT"

    # ── Find top 5 most common log sources using awk + sort ──
    echo "  TOP 5 LOG SOURCES (by 4th field)" >> "$REPORT"
    echo "  ---------------------------------" >> "$REPORT"

    # awk prints the 4th column; sort counts and sorts unique values
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

    # ── Print summary to terminal ──
    echo ""
    echo -e "${BOLD}${CYAN}📊  ANALYSIS COMPLETE${RESET}"
    echo -e "  Total Lines  : ${BOLD}${TOTAL_LINES}${RESET}"

    # Colour the error count: red if >0, green if clean
    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        echo -e "  Errors Found : ${RED}${BOLD}${ERROR_COUNT}${RESET}"
    else
        echo -e "  Errors Found : ${GREEN}${BOLD}0 — All clean!${RESET}"
    fi

    echo -e "  Warnings     : ${YELLOW}${WARN_COUNT}${RESET}"
    echo -e "  Report saved : ${CYAN}${REPORT}${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
#  FUNCTION: live_tail
#  Watches the log in real-time and highlights keywords as they appear
# ─────────────────────────────────────────────────────────────────────────────

live_tail() {
    echo -e "\n${BOLD}${CYAN}👁  Live Log Watch${RESET} — ${WATCH_LOG}"
    echo -e "${YELLOW}  Press Ctrl+C to stop watching.${RESET}\n"

    # 'tail -f' follows the file as new lines are added
    # We pipe it through 'sed' to colour keywords in real-time
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

# ─────────────────────────────────────────────────────────────────────────────
#  FUNCTION: show_menu
#  Interactive menu using a while loop + case statement
# ─────────────────────────────────────────────────────────────────────────────

show_menu() {
    while true; do    # infinite loop — only breaks when user chooses Exit
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

        read -r CHOICE    # read user's input into CHOICE variable

        # case statement — like a switch in Python/Java
        case "$CHOICE" in
            1)
                analyze_log
                ;;
            2)
                live_tail
                ;;
            3)
                if check_log_size; then    # if function returns 0 (true)
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
                break    # exit the while loop
                ;;
            *)
                # * matches anything else
                echo -e "${RED}  Invalid option '$CHOICE'. Please choose 1-5.${RESET}"
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
#  MAIN — entry point of the script
# ─────────────────────────────────────────────────────────────────────────────

main() {
    clear
    echo -e "${BOLD}${GREEN}"
    echo "  ╔════════════════════════════════════════════════╗"
    echo "  ║   🔍  Intermediate Log Monitor Script v1.0    ║"
    echo "  ╚════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    # $# = number of arguments passed to the script
    if [[ $# -gt 0 ]]; then
        write_log "INFO" "Custom log file provided: $1"
    else
        write_log "INFO" "No log file specified. Using default: $WATCH_LOG"
    fi

    validate_inputs   # always validate before doing any real work
    show_menu         # start the interactive menu
}

# Call main and pass all script arguments to it
# "$@" expands to all positional arguments, properly quoted
main "$@"
