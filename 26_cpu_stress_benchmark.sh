#!/usr/bin/env bash
# =============================================================================
# Script: 26_cpu_stress_benchmark.sh
# Problem Statement: Generate synthetic multi-core CPU load and benchmark execution time to assess thermal performance and system stability.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

ITERATIONS=100000
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

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🚀  CPU MULTI-CORE BENCHMARK & PERFORMANCE TEST       "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Iterations : $ITERATIONS rounds of SHA-256 hashing"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target : $LOG_FILE"
    echo "------------------------------------------------------------"
}

get_core_count() {
    if command -v nproc &>/dev/null; then
        nproc
    elif [[ -f /proc/cpuinfo ]]; then
        grep -c '^processor' /proc/cpuinfo
    else
        echo 2
    fi
}

run_worker_bench() {
    local worker_id="$1"
    local rounds="$2"
    local dummy="benchmark_seed_data_$(date +%s%N)"
    for ((i=1; i<=rounds; i++)); do
        dummy=$(echo "$dummy" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo "$dummy")
    done
}

run_benchmark() {
    local cores
    cores=$(get_core_count)
    log_info "Detected CPU Cores: $cores"
    log_info "Spawning benchmark workers ($ITERATIONS iterations per core)..."

    local start_time
    start_time="$(date +%s)"

    for ((c=1; c<=cores; c++)); do
        ( run_worker_bench "$c" "$ITERATIONS" ) &
    done

    wait

    local end_time
    end_time="$(date +%s)"
    local total_time=$(( end_time - start_time ))
    [[ "$total_time" -le 0 ]] && total_time=1

    local ops_per_sec=$(( (ITERATIONS * cores) / total_time ))

    echo -e "\n------------------------------------------------------------"
    echo -e "${BOLD}Benchmark Results:${RESET}"
    echo -e "Total Time Taken : ${CYAN}${total_time}s${RESET}"
    echo -e "Throughput Rate  : ${GREEN}${BOLD}${ops_per_sec} ops/sec${RESET}"
    echo "------------------------------------------------------------"

    log_info "Benchmark complete: elapsed=${total_time}s, throughput=${ops_per_sec} ops/sec"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [ITERATIONS]"
                echo "Options:"
                echo "  -i, --iterations NUM                 Number of SHA-256 iterations per worker"
                echo "  -o, --output FILE, --log-file FILE   Write benchmark telemetry and results to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    ITERATIONS="$1"
                else
                    log_error "Unknown parameter: $1"
                    exit 1
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
    print_header
    run_benchmark
    log_info "CPU benchmark run completed successfully."
}

main "$@"
