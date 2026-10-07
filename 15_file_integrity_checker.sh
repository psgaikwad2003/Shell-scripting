#!/usr/bin/env bash
# =============================================================================
# Script: 15_file_integrity_checker.sh
# Problem Statement: Generate and compare SHA256 cryptographic file hashes against baselines to detect unauthorized tampering or corruption.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

ACTION="${1:-generate}"
TARGET_DIR="${2:-/tmp/sample_project}"
HASH_DB="${3:-/tmp/file_hashes.sha256}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🛡️  FILE INTEGRITY & TAMPER DETECTION SYSTEM         "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Action     : $ACTION"
    echo "Target Dir : $TARGET_DIR"
    echo "Database   : $HASH_DB"
    echo "Timestamp  : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

prepare_sample_dir() {
    if [[ ! -d "$TARGET_DIR" ]]; then
        mkdir -p "$TARGET_DIR"
        echo "config_version=1.0" > "$TARGET_DIR/settings.conf"
        echo "authorized_keys_entry" > "$TARGET_DIR/auth.txt"
    fi
}

calc_hash() {
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file"
    else
        shasum -a 256 "$file"
    fi
}

generate_baseline() {
    prepare_sample_dir
    echo -e "Computing baseline hashes for all files in: ${BOLD}$TARGET_DIR${RESET}..."

    local count=0
    : > "$HASH_DB"
    while IFS= read -r -d '' file; do
        calc_hash "$file" >> "$HASH_DB"
        ((count++))
    done < <(find "$TARGET_DIR" -type f -print0)

    echo -e "${GREEN}✔ Baseline generated for $count file(s).${RESET}"
    echo -e "Saved hash baseline to: ${BOLD}$HASH_DB${RESET}"
}

verify_integrity() {
    if [[ ! -f "$HASH_DB" ]]; then
        echo -e "${RED}[ERROR] Hash database '$HASH_DB' not found. Run 'generate' first.${RESET}"
        return 1
    fi

    echo -e "Verifying filesystem files against: ${BOLD}$HASH_DB${RESET}...\n"
    local corrupted=0
    local matched=0

    while read -r expected_hash filepath; do
        if [[ ! -f "$filepath" ]]; then
            echo -e "${RED}[MISSING]${RESET} File deleted or moved: $filepath"
            ((corrupted++))
            continue
        fi

        local current_hash
        current_hash=$(calc_hash "$filepath" | cut -d' ' -f1)

        if [[ "$expected_hash" == "$current_hash" ]]; then
            echo -e "${GREEN}[OK]${RESET} Integrity verified: $filepath"
            ((matched++))
        else
            echo -e "${RED}${BOLD}[TAMPERED]${RESET} File modified! $filepath"
            ((corrupted++))
        fi
    done < "$HASH_DB"

    echo "------------------------------------------------------------"
    if (( corrupted == 0 )); then
        echo -e "${GREEN}${BOLD}✔ All $matched file(s) matched baseline. No tampering detected.${RESET}"
    else
        echo -e "${RED}${BOLD}⚠️  Alert: $corrupted integrity violation(s) found!${RESET}"
    fi
}

main() {
    print_header
    case "$ACTION" in
        generate) generate_baseline ;;
        verify)   verify_integrity ;;
        *)
            echo "Usage: $0 [generate|verify] [TARGET_DIR] [HASH_DB]"
            exit 1
            ;;
    esac
}

main "$@"
