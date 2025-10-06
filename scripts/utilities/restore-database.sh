#!/bin/bash

################################################################################
# Database Restore Script
# 
# This script restores PostgreSQL databases from backups created by the
# backup-database.sh script. It supports both local and GCS-stored backups.
#
# Usage:
#   ./restore-database.sh [OPTIONS]
#
# Options:
#   -f, --file PATH       Backup file to restore (required)
#   -d, --database NAME   Target database name (default: from filename)
#   -s, --source gcs|local Source location (default: local)
#   -b, --bucket NAME     GCS bucket name (required if source=gcs)
#   -y, --yes            Skip confirmation prompt
#   --drop               Drop existing database before restore
#   -h, --help           Show this help message
#
# Examples:
#   ./restore-database.sh -f backups/nexusforge_python_20231006.sql
#   ./restore-database.sh -f nexusforge_python_20231006.sql.gz -s gcs -b my-backups
#   ./restore-database.sh -f backup.sql -d nexusforge_python --drop -y
################################################################################

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
BACKUP_FILE=""
DATABASE_NAME=""
SOURCE="local"
GCS_BUCKET=""
AUTO_YES=false
DROP_DATABASE=false
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"
TEMP_DIR="/tmp/nexusforge_restore_$$"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            BACKUP_FILE="$2"
            shift 2
            ;;
        -d|--database)
            DATABASE_NAME="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE="$2"
            shift 2
            ;;
        -b|--bucket)
            GCS_BUCKET="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        --drop)
            DROP_DATABASE=true
            shift
            ;;
        -h|--help)
            head -n 30 "$0" | tail -n +2 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_info "Cleaned up temporary files"
    fi
}

trap cleanup EXIT

validate_inputs() {
    if [ -z "$BACKUP_FILE" ]; then
        log_error "Backup file is required. Use -f or --file option."
        exit 1
    fi
    
    if [ "$SOURCE" = "gcs" ] && [ -z "$GCS_BUCKET" ]; then
        log_error "GCS bucket is required when source is 'gcs'. Use -b or --bucket option."
        exit 1
    fi
    
    # Extract database name from filename if not provided
    if [ -z "$DATABASE_NAME" ]; then
        DATABASE_NAME=$(basename "$BACKUP_FILE" | sed 's/_[0-9]*\.sql.*//')
        log_info "Extracted database name from filename: $DATABASE_NAME"
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        log_error "psql not found. Please install PostgreSQL client tools."
        exit 1
    fi
    
    # Check if docker is available (for Docker-based PostgreSQL)
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. Assuming PostgreSQL is running locally."
    fi
    
    # Check if gcloud is available (for GCS download)
    if [ "$SOURCE" = "gcs" ] && ! command -v gcloud &> /dev/null; then
        log_error "gcloud not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    log_success "Prerequisites check completed"
}

download_from_gcs() {
    local gcs_path="gs://${GCS_BUCKET}/database-backups/**/${BACKUP_FILE}"
    local local_file="${TEMP_DIR}/$(basename "$BACKUP_FILE")"
    
    log_info "Searching for backup in GCS..."
    
    # Find the backup file in GCS
    local found_file=$(gsutil ls "$gcs_path" 2>/dev/null | head -n 1)
    
    if [ -z "$found_file" ]; then
        log_error "Backup file not found in GCS: $BACKUP_FILE"
        exit 1
    fi
    
    log_info "Downloading from GCS: $found_file"
    
    if gsutil cp "$found_file" "$local_file"; then
        log_success "Downloaded successfully"
        echo "$local_file"
    else
        log_error "Failed to download from GCS"
        exit 1
    fi
}

decompress_if_needed() {
    local file=$1
    
    if [[ "$file" == *.gz ]]; then
        log_info "Decompressing backup file..."
        gunzip "$file"
        local decompressed="${file%.gz}"
        log_success "Decompressed: $decompressed"
        echo "$decompressed"
    else
        echo "$file"
    fi
}

check_database_exists() {
    local db_name=$1
    
    if docker ps --filter "name=postgres" --format "{{.Names}}" | grep -q "postgres"; then
        docker exec postgres psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$db_name"
    else
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$db_name"
    fi
}

