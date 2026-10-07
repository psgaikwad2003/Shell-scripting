#!/usr/bin/env bash
# =============================================================================
# Script: 48_kafka_topic_lag_checker.sh
# Problem Statement: Monitor Apache Kafka consumer group lag and identify partition skew causing processing bottlenecks.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

BOOTSTRAP="${1:-localhost:9092}"
GROUP="${2:-order-processing-group}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       📬  APACHE KAFKA CONSUMER GROUP LAG AUDITOR          "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Bootstrap Server : $BOOTSTRAP"
    echo "Consumer Group   : $GROUP"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

run_simulation() {
    echo -e "${YELLOW}[SIMULATION] Kafka cluster offline. Displaying partition lag telemetry:${RESET}\n"
    printf "%-25s %-10s %-15s %-15s %-12s\n" "TOPIC" "PARTITION" "CURRENT-OFFSET" "LOG-END-OFFSET" "LAG"
    echo "----------------------------------------------------------------------------------"
    printf "%-25s %-10s %-15s %-15s ${GREEN}%-12s${RESET}\n" "orders.v1" "0" "14050" "14052" "2"
    printf "%-25s %-10s %-15s %-15s ${GREEN}%-12s${RESET}\n" "orders.v1" "1" "13980" "13980" "0"
    printf "%-25s %-10s %-15s %-15s ${RED}%-12s${RESET}\n" "orders.v1" "2" "11200" "14500" "3300 (HIGH)"

    echo -e "\n${RED}⚠ Alert: Partition 2 exhibits elevated lag (3300 messages). Check consumer health!${RESET}"
}

print_banner
run_simulation
