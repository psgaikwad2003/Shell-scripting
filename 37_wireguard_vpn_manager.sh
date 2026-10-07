#!/usr/bin/env bash
# =============================================================================
# Script: 37_wireguard_vpn_manager.sh
# Problem Statement: Audit WireGuard VPN interfaces, peer handshake freshness, and network transfer volume to detect stale tunnels.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

WG_IFACE="${1:-wg0}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🛡️   WIREGUARD VPN PEER HEALTH & AUDITOR              "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Interface: $WG_IFACE"
    echo "Timestamp       : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

run_simulation() {
    echo -e "${YELLOW}[SIMULATION] wg CLI or interface inactive. Demonstrating peer monitoring:${RESET}\n"
    printf "%-30s %-20s %-18s %-12s\n" "PEER PUBLIC KEY" "ENDPOINT" "LATEST HANDSHAKE" "STATUS"
    echo "--------------------------------------------------------------------------------"
    printf "%-30s %-20s %-18s ${GREEN}%-12s${RESET}\n" "xK9z...pL2w=" "198.51.100.24:51820" "14 seconds ago" "ONLINE"
    printf "%-30s %-20s %-18s ${GREEN}%-12s${RESET}\n" "bT4y...qM7a=" "203.0.113.88:51820" "52 seconds ago" "ONLINE"
    printf "%-30s %-20s %-18s ${RED}%-12s${RESET}\n" "aR8e...vK1x=" "(none)" "Never" "STALE"
}

check_wireguard() {
    if command -v wg &>/dev/null && wg show "$WG_IFACE" &>/dev/null; then
        echo -e "${BOLD}Active WireGuard Interface Data:${RESET}"
        wg show "$WG_IFACE"
    else
        run_simulation
    fi
}

print_banner
check_wireguard
