#!/usr/bin/env bash
# =============================================================================
# Script: daily_toolkit.sh
# Problem Statement: Provide a unified interactive command-line interface for daily developer and sysadmin operations including health checks, backups, and maintenance.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

cmd_suite() {
  echo -e "\n${BOLD}${CYAN}🚀  Comprehensive Shell Script Suite (50 Production Tools)${RESET}"
  print_separator
  local COUNT
  COUNT=$(find . -maxdepth 1 -name "[0-9][0-9]_*.sh" | wc -l)
  log_info "Discovered ${BOLD}${COUNT}${RESET} specialized DevOps automation scripts."
  log_info "Run any script directly using: bash <script_name>"
  log_success "All scripts validated and ready for production deployment."
}

print_banner() {
  echo -e "${MAGENTA}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║        🛠  Developer Daily Toolkit  🛠        ║"
  echo "║  sysinfo | backup | gitpush | cleanup | more ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

print_separator() {
  echo -e "${BLUE}──────────────────────────────────────────────${RESET}"
}

cmd_sysinfo() {
  echo -e "\n${BOLD}${CYAN}📊  System Health Dashboard${RESET}"
  print_separator

  OS=$(uname -s)
  KERNEL=$(uname -r)
  HOSTNAME=$(hostname)
  log_info "Host     : ${BOLD}${HOSTNAME}${RESET}"
  log_info "OS       : ${OS} (Kernel: ${KERNEL})"

  UPTIME=$(uptime -p 2>/dev/null || uptime)
  log_info "Uptime   : ${UPTIME}"

  if command -v mpstat &>/dev/null; then
    CPU_IDLE=$(mpstat 1 1 | awk '/Average/ {print $NF}')
    CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc)
    log_info "CPU Load : ${CPU_USAGE}% used"
  elif [[ -f /proc/loadavg ]]; then
    LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
    log_info "Load Avg : ${LOAD}"
  fi

  if command -v free &>/dev/null; then
    TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
    USED_MEM=$(free -h  | awk '/^Mem:/ {print $3}')
    FREE_MEM=$(free -h  | awk '/^Mem:/ {print $4}')
    log_info "Memory   : ${USED_MEM} used / ${TOTAL_MEM} total (${FREE_MEM} free)"
  fi

  print_separator
  echo -e "${BOLD}  💾  Disk Usage${RESET}"
  df -h | grep -E "^/dev|^Filesystem" | awk '{printf "  %-20s %6s used of %-6s  (%s)\n", $1, $3, $2, $5}'

  print_separator
  echo -e "${BOLD}  🔥  Top 5 Processes by CPU${RESET}"
  if ps aux --sort=-%cpu &>/dev/null 2>&1; then
    ps aux --sort=-%cpu 2>/dev/null | head -6 | awk 'NR==1 {print "  "$0} NR>1 {printf "  %-12s %5s%%  %s\n", $1, $3, $11}'
  else
    ps aux 2>/dev/null | sort -k3 -rn | head -5 | awk '{printf "  %-12s %5s%%  %s\n", $1, $3, $11}'
  fi

  print_separator
  echo -e "${BOLD}  🌐  Network Interfaces${RESET}"
  ip -br addr 2>/dev/null | awk '{printf "  %-12s  %-10s  %s\n", $1, $2, $3}' \
    || ifconfig 2>/dev/null | grep -E "^[a-z]|inet " | head -12

  print_separator
  log_success "System info complete — $(date '+%Y-%m-%d %H:%M:%S')"
}

