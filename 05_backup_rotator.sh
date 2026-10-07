#!/usr/bin/env bash
# =============================================================================
# Script: 05_backup_rotator.sh
# Problem Statement: Automate directory backups with Gzip compression and enforce rolling retention policies by pruning archives older than a specified duration.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

log_info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

SOURCE_DIR="${1:-$HOME/data_to_backup}"
BACKUP_DIR="${2:-$HOME/backups}"
RETENTION_DAYS="${3:-7}"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
ARCHIVE_NAME="backup_$(basename "$SOURCE_DIR")_${TIMESTAMP}.tar.gz"
TARGET_ARCHIVE="${BACKUP_DIR}/${ARCHIVE_NAME}"

print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "============================================================"
    echo "       🗄️  AUTOMATED BACKUP & RETENTION ROTATOR              "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Source Directory : $SOURCE_DIR"
    echo "Backup Directory : $BACKUP_DIR"
    echo "Retention Policy : Keep backups for $RETENTION_DAYS day(s)"
    echo "Timestamp        : $TIMESTAMP"
    echo "------------------------------------------------------------"
}

validate_inputs() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_warn "Source directory '$SOURCE_DIR' does not exist."
        log_info "Creating dummy sample files in '$SOURCE_DIR' for demonstration..."
        mkdir -p "$SOURCE_DIR"
        echo "Sample data 1 created at $(date)" > "$SOURCE_DIR/file1.txt"
        echo "Sample data 2 created at $(date)" > "$SOURCE_DIR/file2.txt"
        log_success "Sample source directory prepared."
    fi

    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "Backup directory '$BACKUP_DIR' does not exist. Creating it..."
        mkdir -p "$BACKUP_DIR"
    fi
}

create_backup() {
    log_info "Starting compression for: $SOURCE_DIR"

    local start_time
    start_time="$(date +%s)"

    tar --exclude='*.tmp' --exclude='.git' -czf "$TARGET_ARCHIVE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))

    if [[ -f "$TARGET_ARCHIVE" ]]; then
        local file_size
        file_size="$(du -h "$TARGET_ARCHIVE" | cut -f1)"
        log_success "Backup archive created: $TARGET_ARCHIVE"
        log_success "Archive size: $file_size (took ${duration}s)"
    else
        log_error "Failed to generate archive: $TARGET_ARCHIVE"
        exit 1
    fi
}

rotate_old_backups() {
    log_info "Checking for backups older than $RETENTION_DAYS day(s)..."

    local old_backups
    old_backups="$(find "$BACKUP_DIR" -maxdepth 1 -name "backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" 2>/dev/null || true)"

    if [[ -z "$old_backups" ]]; then
        log_info "No expired backups found. Everything is within the retention period."
    else
        log_warn "Found expired backups to remove:"
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            echo "  - Removing: $file"
            rm -f "$file"
        done <<< "$old_backups"
        log_success "Old backup rotation completed."
    fi
}

list_current_backups() {
    echo -e "\n${BOLD}Current Backups in Repository:${RESET}"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups present."
}

main() {
    print_banner
    validate_inputs
    create_backup
    rotate_old_backups
    list_current_backups
    echo -e "\n${GREEN}${BOLD}✔ Backup workflow completed successfully!${RESET}"
}

main "$@"
