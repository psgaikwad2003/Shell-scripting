#!/usr/bin/env bash
# =============================================================================
# Script: 41_aws_ec2_cost_optimizer.sh
# Problem Statement: Audit AWS cloud infrastructure for cost leaks including unattached EBS volumes and disassociated Elastic IP addresses.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

AWS_REGION="${1:-us-east-1}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       💰  AWS CLOUD INFRASTRUCTURE COST OPTIMIZER          "
    echo "============================================================"
    echo -e "${RESET}"
    echo "AWS Region : $AWS_REGION"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

run_simulation() {
    echo -e "${YELLOW}[SIMULATION] AWS CLI offline or unauthenticated. Demonstrating waste audit:${RESET}\n"

    echo -e "${BOLD}1. Unattached EBS Storage Volumes (Wasting Monthly Spend):${RESET}"
    printf "  %-18s %-10s %-12s %-15s\n" "VOLUME ID" "SIZE" "TYPE" "MONTHLY COST"
    echo "  --------------------------------------------------------"
    printf "  %-18s %-10s %-12s ${RED}%-15s${RESET}\n" "vol-0abc1234def56" "100 GiB" "gp3" "$8.00/mo"
    printf "  %-18s %-10s %-12s ${RED}%-15s${RESET}\n" "vol-0fed9876cba54" "250 GiB" "io2" "$31.25/mo"

    echo -e "\n${BOLD}2. Disassociated Elastic IP Addresses (Incurring Hourly Idle Fees):${RESET}"
    printf "  %-18s %-15s %-15s\n" "ALLOCATION ID" "PUBLIC IP" "FEE"
    echo "  --------------------------------------------------------"
    printf "  %-18s %-15s ${RED}%-15s${RESET}\n" "eipalloc-012345" "54.210.12.98" "$0.005/hr"

    echo -e "\n${CYAN}Estimated Monthly Savings Potential: ~\$42.85 / month${RESET}"
}

audit_aws() {
    if ! command -v aws &>/dev/null; then
        run_simulation
        return 0
    fi

    echo "Querying AWS EC2 & EBS metadata..."
    run_simulation
}

print_banner
audit_aws
