#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 31_redis_cache_benchmark.sh
#  LEVEL  : Intermediate
#  PURPOSE: Audit Redis in-memory cache metrics, latency, hit ratios, & fragmentation
#  USAGE  : bash 31_redis_cache_benchmark.sh [HOST] [PORT] [AUTH_PASSWORD]
#           bash 31_redis_cache_benchmark.sh 127.0.0.1 6379 ""
#
#  CONCEPTS COVERED:
#    - Redis INFO command metric extraction via redis-cli / netcat
#    - Cache hit ratio calculation formula: hits / (hits + misses) * 100
#    - Memory fragmentation ratio analysis (used_memory vs used_memory_rss)
#    - Graceful fallback simulator when Redis server is offline
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

REDIS_HOST="${1:-127.0.0.1}"
REDIS_PORT="${2:-6379}"
REDIS_AUTH="${3:-}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ⚡  REDIS IN-MEMORY CACHE & LATENCY BENCHMARK        "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Endpoint   : ${REDIS_HOST}:${REDIS_PORT}"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

run_mock_benchmark() {
    echo -e "${YELLOW}[SIMULATION] Redis instance offline or unreachable. Demonstrating metric audit:${RESET}\n"
    
    echo -e "${BOLD}Simulated Redis Metrics:${RESET}"
    echo "  Connected Clients           : 142"
    echo "  Total Keys Stored           : 1,845,920"
    echo "  Memory Used (Human)         : 2.14G"
    echo "  Memory RSS (Resident)       : 2.45G"
    echo "  Memory Fragmentation Ratio  : 1.14 (Optimal range: 1.0 - 1.5)"
    echo "  Cache Hits                  : 45,920,110"
    echo "  Cache Misses                : 1,230,400"
    echo -e "  Hit Ratio                   : ${GREEN}97.39% (Excellent)${RESET}"
    echo -e "  Ping Latency (Roundtrip)    : ${GREEN}0.42 ms${RESET}"
    echo -e "\n${GREEN}✔ Simulated Redis performance analysis completed successfully.${RESET}"
}

audit_redis() {
    if ! command -v redis-cli &>/dev/null; then
        run_mock_benchmark
        return 0
    fi

    local CLI_CMD=(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT")
    [[ -n "$REDIS_AUTH" ]] && CLI_CMD+=(-a "$REDIS_AUTH")

    if ! "${CLI_CMD[@]}" ping 2>/dev/null | grep -q PONG; then
        run_mock_benchmark
        return 0
    fi

    echo -e "${BOLD}Active Server Diagnostics:${RESET}"
    local INFO
    INFO=$("${CLI_CMD[@]}" info)

    local CLIENTS USED_MEM USED_RSS HITS MISSES FRAG
    CLIENTS=$(echo "$INFO" | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')
    USED_MEM=$(echo "$INFO" | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
    USED_RSS=$(echo "$INFO" | grep "used_memory_rss_human:" | cut -d: -f2 | tr -d '\r')
    FRAG=$(echo "$INFO" | grep "mem_fragmentation_ratio:" | cut -d: -f2 | tr -d '\r')
    HITS=$(echo "$INFO" | grep "keyspace_hits:" | cut -d: -f2 | tr -d '\r')
    MISSES=$(echo "$INFO" | grep "keyspace_misses:" | cut -d: -f2 | tr -d '\r')

    echo "  Connected Clients : $CLIENTS"
    echo "  Used Memory       : $USED_MEM (RSS: $USED_RSS)"
    echo "  Fragmentation     : $FRAG"

    local TOTAL=$(( HITS + MISSES ))
    if (( TOTAL > 0 )); then
        local RATIO=$(( HITS * 100 / TOTAL ))
        echo "  Hit Ratio         : ${RATIO}% (Hits: $HITS, Misses: $MISSES)"
    fi
}

print_banner
audit_redis
