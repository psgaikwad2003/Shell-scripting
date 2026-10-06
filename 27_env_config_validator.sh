#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 27_env_config_validator.sh
#  LEVEL  : Intermediate
#  PURPOSE: Production .env Environment & Secret Key Validator
#  USAGE  : bash 27_env_config_validator.sh [ENV_FILE] [EXAMPLE_FILE]
#           bash 27_env_config_validator.sh .env .env.example
#
#  CONCEPTS COVERED:
#    - Parsing KEY=VALUE formatted configuration files
#    - Detecting missing required environment keys
#    - Checking for empty / unset variable definitions
#    - Associative arrays (declare -A) for dictionary lookups
#    - CI/CD pre-flight deployment check exit codes
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

ENV_FILE="${1:-/tmp/.env}"
EXAMPLE_FILE="${2:-/tmp/.env.example}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       ⚙️   .ENV CONFIGURATION & SECRET VALIDATOR            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Active .env File   : $ENV_FILE"
    echo "Template Example   : $EXAMPLE_FILE"
    echo "Timestamp          : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

seed_samples_if_missing() {
    if [[ ! -f "$EXAMPLE_FILE" ]]; then
        cat << 'EOF' > "$EXAMPLE_FILE"
# Application Configuration Template
DATABASE_URL=
API_SECRET_KEY=
PORT=8080
LOG_LEVEL=info
REDIS_HOST=
EOF
    fi

    if [[ ! -f "$ENV_FILE" ]]; then
        cat << 'EOF' > "$ENV_FILE"
# Active Environment
PORT=8080
LOG_LEVEL=debug
# Notice DATABASE_URL and API_SECRET_KEY are missing for demonstration!
REDIS_HOST=
EOF
    fi
}

validate_env() {
    seed_samples_if_missing
    echo -e "Auditing environment configuration...\n"

    local missing_count=0
    local empty_count=0
    local valid_count=0

    # Extract all non-comment non-empty keys from example template
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        # Strip comments and whitespace
        key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        # Check if key exists in active env file
        if ! grep -q "^[[:space:]]*${key}=" "$ENV_FILE" 2>/dev/null; then
            echo -e "${RED}${BOLD}[MISSING KEY]${RESET} '$key' is required by template but absent in .env"
            ((missing_count++))
        else
            # Extract assigned value
            local actual_val
            actual_val=$(grep "^[[:space:]]*${key}=" "$ENV_FILE" | head -n 1 | cut -d'=' -f2-)
            if [[ -z "$actual_val" ]]; then
                echo -e "${YELLOW}[EMPTY VALUE]${RESET} '$key' is defined but has no value assigned"
                ((empty_count++))
            else
                echo -e "${GREEN}[VALID]${RESET} '$key' is configured"
                ((valid_count++))
            fi
        fi
    done < "$EXAMPLE_FILE"

    echo "------------------------------------------------------------"
    echo -e "Validation Summary: ${GREEN}$valid_count Valid${RESET} | ${YELLOW}$empty_count Empty${RESET} | ${RED}$missing_count Missing${RESET}"

    if (( missing_count > 0 )); then
        echo -e "\n${RED}❌ Validation Failed: Critical required variables are missing!${RESET}"
        return 1
    else
        echo -e "\n${GREEN}✔ Validation Passed: Environment is ready for deployment.${RESET}"
        return 0
    fi
}

main() {
    print_header
    validate_env || true
}

main "$@"