drop_database() {
    local db_name=$1
    
    log_warning "Dropping existing database: $db_name"
    
    if docker ps --filter "name=postgres" --format "{{.Names}}" | grep -q "postgres"; then
        docker exec postgres psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS $db_name;" 2>/dev/null
    else
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $db_name;" 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        log_success "Database dropped successfully"
    else
        log_error "Failed to drop database"
        exit 1
    fi
}

create_database() {
    local db_name=$1
    
    log_info "Creating database: $db_name"
    
    if docker ps --filter "name=postgres" --format "{{.Names}}" | grep -q "postgres"; then
        docker exec postgres psql -U "$DB_USER" -c "CREATE DATABASE $db_name;" 2>/dev/null
    else
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $db_name;" 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        log_success "Database created successfully"
    else
        log_error "Failed to create database"
        exit 1
    fi
}

restore_database() {
    local backup_file=$1
    local db_name=$2
    
    log_info "Restoring database: $db_name from $backup_file"
    
    local start_time=$(date +%s)
    
    if docker ps --filter "name=postgres" --format "{{.Names}}" | grep -q "postgres"; then
        docker exec -i postgres psql -U "$DB_USER" "$db_name" < "$backup_file" 2>/dev/null
    else
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$db_name" < "$backup_file" 2>/dev/null
    fi
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        log_success "Database restored successfully in ${duration}s"
        return 0
    else
        log_error "Failed to restore database"
        return 1
    fi
}

get_database_info() {
    local db_name=$1
    
    log_info "Database information:"
    
    if docker ps --filter "name=postgres" --format "{{.Names}}" | grep -q "postgres"; then
        local size=$(docker exec postgres psql -U "$DB_USER" -t -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" | xargs)
        local tables=$(docker exec postgres psql -U "$DB_USER" "$db_name" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
        
        echo -e "  Database: ${BOLD}$db_name${NC}"
        echo -e "  Size: ${BOLD}$size${NC}"
        echo -e "  Tables: ${BOLD}$tables${NC}"
    fi
}

confirm_restore() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    
    echo ""
    echo -e "${BOLD}${YELLOW}WARNING: This will restore the database and may overwrite existing data!${NC}"
    echo -e "Database: ${BOLD}$DATABASE_NAME${NC}"
    echo -e "Backup file: ${BOLD}$BACKUP_FILE${NC}"
    
    if [ "$DROP_DATABASE" = true ]; then
        echo -e "${RED}The existing database will be DROPPED and recreated!${NC}"
    fi
    
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restore cancelled by user"
        exit 0
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║      NexusForge Platform - Database Restore Script            ║"
    echo "║      Timestamp: $(date '+%Y-%m-%d %H:%M:%S')                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Validate inputs
    validate_inputs
    
    # Check prerequisites
    check_prerequisites
    
    # Prepare backup file
    local restore_file="$BACKUP_FILE"
    
    if [ "$SOURCE" = "gcs" ]; then
        restore_file=$(download_from_gcs)
    elif [ ! -f "$restore_file" ]; then
        log_error "Backup file not found: $restore_file"
        exit 1
    fi
    
    # Decompress if needed
    restore_file=$(decompress_if_needed "$restore_file")
    
    # Check if database exists
    local db_exists=false
    if check_database_exists "$DATABASE_NAME"; then
        db_exists=true
        log_warning "Database '$DATABASE_NAME' already exists"
    fi
    
    # Confirm restore
    confirm_restore
    
    # Handle existing database
    if [ "$db_exists" = true ]; then
        if [ "$DROP_DATABASE" = true ]; then
            drop_database "$DATABASE_NAME"
            create_database "$DATABASE_NAME"
        else
            log_warning "Restoring into existing database (data may be duplicated)"
        fi
    else
        create_database "$DATABASE_NAME"
    fi
    
    # Perform restore
    if restore_database "$restore_file" "$DATABASE_NAME"; then
        # Get database info
        get_database_info "$DATABASE_NAME"
        
        # Summary
        echo ""
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}Restore Summary${NC}"
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        log_success "Database restored successfully"
        echo -e "  Database: ${BOLD}$DATABASE_NAME${NC}"
        echo -e "  Backup file: ${BOLD}$BACKUP_FILE${NC}"
        echo -e "  Source: ${BOLD}$SOURCE${NC}"
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        
        exit 0
    else
        log_error "Restore failed"
        exit 1
    fi
}

# Run main function
main

exit 0
