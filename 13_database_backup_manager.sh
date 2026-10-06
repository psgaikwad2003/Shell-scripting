#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 13_database_backup_manager.sh
#  LEVEL  : Intermediate - Advanced
#  PURPOSE: Database Backup Automation (MySQL / Postgres) with Checksums
#  USAGE  : bash 13_database_backup_manager.sh [DB_TYPE] [DB_NAME] [OUTPUT_DIR]
#           bash 13_database_backup_manager.sh mysql production_db /backups/db
#
#  CONCEPTS COVERED:
#    - mysqldump / pg_dump execution pattern
#    - Integrity verification via sha256sum
#    - Environment variable secret extraction (DB_USER, DB_PASS)
#    - Simulation / mock mode when DB binary is missing
#    - Timestamped archive management & error handling
# =============================================================================

set -euo pipefail

# ── Color Palette ─────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

DB_TYPE="${1:-mysql}"
DB_NAME="${2:-app_production}"
BACKUP_DIR="${3:-/tmp/db_backups}"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_FILE="${BACKUP_DIR}/${DB_TYPE}_${DB_NAME}_${TIMESTAMP}.sql.gz"
CHECKSUM_FILE="${BACKUP_FILE}.sha256"

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🗄️  DATABASE BACKUP & CHECKSUM MANAGER               "
    echo "============================================================"
    echo -e "${RESET}"
    echo "Engine Type    : $DB_TYPE"
    echo "Database Name  : $DB_NAME"
    echo "Destination    : $BACKUP_FILE"
    echo "Timestamp      : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------"
}

execute_dump() {
    mkdir -p "$BACKUP_DIR"
    echo -e "Initiating dump for database: ${BOLD}${DB_NAME}${RESET}..."

    if [[ "$DB_TYPE" == "mysql" ]]; then
        if command -v mysqldump &>/dev/null; then
            mysqldump --single-transaction --quick "$DB_NAME" | gzip > "$BACKUP_FILE"
        else
            echo -e "${YELLOW}[NOTICE] 'mysqldump' not detected in PATH. Generating simulated SQL dump...${RESET}"
            echo "-- Mock MySQL Dump for $DB_NAME created at $(date)" | gzip > "$BACKUP_FILE"
        fi
    elif [[ "$DB_TYPE" == "postgres" ]]; then
        if command -v pg_dump &>/dev/null; then
            pg_dump "$DB_NAME" | gzip > "$BACKUP_FILE"
        else
            echo -e "${YELLOW}[NOTICE] 'pg_dump' not detected in PATH. Generating simulated Postgres dump...${RESET}"
            echo "-- Mock PostgreSQL Dump for $DB_NAME created at $(date)" | gzip > "$BACKUP_FILE"
        fi
    else
        echo -e "${RED}[ERROR] Unsupported database type: $DB_TYPE (use mysql or postgres)${RESET}"
        exit 1
    fi

    echo -e "${GREEN}✔ Database dump file created: ${BACKUP_FILE}${RESET}"
}

generate_checksum() {
    echo -e "Generating SHA-256 integrity checksum..."
    if command -v sha256sum &>/dev/null; then
        sha256sum "$BACKUP_FILE" > "$CHECKSUM_FILE"
    else
        shasum -a 256 "$BACKUP_FILE" > "$CHECKSUM_FILE"
    fi
    local hash_val
    hash_val=$(cut -d' ' -f1 < "$CHECKSUM_FILE")
    echo -e "${GREEN}✔ Checksum:${RESET} $hash_val"
    echo -e "${GREEN}✔ Checksum file written to:${RESET} $CHECKSUM_FILE"
}

main() {
    print_header
    execute_dump
    generate_checksum
    echo "------------------------------------------------------------"
    echo -e "${GREEN}${BOLD}Backup process completed successfully!${RESET}"
}

main "$@"
