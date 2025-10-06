#!/bin/bash

################################################################################
# Database Backup Script
# 
# This script creates backups of PostgreSQL databases used by NexusForge
# Platform services. It supports multiple databases, compression, and
# both local and cloud storage.
#
# Usage:
#   ./backup-database.sh [OPTIONS]
#
# Options:
#   -d, --database NAME   Database name (default: all databases)
#   -o, --output DIR      Output directory (default: ./backups)
#   -c, --compress        Compress backup with gzip
#   -u, --upload          Upload to GCS after backup
#   -b, --bucket NAME     GCS bucket name for upload
#   -r, --retention DAYS  Keep backups for N days (default: 30)
#   -h, --help           Show this help message
#
# Examples:
#   ./backup-database.sh                                    # Backup all databases
#   ./backup-database.sh -d nexusforge_python               # Backup single database
#   ./backup-database.sh -c -u -b my-backups                # Compress and upload
#   ./backup-database.sh -r 90                              # Keep backups for 90 days
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
DATABASE_NAME="${DATABASE_NAME:-all}"
OUTPUT_DIR="./backups"
COMPRESS=false
UPLOAD_TO_GCS=false
GCS_BUCKET=""
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--database)
            DATABASE_NAME="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -u|--upload)
            UPLOAD_TO_GCS=true
            shift
            ;;
        -b|--bucket)
            GCS_BUCKET="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if pg_dump is available
    if ! command -v pg_dump &> /dev/null; then
        log_error "pg_dump not found. Please install PostgreSQL client tools."
        exit 1
    fi
    
    # Check if docker is available (for Docker-based PostgreSQL)
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. Assuming PostgreSQL is running locally."
    fi
    
    # Check if gcloud is available (for GCS upload)
    if [ "$UPLOAD_TO_GCS" = true ] && ! command -v gcloud &> /dev/null; then
        log_error "gcloud not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    log_success "Prerequisites check completed"
}

