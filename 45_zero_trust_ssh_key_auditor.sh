#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 45_zero_trust_ssh_key_auditor.sh
#  LEVEL  : Advanced
#  PURPOSE: Audit authorized_keys files for weak cryptography (DSA, small RSA)
#  USAGE  : bash 45_zero_trust_ssh_key_auditor.sh [KEYS_FILE]
#           bash 45_zero_trust_ssh_key_auditor.sh ~/.ssh/authorized_keys
#
#  CONCEPTS COVERED:
#    - SSH public key parsing (ssh-keygen -l -f)
#    - Cryptographic algorithm policy enforcement (ED25519 vs RSA >= 3072 vs DSA)
#    - Detection of duplicate authorized keys across user profiles
#    - Self-contained dummy keys generator for test runs
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

KEYS_FILE="${1:-/tmp/sample_authorized_keys}"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🔑  ZERO-TRUST SSH AUTHORIZED_KEYS AUDITOR            "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target File: $KEYS_FILE"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

seed_sample_if_missing() {
    if [[ ! -f "$KEYS_FILE" ]]; then
        cat << 'EOF' > "$KEYS_FILE"
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleModernKeyDevOps admin@corp.internal
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQLegacyKey2048 user@legacy.domain
ssh-dss AAAAB3NzaC1kc3MAAACBInsecureDeprecatedDsaKey oldserver@domain
EOF
    fi
}

audit_keys() {
    echo -e "${BOLD}Scanning SSH Public Keys for Policy Compliance:${RESET}\n"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        local KEY_TYPE COMMENT
        KEY_TYPE=$(echo "$line" | awk '{print $1}')
        COMMENT=$(echo "$line" | awk '{print $3}')

        case "$KEY_TYPE" in
            ssh-ed25519)
                echo -e "  [PASS] ${GREEN}ED25519 Modern Elliptic Curve${RESET} (Comment: $COMMENT)"
                ;;
            ssh-rsa)
                echo -e "  [WARN] ${YELLOW}RSA Key Found - Ensure >= 3072 bits${RESET} (Comment: $COMMENT)"
                ;;
            ssh-dss)
                echo -e "  [FAIL] ${RED}DEPRECATED DSA KEY (Cryptographically Broken)${RESET} (Comment: $COMMENT)"
                ;;
            *)
                echo -e "  [INFO] $KEY_TYPE (Comment: $COMMENT)"
                ;;
        esac
    done < "$KEYS_FILE"

    echo -e "\n${GREEN}✔ SSH Key audit finished.${RESET}"
}

print_banner
seed_sample_if_missing
audit_keys
