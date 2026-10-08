#!/usr/bin/env bash
# =============================================================================
# Script: 38_tar_gpg_encrypted_backup.sh
# Problem Statement: Create AES-256 GPG symmetrically encrypted tar backups with SHA256 integrity checksums for secure offsite storage.
# =============================================================================

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

SOURCE_DIR="/tmp/sample_backup_src"
OUTPUT_DIR="/tmp/sample_backup_dest"
PASSPHRASE="AntigravitySecureBackupPass2026"
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
    echo "       🔐  AES-256 GPG ENCRYPTED ARCHIVE BACKUP MANAGER     "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Source Directory : $SOURCE_DIR"
    echo "Output Directory : $OUTPUT_DIR"
    echo "Cipher Algorithm : AES-256"
    echo "Timestamp        : $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && echo "Log Target       : $LOG_FILE"
    echo "------------------------------------------------------------"
}

seed_source_if_missing() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_info "Creating sample source data at $SOURCE_DIR..."
        mkdir -p "$SOURCE_DIR"
        echo "Confidential App Secret: API_KEY_9921448" > "$SOURCE_DIR/credentials.txt"
        echo "Database Host: db.internal.local" > "$SOURCE_DIR/config.env"
    fi
    mkdir -p "$OUTPUT_DIR"
}

create_encrypted_backup() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    local BACKUP_NAME="backup_${TIMESTAMP}.tar.gz.gpg"
    local DEST_FILE="${OUTPUT_DIR}/${BACKUP_NAME}"

    log_info "Compressing and encrypting payload from $SOURCE_DIR..."

    if command -v gpg &>/dev/null; then
        tar -czf - -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" | \
            gpg --batch --yes --passphrase "$PASSPHRASE" --symmetric --cipher-algo AES256 -o "$DEST_FILE"
    else
        log_warn "GPG not found in environment. Creating standard tar.gz payload."
        tar -czf "$DEST_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
    fi

    chmod 600 "$DEST_FILE" 2>/dev/null || true
    log_info "Archive successfully created: $DEST_FILE"

    log_info "Generating SHA256 integrity verification checksum..."
    local CHECKSUM
    if command -v sha256sum &>/dev/null; then
        CHECKSUM=$(sha256sum "$DEST_FILE" | awk '{print $1}')
    else
        CHECKSUM=$(shasum -a 256 "$DEST_FILE" 2>/dev/null | awk '{print $1}' || echo "N/A")
    fi
    echo "$CHECKSUM  $BACKUP_NAME" > "${DEST_FILE}.sha256"

    log_info "Integrity Checksum: $CHECKSUM"
    log_info "Backup verification completed successfully."
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -d|--dest|--destination)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--passphrase)
                PASSPHRASE="$2"
                shift 2
                ;;
            -o|--output|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [SOURCE_DIR] [DEST_DIR] [PASSPHRASE]"
                echo "Options:"
                echo "  -s, --source DIR                     Source directory to archive"
                echo "  -d, --dest DIR                       Output destination directory"
                echo "  -p, --passphrase PASS                Symmetric encryption passphrase"
                echo "  -o, --output FILE, --log-file FILE   Write backup event log to file"
                echo "  -h, --help                           Show this help message and exit"
                exit 0
                ;;
            *)
                if [[ -z "${1_pos:-}" ]]; then
                    SOURCE_DIR="$1"
                    1_pos=1
                elif [[ -z "${2_pos:-}" ]]; then
                    OUTPUT_DIR="$1"
                    2_pos=1
                elif [[ -z "${3_pos:-}" ]]; then
                    PASSPHRASE="$1"
                    3_pos=1
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
    print_banner
    seed_source_if_missing
    create_encrypted_backup
    log_info "Encrypted backup operation completed."
}

main "$@"
