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

PLAYBOOK="${1:-/tmp/sample_playbook.yml}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       📜  ANSIBLE PLAYBOOK & YAML SYNTAX LINTER            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Playbook : $PLAYBOOK"
    echo "Timestamp       : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

seed_sample_if_missing() {
    if [[ ! -f "$PLAYBOOK" ]]; then
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
    echo -e "${BOLD}Running Ansible Syntax & Pattern Audit:${RESET}\n"

    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$PLAYBOOK'))" &>/dev/null; then
            echo -e "  [PASS] ${GREEN}YAML syntax is valid${RESET}"
        else
            echo -e "  [FAIL] ${RED}YAML syntax error detected${RESET}"
        fi
    fi

    local UNNAMED_TASKS
    UNNAMED_TASKS=$(grep -nE "^\s*-\s*(command|shell|copy|apt|yum):" "$PLAYBOOK" || true)
    if [[ -n "$UNNAMED_TASKS" ]]; then
        echo -e "  [WARN] ${YELLOW}Found unnamed task(s) - best practice requires a 'name:' field:${RESET}"
        echo "$UNNAMED_TASKS" | sed 's/^/         /'
    else
        echo -e "  [PASS] ${GREEN}All tasks are properly named${RESET}"
    fi

    if grep -inE "(password|secret|api_key|token):\s+[^\{]" "$PLAYBOOK" &>/dev/null; then
        echo -e "  [FAIL] ${RED}Potential hardcoded secret discovered! Use ansible-vault instead.${RESET}"
    else
        echo -e "  [PASS] ${GREEN}No obvious hardcoded plaintext credentials${RESET}"
    fi

    echo -e "\n${GREEN}✔ Linter execution finished.${RESET}"
}

print_banner
seed_sample_if_missing
lint_playbook