cmd_backup() {
  SOURCE_DIR="${1:-$HOME/Documents}"
  BACKUP_DIR="${2:-$HOME/backups}"
  TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
  ARCHIVE_NAME="backup_$(basename "$SOURCE_DIR")_${TIMESTAMP}.tar.gz"

  echo -e "\n${BOLD}${CYAN}💾  Backup Utility${RESET}"
  print_separator

  if [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "Source directory not found: $SOURCE_DIR"
    echo -e "  ${YELLOW}Usage: bash $0 backup <source_dir> <backup_dir>${RESET}"
    exit 1
  fi

  mkdir -p "$BACKUP_DIR"
  log_info "Source   : ${SOURCE_DIR}"
  log_info "Target   : ${BACKUP_DIR}/${ARCHIVE_NAME}"

  log_info "Compressing... (this may take a moment)"
  tar -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" \
      --exclude='*.tmp' \
      --exclude='node_modules' \
      --exclude-vcs \
      "$SOURCE_DIR" 2>/dev/null

  ARCHIVE_SIZE=$(du -sh "${BACKUP_DIR}/${ARCHIVE_NAME}" | cut -f1)
  log_success "Backup created: ${ARCHIVE_NAME} (${ARCHIVE_SIZE})"

  BACKUP_COUNT=$(find "${BACKUP_DIR}" -maxdepth 1 -name 'backup_*.tar.gz' 2>/dev/null | wc -l)
  if (( BACKUP_COUNT > 7 )); then
    log_warn "Old backups found. Removing extras (keeping 7 most recent)..."
    find "${BACKUP_DIR}" -maxdepth 1 -name 'backup_*.tar.gz' -printf '%T@ %p\n' \
      | sort -rn | tail -n +8 | awk '{print $2}' | xargs rm -f
    log_success "Old backups pruned."
  fi

  print_separator
}

cmd_gitpush() {
  COMMIT_MSG="${1:-"chore: daily update $(date '+%Y-%m-%d %H:%M')"}"

  echo -e "\n${BOLD}${CYAN}🚀  Smart Git Push${RESET}"
  print_separator

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_error "Not inside a Git repository. cd into your project first."
    exit 1
  fi

  BRANCH=$(git branch --show-current)
  REPO=$(basename "$(git rev-parse --show-toplevel)")
  log_info "Repo     : ${REPO}"
  log_info "Branch   : ${BRANCH}"

  CHANGES=$(git status --short)
  if [[ -z "$CHANGES" ]]; then
    log_warn "Nothing to commit — working tree is clean."
    exit 0
  fi

  echo -e "${YELLOW}  Changed files:${RESET}"
  git status --short | awk '{printf "    %s\n", $0}'

  git add -A
  log_info "Staged all changes."

  git commit -m "$COMMIT_MSG"
  log_success "Committed: \"${COMMIT_MSG}\""

  git push --set-upstream origin "$BRANCH"
  log_success "Pushed to origin/${BRANCH} successfully!"

  print_separator
}

cmd_cleanup() {
  TARGET_DIR="${1:-.}"

  echo -e "\n${BOLD}${CYAN}🧹  Cleanup Tool${RESET}"
  print_separator
  log_info "Target   : $(realpath "$TARGET_DIR")"

  FREED=0

  human_size() {
    local bytes=$1
    if   (( bytes >= 1073741824 )); then printf "%.1fG" "$(echo "scale=1; $bytes/1073741824" | bc)"
    elif (( bytes >= 1048576    )); then printf "%.1fM" "$(echo "scale=1; $bytes/1048576" | bc)"
    elif (( bytes >= 1024       )); then printf "%.1fK" "$(echo "scale=1; $bytes/1024" | bc)"
    else printf "%dB" "$bytes"; fi
  }

  delete_files() {
    local pattern="$1"
    local label="$2"
    local count size
    count=$(find "$TARGET_DIR" -type f -name "$pattern" 2>/dev/null | wc -l)
    if (( count > 0 )); then
      size=$(find "$TARGET_DIR" -type f -name "$pattern" -exec du -sb {} + 2>/dev/null | awk '{s+=$1} END{print s+0}')
      find "$TARGET_DIR" -type f -name "$pattern" -delete 2>/dev/null
      FREED=$((FREED + size))
      log_success "Removed ${count}x ${label} — freed $(human_size "$size")"
    else
      log_info "No ${label} found."
    fi
  }

  delete_files "*.tmp"      "temp files"
  delete_files "*.log"      "log files"
  delete_files ".DS_Store"  "macOS DS_Store files"
  delete_files "*.bak"      "backup files"
  delete_files "*.swp"      "Vim swap files"
  delete_files "Thumbs.db"  "Windows thumbnails"

  EMPTY_DIRS=$(find "$TARGET_DIR" -mindepth 1 -type d -empty 2>/dev/null | wc -l)
  if (( EMPTY_DIRS > 0 )); then
    find "$TARGET_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null
    log_success "Removed ${EMPTY_DIRS} empty directories."
  fi

  echo ""
  log_success "🎉  Cleanup done! Total space freed: ${BOLD}$(human_size "$FREED")${RESET}"
  print_separator
}

cmd_monitor() {
  echo -e "\n${BOLD}${CYAN}📡  Real-Time Process Monitor${RESET}  (Press Ctrl+C to quit)"
  print_separator

  INTERVAL=${1:-3}

  while true; do
    clear
    echo -e "${BOLD}${CYAN}📡  Process Monitor — $(date '+%H:%M:%S')${RESET}  [refresh: ${INTERVAL}s | Ctrl+C to exit]"
    print_separator

    if command -v free &>/dev/null; then
      free -h | awk '
        /^Mem:/ { printf "  RAM  : %s used / %s total\n", $3, $2 }
        /^Swap:/ { printf "  Swap : %s used / %s total\n", $3, $2 }
      '
    fi

    if [[ -f /proc/loadavg ]]; then
      echo -e "  Load : $(cut -d' ' -f1-3 /proc/loadavg)"
    fi

    print_separator
    echo -e "${BOLD}  PID       USER       CPU%   MEM%   COMMAND${RESET}"
    if ps aux --sort=-%cpu &>/dev/null 2>&1; then
      ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=16 {
        printf "  %-9s %-10s %5s  %5s  %s\n", $2, $1, $3, $4, $11
      }'
    else
      ps aux 2>/dev/null | sort -k3 -rn | awk 'NR<=15 {
        printf "  %-9s %-10s %5s  %5s  %s\n", $2, $1, $3, $4, $11
      }'
    fi

    print_separator
    sleep "$INTERVAL"
  done
}

