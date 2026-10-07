#!/usr/bin/env bash
# =============================================================================
# Script: 03_system_report.sh
# Problem Statement: Collect and display comprehensive server hardware, load average, network interfaces, and disk storage diagnostics.
# =============================================================================

set -euo pipefail

trap 'echo -e "\n${RED}Script exited unexpectedly.${RESET}" >&2' ERR

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; RED="\033[0;31m"; RESET="\033[0m"
REPORT="system_report_$(date '+%Y-%m-%d').txt"

clear
echo -e "${GREEN}=== System Report Generator ===${RESET}\n"

echo -n "Enter your name: "
read -r NAME
[ -z "$NAME" ] && NAME="User"

echo -e "\nHello $NAME! Generating report...\n"

{
  echo "=============================="
  echo "  SYSTEM REPORT"
  echo "  By       : $NAME"
  echo "  Date     : $(date '+%d %B %Y')"
  echo "  Time     : $(date '+%H:%M:%S')"
  echo "=============================="

  echo -e "\n--- Basic Info ---"
  echo "Hostname : $(hostname)"
  echo "User     : $(whoami)"
  echo "OS       : $(uname -s) | Kernel: $(uname -r)"
  echo "Shell    : $SHELL"
  echo "Uptime   : $(uptime -p 2>/dev/null || uptime)"

  echo -e "\n--- Memory Usage ---"
  free -h 2>/dev/null || echo "free command not available"

  echo -e "\n--- Disk Usage ---"
  df -h

  echo -e "\n--- Top 5 Processes by CPU ---"
  if ps aux --sort=-%cpu &>/dev/null 2>&1; then
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR==1 || NR<=6 {printf "%-12s %5s%% %s\n", $1, $3, $11}'
  else
    ps aux 2>/dev/null | sort -k3 -rn | awk 'NR<=5 {printf "%-12s %5s%% %s\n", $1, $3, $11}'
  fi

  echo -e "\n=============================="
  echo "  END OF REPORT"
  echo "=============================="
} | tee "$REPORT"

DISK_USED=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

if   [ "$DISK_USED" -ge 80 ]; then echo -e "\n${RED}⚠  Disk is ${DISK_USED}% full — cleanup needed!${RESET}"
elif [ "$DISK_USED" -ge 60 ]; then echo -e "\n${YELLOW}⚡ Disk is ${DISK_USED}% full.${RESET}"
else                                echo -e "\n${GREEN}✅ Disk is healthy: ${DISK_USED}% used.${RESET}"
fi

echo -e "\n${CYAN}Report saved to: $REPORT${RESET}\n"
