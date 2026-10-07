#!/usr/bin/env bash
# =============================================================================
# Script: 14_docker_cleanup_tool.sh
# Problem Statement: Clean up stopped Docker containers, dangling images, unused volumes, and build cache to reclaim host disk space.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

MODE="${1:---dry-run}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🐳  DOCKER RESOURCE CLEANUP & PRUNING UTILITY        "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Execution Mode : $MODE"
    echo "Timestamp      : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}[INFO] 'docker' binary not found. Simulating cleanup commands.${RESET}"
        IS_MOCK=true
    else
        IS_MOCK=false
    fi
}

prune_stopped_containers() {
    echo -e "\n${BOLD}[1/4] Checking stopped containers...${RESET}"
    if [[ "$IS_MOCK" == "true" ]]; then
        echo "  ↳ [SIMULATION] Found 3 stopped containers. Running: docker container prune -f"
    else
        if [[ "$MODE" == "--force" ]]; then
            docker container prune -f
        else
            echo "  ↳ [DRY-RUN] Would remove stopped containers:"
            docker ps -a --filter "status=exited" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}" || true
        fi
    fi
}

prune_dangling_images() {
    echo -e "\n${BOLD}[2/4] Checking dangling images (<none>)...${RESET}"
    if [[ "$IS_MOCK" == "true" ]]; then
        echo "  ↳ [SIMULATION] Found 2 dangling images. Running: docker image prune -f"
    else
        if [[ "$MODE" == "--force" ]]; then
            docker image prune -f
        else
            echo "  ↳ [DRY-RUN] Would remove dangling images:"
            docker images -f "dangling=true" --format "table {{.ID}}\t{{.Repository}}\t{{.Size}}" || true
        fi
    fi
}

prune_unused_volumes() {
    echo -e "\n${BOLD}[3/4] Checking unused dangling volumes...${RESET}"
    if [[ "$IS_MOCK" == "true" ]]; then
        echo "  ↳ [SIMULATION] Found 1 unattached volume. Running: docker volume prune -f"
    else
        if [[ "$MODE" == "--force" ]]; then
            docker volume prune -f
        else
            echo "  ↳ [DRY-RUN] Would remove dangling volumes:"
            docker volume ls -qf dangling=true || true
        fi
    fi
}

prune_build_cache() {
    echo -e "\n${BOLD}[4/4] Checking Docker build cache...${RESET}"
    if [[ "$IS_MOCK" == "true" ]]; then
        echo "  ↳ [SIMULATION] Running: docker builder prune -f"
    else
        if [[ "$MODE" == "--force" ]]; then
            docker builder prune -f
        else
            echo "  ↳ [DRY-RUN] Run with --force to clear builder cache."
        fi
    fi
}

main() {
    print_header
    check_docker
    prune_stopped_containers
    prune_dangling_images
    prune_unused_volumes
    prune_build_cache
    echo "------------------------------------------------------------"
    if [[ "$MODE" == "--force" ]]; then
        echo -e "${GREEN}${BOLD}✔ Docker environment cleanup completed!${RESET}"
    else
        echo -e "${YELLOW}Dry run completed. Pass '--force' to execute destructive cleanup.${RESET}"
    fi
}

main "$@"
