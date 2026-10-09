#!/usr/bin/env bash
# =============================================================================
# Script: 05_backup_rotator.sh
# Problem Statement: Automate directory backups with Gzip compression and enforce rolling retention policies by pruning archives older than a specified duration.
# =============================================================================

set -euo pipefail

SOURCE_DIR="${HOME}/data_to_backup"
BACKUP_DIR="${HOME}/backups"
RETENTION_DAYS=7
LOG_FILE="${REPORT_LOG_FILE:-}"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

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
    echo -e "${CYAN}[INFO]${RESET} [${ts}] ${msg}"
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

print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "============================================================"
    echo "       🗄️   AUTOMATED BACKUP & RETENTION ROTATOR              "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Source Directory : $SOURCE_DIR"
    echo "Backup Directory : $BACKUP_DIR"
    echo "Retention Policy : Keep backups for $RETENTION_DAYS day(s)"
    echo "Timestamp        : $TIMESTAMP"
    [[ -n "$LOG_FILE" ]] && echo "Log Target       : $LOG_FILE"
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
    local target_archive="${BACKUP_DIR}/backup_$(basename "$SOURCE_DIR")_${TIMESTAMP}.tar.gz"
    log_info "Starting compression for: $SOURCE_DIR"

    local start_time end_time duration file_size
    start_time="$(date +%s)"

    tar --exclude='*.tmp' --exclude='.git' -czf "$target_archive" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

    end_time="$(date +%s)"
    duration=$((end_time - start_time))

    if [[ -f "$target_archive" ]]; then
        file_size="$(du -h "$target_archive" 2>/dev/null | cut -f1 || echo "unknown")"
        log_success "Backup archive created: $target_archive"
        log_success "Archive size: $file_size (took ${duration}s)"
    else
        log_error "Failed to generate archive: $target_archive"
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
            log_info "  - Removing expired archive: $file"
            rm -f "$file"
        done <<< "$old_backups"
        log_success "Old backup rotation completed."
    fi
}

list_current_backups() {
    echo -e "\n${BOLD}Current Backups in Repository:${RESET}"
    local count=0
    for archive in "$BACKUP_DIR"/*.tar.gz; do
        if [[ -f "$archive" ]]; then
            ls -lh "$archive"
            ((count++))
        fi
    done
    if (( count == 0 )); then
        echo "No backups present."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [SOURCE_DIR] [BACKUP_DIR] [RETENTION_DAYS]"
                echo "Options:"
                echo "  -s, --source DIR                     Directory to back up"
                echo "  -b, --backup-dir DIR                 Target backup directory"
                echo "  -r, --retention DAYS                 Number of days to keep backups (default: 7)"
                echo "  -o, --output FILE, --log-file FILE   Write execution logs to specified file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    if [[ -z "${SOURCE_DIR_SET:-}" ]]; then
                        SOURCE_DIR="$1"
                        SOURCE_DIR_SET=1
                    elif [[ -z "${BACKUP_DIR_SET:-}" ]]; then
                        BACKUP_DIR="$1"
                        BACKUP_DIR_SET=1
                    elif [[ -z "${RETENTION_SET:-}" ]]; then
                        RETENTION_DAYS="$1"
                        RETENTION_SET=1
                    fi
                    shift
                else
                    log_error "Unknown option: $1"
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

    print_banner
    validate_inputs
    create_backup
    rotate_old_backups
    list_current_backups
    log_success "Backup workflow completed successfully!"
}

main "$@"
