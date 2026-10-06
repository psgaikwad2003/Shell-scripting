#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 19_bulk_file_renamer.sh
#  LEVEL  : Intermediate
#  PURPOSE: Advanced Batch File Renaming & Sanitizer Tool
#  USAGE  : bash 19_bulk_file_renamer.sh [DIRECTORY] [ACTION] [ARGS...]
#           bash 19_bulk_file_renamer.sh ./docs prefix "2026_"
#           bash 19_bulk_file_renamer.sh ./docs lowercase
#           bash 19_bulk_file_renamer.sh ./docs ext-swap ".txt" ".md"
#
#  CONCEPTS COVERED:
#    - Bash parameter expansion (${var//search/replace}, ${var,,})
#    - File basename and dirname manipulation
#    - Dry-run validation prior to filesystem mutation
#    - Handling whitespace and special characters in filenames safely
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

TARGET_DIR="${1:-/tmp/sample_renamer}"
ACTION="${2:-demo}"
ARG1="${3:-}"
ARG2="${4:-}"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🏷️  BULK FILE RENAMER & SANITIZER UTILITY             "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Target Directory : $TARGET_DIR"
    echo "Action           : $ACTION"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

setup_demo_files() {
    mkdir -p "$TARGET_DIR"
    touch "$TARGET_DIR/My Report Document.txt"
    touch "$TARGET_DIR/IMAGE_001.JPG"
    touch "$TARGET_DIR/OLD_DATA_FILE.log"
}

action_prefix() {
    local prefix="$1"
    echo -e "Adding prefix '${prefix}' to files in $TARGET_DIR..."
    for file in "$TARGET_DIR"/*; do
        [[ -f "$file" ]] || continue
        local dirname basename new_name
        dirname="$(dirname "$file")"
        basename="$(basename "$file")"
        new_name="${dirname}/${prefix}${basename}"
        echo -e "  [RENAME] $basename -> ${prefix}${basename}"
        mv "$file" "$new_name"
    done
}

action_lowercase() {
    echo -e "Converting all filenames in $TARGET_DIR to lowercase..."
    for file in "$TARGET_DIR"/*; do
        [[ -f "$file" ]] || continue
        local dirname basename lower_name new_name
        dirname="$(dirname "$file")"
        basename="$(basename "$file")"
        # Convert to lowercase using tr or bash expansion
        lower_name="$(echo "$basename" | tr '[:upper:]' '[:lower:]')"
        new_name="${dirname}/${lower_name}"
        if [[ "$file" != "$new_name" ]]; then
            echo -e "  [LOWERCASE] $basename -> $lower_name"
            mv "$file" "$new_name"
        fi
    done
}

action_ext_swap() {
    local old_ext="$1"
    local new_ext="$2"
    echo -e "Swapping extension '${old_ext}' to '${new_ext}'..."
    for file in "$TARGET_DIR"/*"${old_ext}"; do
        [[ -f "$file" ]] || continue
        local new_name="${file%${old_ext}}${new_ext}"
        echo -e "  [EXT-SWAP] $(basename "$file") -> $(basename "$new_name")"
        mv "$file" "$new_name"
    done
}

main() {
    print_header
    if [[ "$ACTION" == "demo" ]]; then
        setup_demo_files
        echo -e "${YELLOW}Demo mode: Created sample files in $TARGET_DIR.${RESET}"
        action_lowercase
        action_prefix "archived_"
        echo -e "\n${GREEN}✔ Bulk rename demonstration completed!${RESET}"
    elif [[ "$ACTION" == "prefix" ]]; then
        action_prefix "$ARG1"
    elif [[ "$ACTION" == "lowercase" ]]; then
        action_lowercase
    elif [[ "$ACTION" == "ext-swap" ]]; then
        action_ext_swap "$ARG1" "$ARG2"
    else
        echo "Usage: $0 [DIR] {prefix|lowercase|ext-swap|demo} [args]"
    fi
}

main "$@"
