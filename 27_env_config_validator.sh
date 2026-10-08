#!/usr/bin/env bash
# =============================================================================
# Script: 27_env_config_validator.sh
# Problem Statement: Validate active .env configuration files against template .env.example definitions to prevent missing secrets in CI/CD.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

ENV_FILE="/tmp/.env"
EXAMPLE_FILE="/tmp/.env.example"
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
    echo "       ⚙️   .ENV CONFIGURATION & SECRET VALIDATOR            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Active .env File   : $ENV_FILE"
    echo "Template Example   : $EXAMPLE_FILE"
    echo "Timestamp          : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target         : $LOG_FILE"
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
    log_info "Auditing environment configuration ($ENV_FILE vs $EXAMPLE_FILE)..."

    local missing_count=0
    local empty_count=0
    local valid_count=0

    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        if ! grep -q "^[[:space:]]*${key}=" "$ENV_FILE" 2>/dev/null; then
            log_error "[MISSING KEY] '$key' is required by template but absent in .env"
            ((missing_count++))
        else
            local actual_val
            actual_val=$(grep "^[[:space:]]*${key}=" "$ENV_FILE" | head -n 1 | cut -d'=' -f2-)
            if [[ -z "$actual_val" ]]; then
                log_warn "[EMPTY VALUE] '$key' is defined but has no value assigned"
                ((empty_count++))
            else
                log_info "[VALID] '$key' is properly configured"
                ((valid_count++))
            fi
        fi
    done < "$EXAMPLE_FILE"

    echo "------------------------------------------------------------"
    log_info "Validation Summary: $valid_count Valid | $empty_count Empty | $missing_count Missing"

    if (( missing_count > 0 )); then
        log_error "Validation Failed: Critical required variables are missing!"
        return 1
    else
        log_info "Validation Passed: Environment configuration is complete."
        return 0
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env)
                ENV_FILE="$2"
                shift 2
                ;;
            -t|--template|--example)
                EXAMPLE_FILE="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [ENV_FILE] [EXAMPLE_FILE]"
                echo "Options:"
                echo "  -e, --env FILE                       Path to active .env file"
                echo "  -t, --template FILE                  Path to template .env.example file"
                echo "  -o, --output FILE, --log-file FILE   Write audit report to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ -z "${1_pos:-}" ]]; then
                    ENV_FILE="$1"
                    1_pos=1
                elif [[ -z "${2_pos:-}" ]]; then
                    EXAMPLE_FILE="$1"
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
    print_header
    validate_env || true
}

main "$@"
