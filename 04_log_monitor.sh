#!/usr/bin/env bash
# Log Monitor Script — Intermediate Level

set -euo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"
CYAN="\033[0;36m"; BOLD="\033[1m"; RESET="\033[0m"

LOG_FILE="${1:-./demo.log}"
REPORT_DIR="./reports"
KEYWORDS=("ERROR" "CRITICAL" "FATAL" "FAILED" "WARN")

# Create a demo log if none is given
create_demo_log() {
  cat > "$LOG_FILE" <<EOF
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
  echo -e "${GREEN}Demo log created: $LOG_FILE${RESET}"
}

# Analyze the log file
analyze() {
  mkdir -p "$REPORT_DIR"
  REPORT="$REPORT_DIR/report_$(date '+%Y%m%d_%H%M%S').txt"

  TOTAL=$(wc -l < "$LOG_FILE")
  ERRORS=$(grep -icE "error|critical|fatal|failed" "$LOG_FILE" 2>/dev/null || echo 0)
  WARNS=$(grep -ic "warn" "$LOG_FILE" 2>/dev/null || echo 0)

  {
    echo "=============================="
    echo "  LOG ANALYSIS REPORT"
    echo "  File  : $LOG_FILE"
    echo "  Date  : $(date)"
    echo "=============================="
    echo ""
    printf "  %-20s : %d\n" "Total Lines"   "$TOTAL"
    printf "  %-20s : %d\n" "Errors Found"  "$ERRORS"
    printf "  %-20s : %d\n" "Warnings Found" "$WARNS"
    echo ""
    echo "  --- Keyword Counts ---"
    for KW in "${KEYWORDS[@]}"; do
      COUNT=$(grep -ic "$KW" "$LOG_FILE" 2>/dev/null || echo 0)
      printf "  %-12s : %d\n" "$KW" "$COUNT"
    done
    echo ""
    echo "  --- Error Lines ---"
    grep -iE "error|critical|fatal|failed" "$LOG_FILE" 2>/dev/null \
      | awk '{print NR". "$0}' || echo "  None found."
    echo ""
    echo "=============================="
  } | tee "$REPORT"

  echo -e "\n${CYAN}Report saved: $REPORT${RESET}"
}

# Watch the log live and highlight keywords
watch_live() {
  echo -e "${CYAN}Watching: $LOG_FILE  (Ctrl+C to stop)${RESET}\n"
  tail -f "$LOG_FILE" | sed \
    -e "s/ERROR/${RED}ERROR${RESET}/gI" \
    -e "s/CRITICAL/${RED}CRITICAL${RESET}/gI" \
    -e "s/FATAL/${RED}FATAL${RESET}/gI" \
    -e "s/WARN/${YELLOW}WARN${RESET}/gI" \
    -e "s/INFO/${GREEN}INFO${RESET}/gI"
}

# Interactive menu
menu() {
  while true; do
    echo ""
    echo -e "${BOLD}${CYAN}=== Log Monitor Menu ===${RESET}"
    echo "  1) Analyze log"
    echo "  2) Watch log live"
    echo "  3) Show last 20 lines"
    echo "  4) Exit"
    echo -n "  Choice [1-4]: "
    read -r CHOICE

    case "$CHOICE" in
      1) analyze ;;
      2) watch_live ;;
      3) echo ""; tail -20 "$LOG_FILE" ;;
      4) echo -e "${GREEN}Bye!${RESET}"; break ;;
      *) echo -e "${RED}Invalid option.${RESET}" ;;
    esac
  done
}

# Entry point
clear
echo -e "${BOLD}${GREEN}=== Log Monitor Script ===${RESET}\n"

[ ! -f "$LOG_FILE" ] && create_demo_log

echo -e "Log file: ${YELLOW}$LOG_FILE${RESET}"
menu
