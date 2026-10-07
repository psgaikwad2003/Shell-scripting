#!/usr/bin/env bash
# =============================================================================
# Script: 30_k8s_pod_health_inspector.sh
# Problem Statement: Inspect Kubernetes pods across namespaces to detect CrashLoopBackOff states, OOMKilled events, and excessive restart counts.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

NAMESPACE="${1:---all-namespaces}"
MAX_RESTARTS="${2:-5}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ☸️   KUBERNETES POD HEALTH & TRIAGE INSPECTOR         "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Namespace Filter : $NAMESPACE"
    echo "Restart Threshold: $MAX_RESTARTS restarts"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

run_mock_diagnostic() {
    echo -e "${YELLOW}[NOTICE] 'kubectl' not found or cluster unreachable. Running diagnostic simulation mode.${RESET}\n"

    printf "%-20s %-30s %-12s %-10s %-15s\n" "NAMESPACE" "POD NAME" "STATUS" "RESTARTS" "HEALTH"
    echo "----------------------------------------------------------------------------------------"
    printf "%-20s %-30s %-12s %-10s ${GREEN}%-15s${RESET}\n" "production" "web-api-749bf6979b-x89p2" "Running" "0" "HEALTHY"
    printf "%-20s %-30s %-12s %-10s ${GREEN}%-15s${RESET}\n" "production" "redis-master-0" "Running" "1" "HEALTHY"
    printf "%-20s %-30s %-12s %-10s ${RED}%-15s${RESET}\n" "staging" "worker-queue-69d8b8cc7-7zkm1" "CrashLoop" "14" "CRITICAL_RESTART"
    printf "%-20s %-30s %-12s %-10s ${YELLOW}%-15s${RESET}\n" "monitoring" "grafana-5f4b59b58-q4pl9" "Pending" "0" "PENDING_SCHEDULE"
    printf "%-20s %-30s %-12s %-10s ${RED}%-15s${RESET}\n" "ingress" "cert-manager-5d46c8b9f-lk8m2" "OOMKilled" "8" "OUT_OF_MEMORY"

    echo -e "\n${BOLD}Simulation Recommendations:${RESET}"
    echo "  1. Investigate worker-queue: 'kubectl logs -n staging worker-queue-69d8b8cc7-7zkm1 --previous'"
    echo "  2. Increase memory limits for cert-manager in ingress namespace."
}

audit_cluster() {
    if ! command -v kubectl &>/dev/null; then
        run_mock_diagnostic
        return 0
    fi

    local NS_FLAG=""
    if [[ "$NAMESPACE" != "--all-namespaces" ]]; then
        NS_FLAG="-n $NAMESPACE"
    else
        NS_FLAG="-A"
    fi

    echo -e "${BOLD}Querying cluster pod metrics...${RESET}\n"

    local POD_DATA
    if ! POD_DATA=$(kubectl get pods $NS_FLAG --no-headers -o custom-columns="NS:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount" 2>/dev/null); then
        run_mock_diagnostic
        return 0
    fi

    printf "%-20s %-35s %-15s %-10s\n" "NAMESPACE" "POD NAME" "STATUS" "RESTARTS"
    echo "------------------------------------------------------------------------------------"

    local ISSUES_FOUND=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ns name status restarts
        read -r ns name status restarts <<< "$line"

        restarts="${restarts:-0}"
        if [[ "$restarts" =~ ^[0-9]+$ ]] && (( restarts >= MAX_RESTARTS )); then
            printf "%-20s %-35s %-15s ${RED}%-10s [EXCEEDED THRESHOLD]${RESET}\n" "$ns" "$name" "$status" "$restarts"
            ((ISSUES_FOUND++)) || true
        elif [[ "$status" != "Running" ]] && [[ "$status" != "Completed" ]]; then
            printf "%-20s %-35s ${YELLOW}%-15s${RESET} %-10s\n" "$ns" "$name" "$status" "$restarts"
            ((ISSUES_FOUND++)) || true
        else
            printf "%-20s %-35s ${GREEN}%-15s${RESET} %-10s\n" "$ns" "$name" "$status" "$restarts"
        fi
    done <<< "$POD_DATA"

    echo -e "\nSummary: Audit completed with $ISSUES_FOUND alert(s) detected."
}

print_banner
audit_cluster