get_database_list() {
    local databases=()
    
    if [ "$DATABASE_NAME" = "all" ]; then
        # Get all databases except system databases
        if docker ps --filter "name=postgres" --format "{{.Names}}" | grep -q "postgres"; then
            databases=($(docker exec postgres psql -U "$DB_USER" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" | xargs))
        else
            databases=($(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" | xargs))
        fi
    else
        databases=("$DATABASE_NAME")
    fi
    
    echo "${databases[@]}"
}

backup_database() {
    local db_name=$1
    local backup_file="${OUTPUT_DIR}/${db_name}_${TIMESTAMP}.sql"
    
    log_info "Backing up database: $db_name"
    
    # Perform backup
    if docker ps --filter "name=postgres" --format "{{.Names}}" | grep -q "postgres"; then
        # Docker-based PostgreSQL
        docker exec postgres pg_dump -U "$DB_USER" "$db_name" > "$backup_file" 2>/dev/null
    else
        # Local PostgreSQL
        PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$db_name" > "$backup_file" 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        log_success "Backup created: $backup_file (Size: $size)"
        
        # Compress if requested
        if [ "$COMPRESS" = true ]; then
            log_info "Compressing backup..."
            gzip "$backup_file"
            backup_file="${backup_file}.gz"
            local compressed_size=$(du -h "$backup_file" | cut -f1)
            log_success "Backup compressed: $backup_file (Size: $compressed_size)"
        fi
        
        # Upload to GCS if requested
        if [ "$UPLOAD_TO_GCS" = true ]; then
            upload_to_gcs "$backup_file"
        fi
        
        echo "$backup_file"
    else
        log_error "Failed to backup database: $db_name"
        return 1
    fi
}

upload_to_gcs() {
    local file=$1
    local filename=$(basename "$file")
    local gcs_path="gs://${GCS_BUCKET}/database-backups/$(date +%Y/%m/%d)/${filename}"
    
    log_info "Uploading to GCS: $gcs_path"
    
    if gsutil cp "$file" "$gcs_path"; then
        log_success "Uploaded to GCS: $gcs_path"
    else
        log_error "Failed to upload to GCS"
        return 1
    fi
}

cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local deleted_count=0
    
    # Clean local backups
    find "$OUTPUT_DIR" -name "*.sql*" -mtime +${RETENTION_DAYS} -type f | while read -r file; do
        rm -f "$file"
        deleted_count=$((deleted_count + 1))
        log_info "Deleted old backup: $(basename "$file")"
    done
    
    # Clean GCS backups if applicable
    if [ "$UPLOAD_TO_GCS" = true ] && [ -n "$GCS_BUCKET" ]; then
        local cutoff_date=$(date -u -d "${RETENTION_DAYS} days ago" +%Y-%m-%d 2>/dev/null || date -u -v-${RETENTION_DAYS}d +%Y-%m-%d)
        log_info "Cleaning GCS backups older than $cutoff_date..."
        
        gsutil ls "gs://${GCS_BUCKET}/database-backups/**" 2>/dev/null | while read -r object; do
            local object_date=$(gsutil stat "$object" | grep "Creation time" | awk '{print $3}')
            if [[ "$object_date" < "$cutoff_date" ]]; then
                gsutil rm "$object"
                log_info "Deleted old GCS backup: $object"
            fi
        done
    fi
    
    if [ $deleted_count -gt 0 ]; then
        log_success "Cleanup completed: $deleted_count files deleted"
    else
        log_info "No old backups to clean up"
    fi
}

generate_backup_metadata() {
    local backup_files=("$@")
    local metadata_file="${OUTPUT_DIR}/backup_${TIMESTAMP}.json"
    
    cat > "$metadata_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_id": "${TIMESTAMP}",
  "databases": [
EOF
    
    local first=true
    for file in "${backup_files[@]}"; do
        local db_name=$(basename "$file" | sed 's/_[0-9]*\.sql.*//')
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$metadata_file"
        fi
        
        cat >> "$metadata_file" <<EOF
    {
      "name": "$db_name",
      "file": "$(basename "$file")",
      "size_bytes": $size,
      "compressed": $([ "$COMPRESS" = true ] && echo "true" || echo "false")
    }
EOF
    done
    
    cat >> "$metadata_file" <<EOF

  ],
  "retention_days": $RETENTION_DAYS,
  "upload_to_gcs": $([ "$UPLOAD_TO_GCS" = true ] && echo "true" || echo "false"),
  "gcs_bucket": "${GCS_BUCKET}"
}
EOF
    
    log_success "Metadata saved: $metadata_file"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║       NexusForge Platform - Database Backup Script            ║"
    echo "║       Timestamp: $(date '+%Y-%m-%d %H:%M:%S')                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check prerequisites
    check_prerequisites
    
    # Get list of databases to backup
    local databases=($(get_database_list))
    
    if [ ${#databases[@]} -eq 0 ]; then
        log_error "No databases found to backup"
        exit 1
    fi
    
    log_info "Found ${#databases[@]} database(s) to backup: ${databases[*]}"
    
    # Perform backups
    local backup_files=()
    local success_count=0
    local fail_count=0
    
    for db in "${databases[@]}"; do
        if backup_file=$(backup_database "$db"); then
            backup_files+=("$backup_file")
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done
    
    # Generate metadata
    if [ ${#backup_files[@]} -gt 0 ]; then
        generate_backup_metadata "${backup_files[@]}"
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Summary
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Backup Summary${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    log_success "Successfully backed up: $success_count database(s)"
    if [ $fail_count -gt 0 ]; then
        log_error "Failed to backup: $fail_count database(s)"
    fi
    log_info "Backup location: $OUTPUT_DIR"
    if [ "$UPLOAD_TO_GCS" = true ]; then
        log_info "GCS bucket: gs://${GCS_BUCKET}/database-backups/"
    fi
    log_info "Retention period: $RETENTION_DAYS days"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    if [ $fail_count -gt 0 ]; then
        exit 1
    fi
    
    exit 0
}

# Run main function
main

exit 0
