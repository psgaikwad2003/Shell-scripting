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

ITERATIONS="${1:-100000}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🚀  CPU MULTI-CORE BENCHMARK & PERFORMANCE TEST       "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Iterations : $ITERATIONS rounds of SHA-256 hashing"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

get_core_count() {
    if command -v nproc &>/dev/null; then
        nproc
    elif [[ -f /proc/cpuinfo ]]; then
        grep -c '^processor' /proc/cpuinfo
    else
        echo 2 # safe default
    fi
}

run_worker_bench() {
    local worker_id="$1"
    local rounds="$2"
    echo -n "Core Worker #$worker_id running..."
    local dummy="benchmark_seed_data_$(date +%s%N)"
    for ((i=1; i<=rounds; i++)); do
        dummy=$(echo "$dummy" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo "$dummy")
    done
    echo " Done."
}

run_benchmark() {
    local cores
    cores=$(get_core_count)
    echo -e "Detected CPU Cores: ${BOLD}${cores}${RESET}\n"

    echo "Spawning benchmark worker across all detected cores..."
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
}

main() {
    print_header
    run_benchmark
    echo -e "${GREEN}✔ CPU benchmark execution complete.${RESET}"
}

main "$@"
