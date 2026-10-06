#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 07_user_account_manager.sh
#  LEVEL  : Intermediate
#  PURPOSE: Linux User Account Administration (Create, Lock, Unlock, Delete)
#  USAGE  : bash 07_user_account_manager.sh [ACTION] [USERNAME] [GROUP]
#           Actions: create | lock | unlock | delete | list | info
#
#  CONCEPTS COVERED:
#    - Root privileges checking (EUID == 0)
#    - Case statement for subcommands
#    - useradd, usermod, userdel, passwd commands
#    - Idempotency checks (grep in /etc/passwd)
#    - Safe argument parsing and interactive prompting fallback
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
BOLD="\033[1m"
RESET="\033[0m"

log_info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

ACTION="${1:-help}"
USERNAME="${2:-}"
USER_GROUP="${3:-}"

check_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_warn "Notice: Running in unprivileged mode. Privileged commands (useradd/del) will be simulated."
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
        read -rp "Enter username to create: " user
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

    log_info "Executing command: $cmd"
    if [[ "$SIMULATE" == "true" ]]; then
        log_success "[SIMULATION] User '$user' would be created with home directory and bash shell."
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

    read -rp "Are you sure you want to permanently remove user '$user' and home directory? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [[ "$SIMULATE" == "true" ]]; then
            log_success "[SIMULATION] userdel -r '$user' executed."
        else
            userdel -r "$user"
            log_success "User '$user' and associated home files removed."
        fi
    else
        log_info "Operation cancelled by user."
    fi
}

action_info() {
    local user="$1"
    [[ -z "$user" ]] && { log_error "Username required."; return 1; }

    if user_exists "$user"; then
        echo -e "\n${BOLD}User Details for: ${user}${RESET}"
        id "$user"
        grep "^${user}:" /etc/passwd 2>/dev/null || true
    else
        log_error "User '$user' does not exist."
    fi
}

show_usage() {
    echo -e "${BOLD}Usage:${RESET} $0 {create|lock|unlock|delete|info|list} [username] [group]"
    echo
    echo "Examples:"
    echo "  $0 create devops_user developers"
    echo "  $0 lock devops_user"
    echo "  $0 unlock devops_user"
    echo "  $0 info devops_user"
    echo "  $0 delete devops_user"
}

main() {
    check_root
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
