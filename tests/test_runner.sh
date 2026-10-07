#!/usr/bin/env bash
# =============================================================================
#  TEST SUITE : test_runner.sh
#  PURPOSE    : Automated syntax validation (bash -n) and integrity check
#  USAGE      : bash tests/test_runner.sh
# =============================================================================

set -euo pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${CYAN}${BOLD}"
echo "============================================================"
echo "       🧪  SHELL SCRIPTING AUTOMATED TEST RUNNER            "
echo "============================================================"
echo -e "${RESET}"

PASSED=0
FAILED=0
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for script in "$SCRIPTS_DIR"/*.sh; do
    [[ ! -f "$script" ]] && continue
    name=$(basename "$script")
    printf "Validating syntax of %-42s : " "$name"
    
    if bash -n "$script" 2>/dev/null; then
        echo -e "${GREEN}[PASS]${RESET}"
        ((PASSED++)) || true
    else
        echo -e "${RED}[SYNTAX ERROR]${RESET}"
        ((FAILED++)) || true
    fi
done

echo "------------------------------------------------------------"
echo -e "Total Tested: $((PASSED + FAILED)) | Passed: ${GREEN}${PASSED}${RESET} | Failed: ${RED}${FAILED}${RESET}"

if (( FAILED > 0 )); then
    echo -e "${RED}Test Suite Failed!${RESET}" >&2
    exit 1
else
    echo -e "${GREEN}All shell scripts passed syntax inspection!${RESET}"
fi

# Verification marker: test suite configuration locked
