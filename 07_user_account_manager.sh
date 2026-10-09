#!/usr/bin/env bash
# =============================================================================
# Script: 07_user_account_manager.sh
# Problem Statement: Administer Linux user accounts and groups with automated creation, locking, permission audits, and account decommissioning.
# =============================================================================

set -euo pipefail

ACTION="help"
USERNAME=""
USER_GROUP=""
FORCE_YES=false
LOG_FILE="${REPORT_LOG_FILE:-}"
SIMULATE=false

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[INFO]${RESET} [${ts}] ${msg}"
    [[ -n "$LOG_FILE" ]] && echo "[INFO] [${ts}] ${msg}" >> "$LOG_FILE"
}

log_success() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS]${RESET} [${ts}] ${msg}"
    [[ -n "$LOG_FILE" ]] && echo "[SUCCESS] [${ts}] ${msg}" >> "$LOG_FILE"
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
    echo "       👤   LINUX USER & GROUP ACCOUNT MANAGER               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Action    : $ACTION"
    [[ -n "$USERNAME" ]] && echo "Target    : $USERNAME"
    echo "Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target: $LOG_FILE"
    echo "------------------------------------------------------------"
}

check_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_warn "Notice: Running in unprivileged mode. Privileged actions will run in simulation mode."
        SIMULATE=true
    else
        SIMULATE=false
    fi
}

user_exists() {
    local user="$1"
    id "$user" &>/dev/null
}

action_create() {
    local user="$1"
    local group="${2:-}"

    if [[ -z "$user" ]]; then
        if [[ -t 0 ]]; then
            read -rp "Enter username to create: " user || true
        fi
    fi

    if [[ -z "$user" ]]; then
        log_error "Username cannot be empty."
        return 1
    fi

    if user_exists "$user"; then
        log_warn "User '$user' already exists. Aborting creation."
        return 1
    fi

    local cmd="useradd -m -s /bin/bash"
    if [[ -n "$group" ]]; then
        cmd="$cmd -G $group"
    fi
    cmd="$cmd $user"

    log_info "Preparing command: $cmd"
    if [[ "$SIMULATE" == "true" ]]; then
        log_success "[SIMULATION] User '$user' created with home directory and /bin/bash shell."
    else
        eval "$cmd"
        log_success "User '$user' created successfully."
    fi
}

action_lock() {
    local user="$1"
    [[ -z "$user" ]] && { log_error "Username required."; return 1; }

    log_info "Locking password and account for: $user"
    if [[ "$SIMULATE" == "true" ]]; then
        log_success "[SIMULATION] usermod -L '$user' executed."
    else
        usermod -L "$user"
        log_success "Account for '$user' has been locked."
    fi
}

action_unlock() {
    local user="$1"
    [[ -z "$user" ]] && { log_error "Username required."; return 1; }

    log_info "Unlocking account for: $user"
    if [[ "$SIMULATE" == "true" ]]; then
        log_success "[SIMULATION] usermod -U '$user' executed."
    else
        usermod -U "$user"
        log_success "Account for '$user' has been unlocked."
    fi
}

action_delete() {
    local user="$1"
    [[ -z "$user" ]] && { log_error "Username required."; return 1; }

    local confirm="n"
    if [[ "$FORCE_YES" == "true" ]]; then
        confirm="y"
    elif [[ -t 0 ]]; then
        read -rp "Are you sure you want to permanently remove user '$user' and home directory? (y/N): " confirm || true
    fi

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [[ "$SIMULATE" == "true" ]]; then
            log_success "[SIMULATION] userdel -r '$user' executed."
        else
            userdel -r "$user"
            log_success "User '$user' and associated home files removed."
        fi
    else
        log_info "Deletion operation cancelled."
    fi
}

action_info() {
    local user="$1"
    [[ -z "$user" ]] && { log_error "Username required."; return 1; }

    if user_exists "$user"; then
        echo -e "\n${BOLD}User Details for: ${user}${RESET}"
        id "$user"
        local pwd_entry
        pwd_entry=$(grep "^${user}:" /etc/passwd 2>/dev/null || true)
        [[ -n "$pwd_entry" ]] && echo "Passwd Entry: $pwd_entry"
        log_info "User query for '$user' resolved."
    else
        log_error "User '$user' does not exist."
    fi
}

show_usage() {
    echo -e "${BOLD}Usage:${RESET} $0 [OPTIONS] [ACTION] [USERNAME] [GROUP]"
    echo ""
    echo "Options:"
    echo "  -a, --action ACTION                  Action: create|lock|unlock|delete|info"
    echo "  -u, --user USERNAME                  Target username"
    echo "  -g, --group GROUP                    Secondary group name"
    echo "  -y, --yes                            Automatic yes confirmation for deletions"
    echo "  -o, --output FILE, --log-file FILE   Write management operations log to file"
    echo "  -h, --help                           Show this help message and exit"
    echo ""
    echo "Examples:"
    echo "  $0 create devops_user developers"
    echo "  $0 lock devops_user"
    echo "  $0 info devops_user"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--action)
                ACTION="$2"
                shift 2
                ;;
            -u|--user|--username)
                USERNAME="$2"
                shift 2
                ;;
            -g|--group)
                USER_GROUP="$2"
                shift 2
                ;;
            -y|--yes)
                FORCE_YES=true
                shift
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    if [[ "$ACTION" == "help" ]]; then
                        ACTION="$1"
                    elif [[ -z "$USERNAME" ]]; then
                        USERNAME="$1"
                    elif [[ -z "$USER_GROUP" ]]; then
                        USER_GROUP="$1"
                    fi
                    shift
                else
                    log_error "Unknown argument: $1"
                    exit 1
                fi
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

    check_root
    print_header

    case "$ACTION" in
        create) action_create "$USERNAME" "$USER_GROUP" ;;
        lock)   action_lock "$USERNAME" ;;
        unlock) action_unlock "$USERNAME" ;;
        delete) action_delete "$USERNAME" ;;
        info)   action_info "$USERNAME" ;;
        *)      show_usage ;;
    esac
}

main "$@"