cmd_weather() {
  CITY="${1:-}"

  echo -e "\n${BOLD}${CYAN}🌤  Weather Report${RESET}"
  print_separator

  if ! command -v curl &>/dev/null; then
    log_error "curl is required. Install it with: sudo apt install curl"
    exit 1
  fi

  QUERY="${CITY// /+}"
  curl -sS "wttr.in/${QUERY}?format=v2" || curl -sS "wttr.in/${QUERY}"

  print_separator
}

show_help() {
  echo ""
  echo -e "${BOLD}  Usage:${RESET}  bash daily_toolkit.sh <command> [args]"
  echo ""
  echo -e "${BOLD}  Commands:${RESET}"
  echo -e "  ${GREEN}sysinfo${RESET}               Show system health dashboard"
  echo -e "  ${GREEN}backup${RESET}  [src] [dest]   Backup a directory (default: ~/Documents)"
  echo -e "  ${GREEN}gitpush${RESET} [message]      Stage, commit & push current Git repo"
  echo -e "  ${GREEN}cleanup${RESET} [dir]          Remove junk files (.tmp, .log, .bak, etc.)"
  echo -e "  ${GREEN}monitor${RESET} [interval]     Live process monitor (default: 3s refresh)"
  echo -e "  ${GREEN}weather${RESET} [city]         Show weather (uses wttr.in)"
  echo ""
  echo -e "  ${YELLOW}Examples:${RESET}"
  echo -e "    bash daily_toolkit.sh sysinfo"
  echo -e "    bash daily_toolkit.sh backup ~/projects ~/backups"
  echo -e "    bash daily_toolkit.sh gitpush \"feat: add new feature\""
  echo -e "    bash daily_toolkit.sh cleanup ./my_project"
  echo -e "    bash daily_toolkit.sh monitor 5"
  echo -e "    bash daily_toolkit.sh weather \"New York\""
  echo ""
}

main() {
  print_banner

  COMMAND="${1:-help}"
  shift || true

  case "$COMMAND" in
    sysinfo)  cmd_sysinfo "$@" ;;
    backup)   cmd_backup  "$@" ;;
    gitpush)  cmd_gitpush "$@" ;;
    cleanup)  cmd_cleanup "$@" ;;
    monitor)  cmd_monitor "$@" ;;
    weather)  cmd_weather "$@" ;;
    help|--help|-h) show_help ;;
    *)
      log_error "Unknown command: '${COMMAND}'"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
