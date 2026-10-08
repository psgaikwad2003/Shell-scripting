#!/usr/bin/env bash
# =============================================================================
# Script: 40_ansible_playbook_syntax_linter.sh
# Problem Statement: Lint Ansible playbooks for YAML syntax validity, unnamed task anti-patterns, and exposed plaintext credentials.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

PLAYBOOK="/tmp/sample_playbook.yml"
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
    echo "       📜  ANSIBLE PLAYBOOK & YAML SYNTAX LINTER            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Playbook : $PLAYBOOK"
    echo "Timestamp       : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target      : $LOG_FILE"
    echo "------------------------------------------------------------"
}

seed_sample_if_missing() {
    if [[ ! -f "$PLAYBOOK" ]]; then
        log_info "No playbook found at $PLAYBOOK. Seeding demo playbook..."
        cat << 'EOF' > "$PLAYBOOK"
---
- name: Configure Production Web Nodes
  hosts: webservers
  become: true
  tasks:
    - name: Ensure nginx is installed
      apt:
        name: nginx
        state: present
    
    # Notice: Task without name (anti-pattern)
    - command: systemctl restart nginx

    - name: Deploy application config
      copy:
        src: app.conf
        dest: /etc/nginx/conf.d/app.conf
EOF
    fi
}

lint_playbook() {
    log_info "Running Ansible syntax and anti-pattern audit on $PLAYBOOK..."

    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$PLAYBOOK'))" &>/dev/null; then
            log_info "YAML syntax check: PASS (valid YAML)"
        else
            log_error "YAML syntax check: FAIL (syntax parse errors)"
        fi
    fi

    local UNNAMED_TASKS
    UNNAMED_TASKS=$(grep -nE "^\s*-\s*(command|shell|copy|apt|yum):" "$PLAYBOOK" || true)
    if [[ -n "$UNNAMED_TASKS" ]]; then
        log_warn "Discovered unnamed task anti-pattern (missing 'name:' identifier):"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            log_warn "  ↳ Line $line"
        done <<< "$UNNAMED_TASKS"
    else
        log_info "Task naming check: PASS (all tasks explicitly named)"
    fi

    if grep -inE "(password|secret|api_key|token):\s+[^\{]" "$PLAYBOOK" &>/dev/null; then
        log_error "Potential hardcoded credentials detected in playbook! Use ansible-vault."
    else
        log_info "Credential security check: PASS (no unencrypted secrets found)"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--playbook)
                PLAYBOOK="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [PLAYBOOK]"
                echo "Options:"
                echo "  -p, --playbook FILE                  Ansible playbook path to lint"
                echo "  -o, --output FILE, --log-file FILE   Write playbook linter report to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                PLAYBOOK="$1"
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
    seed_sample_if_missing
    lint_playbook
    log_info "Ansible playbook lint evaluation complete."
}

main "$@"
