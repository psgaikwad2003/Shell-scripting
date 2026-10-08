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

NAMESPACE="--all-namespaces"
MAX_RESTARTS=5
LOG_FILE="${REPORT_LOG_FILE:-}"

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${RESET} [${ts}] ${msg}"
    [[ -n "$LOG_FILE" ]] && echo "[INFO] [${ts}] ${msg}" >> "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${RESET} [${ts}] ${msg}"
    [[ -n "$LOG_FILE" ]] && echo "[WARN] [${ts}] ${msg}" >> "$LOG_FILE"
}

log_error() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${RESET} [${ts}] ${msg}" >&2
    [[ -n "$LOG_FILE" ]] && echo "[ERROR] [${ts}] ${msg}" >> "$LOG_FILE"
}

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ☸️   KUBERNETES POD HEALTH & TRIAGE INSPECTOR         "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Namespace Filter : $NAMESPACE"
    echo "Restart Threshold: $MAX_RESTARTS restarts"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target       : $LOG_FILE"
    echo "------------------------------------------------------------"
}

run_mock_diagnostic() {
    log_warn "'kubectl' not found or cluster unreachable. Running diagnostic simulation mode."

    printf "%-20s %-30s %-12s %-10s %-15s\n" "NAMESPACE" "POD NAME" "STATUS" "RESTARTS" "HEALTH"
    echo "----------------------------------------------------------------------------------------"
    printf "%-20s %-30s %-12s %-10s ${GREEN}%-15s${RESET}\n" "production" "web-api-749bf6979b-x89p2" "Running" "0" "HEALTHY"
    printf "%-20s %-30s %-12s %-10s ${GREEN}%-15s${RESET}\n" "production" "redis-master-0" "Running" "1" "HEALTHY"
    printf "%-20s %-30s %-12s %-10s ${RED}%-15s${RESET}\n" "staging" "worker-queue-69d8b8cc7-7zkm1" "CrashLoop" "14" "CRITICAL_RESTART"
    printf "%-20s %-30s %-12s %-10s ${YELLOW}%-15s${RESET}\n" "monitoring" "grafana-5f4b59b58-q4pl9" "Pending" "0" "PENDING_SCHEDULE"
    printf "%-20s %-30s %-12s %-10s ${RED}%-15s${RESET}\n" "ingress" "cert-manager-5d46c8b9f-lk8m2" "OOMKilled" "8" "OUT_OF_MEMORY"

    log_warn "Simulation Recommendation: Investigate worker-queue logs (CrashLoop with 14 restarts)."
    log_warn "Simulation Recommendation: Increase memory limits for cert-manager in ingress (OOMKilled)."
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

    log_info "Querying cluster pod metrics for namespace filter: $NAMESPACE..."

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
            log_error "Pod $name in $ns exceeded restart threshold: $restarts restarts"
            ((ISSUES_FOUND++)) || true
        elif [[ "$status" != "Running" ]] && [[ "$status" != "Completed" ]]; then
            printf "%-20s %-35s ${YELLOW}%-15s${RESET} %-10s\n" "$ns" "$name" "$status" "$restarts"
            log_warn "Pod $name in $ns is non-running: status=$status"
            ((ISSUES_FOUND++)) || true
        else
            printf "%-20s %-35s ${GREEN}%-15s${RESET} %-10s\n" "$ns" "$name" "$status" "$restarts"
        fi
    done <<< "$POD_DATA"

    log_info "Audit complete: $ISSUES_FOUND issue(s) detected across target namespace(s)."
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -r|--max-restarts)
                MAX_RESTARTS="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [NAMESPACE] [MAX_RESTARTS]"
                echo "Options:"
                echo "  -n, --namespace NAMESPACE            Kubernetes namespace (default: --all-namespaces)"
                echo "  -r, --max-restarts NUM               Max allowed container restarts (default: 5)"
                echo "  -o, --output FILE, --log-file FILE   Write pod audit report to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ -z "${1_pos:-}" ]]; then
                    NAMESPACE="$1"
                    1_pos=1
                elif [[ -z "${2_pos:-}" ]]; then
                    MAX_RESTARTS="$1"
                    2_pos=1
                fi
                shift
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        : > "$LOG_FILE"
    fi
    print_banner
    audit_cluster
    log_info "Kubernetes pod inspection cycle concluded."
}

main "$@"
