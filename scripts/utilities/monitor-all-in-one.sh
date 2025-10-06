#!/bin/bash

################################################################################
# All-in-One Monitoring Script
# 
# This script monitors all services, databases, and infrastructure components
# in the NexusForge Platform. It provides real-time status, resource usage,
# and health checks for all components.
#
# Usage:
#   ./monitor-all-in-one.sh [OPTIONS]
#
# Options:
#   -c, --continuous    Run continuously with refresh interval
#   -i, --interval SEC  Refresh interval in seconds (default: 5)
#   -j, --json         Output in JSON format
#   -h, --help         Show this help message
#
# Examples:
#   ./monitor-all-in-one.sh                    # Single check
#   ./monitor-all-in-one.sh -c                 # Continuous monitoring
#   ./monitor-all-in-one.sh -c -i 10           # 10 second refresh
#   ./monitor-all-in-one.sh -j                 # JSON output
################################################################################

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
CONTINUOUS=false
INTERVAL=5
JSON_OUTPUT=false
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--continuous)
            CONTINUOUS=true
            shift
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -j|--json)
            JSON_OUTPUT=true
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

print_header() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "\n${BOLD}${BLUE}=====================================${NC}"
        echo -e "${BOLD}${BLUE}$1${NC}"
        echo -e "${BOLD}${BLUE}=====================================${NC}"
    fi
}

print_success() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓${NC} $1"
    fi
}

print_error() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗${NC} $1"
    fi
}

print_warning() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}⚠${NC} $1"
    fi
}

print_info() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${CYAN}ℹ${NC} $1"
    fi
}

################################################################################
# Check Functions
################################################################################

check_docker_services() {
    print_header "Docker Services Status"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        return 1
    fi
    
    if ! docker ps &> /dev/null; then
        print_error "Docker daemon not running"
        return 1
    fi
    
    local services=("postgres" "redis" "python-api" "nodejs-api" "go-api" "nginx" "prometheus" "grafana")
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" --format "{{.Names}}" | grep -q "$service"; then
            local status=$(docker inspect --format='{{.State.Status}}' "$service" 2>/dev/null)
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "none")
            
            if [ "$status" = "running" ]; then
                if [ "$health" = "healthy" ]; then
                    print_success "$service: Running & Healthy"
                elif [ "$health" = "unhealthy" ]; then
                    print_error "$service: Running but Unhealthy"
                else
                    print_warning "$service: Running (no health check)"
                fi
            else
                print_error "$service: $status"
            fi
        else
            print_error "$service: Not found"
        fi
    done
}

check_service_health() {
    print_header "Service Health Checks"
    
    local services=(
        "Python API:http://localhost:8000/health"
        "Node.js API:http://localhost:3000/health"
        "Go API:http://localhost:8080/health"
        "Prometheus:http://localhost:9090/-/healthy"
        "Grafana:http://localhost:3001/api/health"
    )
    
    for service_url in "${services[@]}"; do
        IFS=':' read -r name url <<< "$service_url"
        
        if curl -sf "$url" > /dev/null 2>&1; then
            print_success "$name: Healthy"
        else
            print_error "$name: Unreachable or Unhealthy"
        fi
    done
}

check_database_status() {
    print_header "Database Status"
    
    # PostgreSQL
    if docker exec postgres psql -U postgres -c "SELECT version();" &> /dev/null; then
        local db_size=$(docker exec postgres psql -U postgres -t -c "SELECT pg_size_pretty(pg_database_size('postgres'));" | xargs)
        local connections=$(docker exec postgres psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" | xargs)
        print_success "PostgreSQL: Running (Size: $db_size, Connections: $connections)"
    else
        print_error "PostgreSQL: Not accessible"
    fi
    
    # Redis
    if docker exec redis redis-cli ping &> /dev/null; then
        local redis_memory=$(docker exec redis redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
        local redis_keys=$(docker exec redis redis-cli DBSIZE | cut -d: -f2 | tr -d '\r')
        print_success "Redis: Running (Memory: $redis_memory, Keys: $redis_keys)"
    else
        print_error "Redis: Not accessible"
    fi
}

check_resource_usage() {
    print_header "Resource Usage"
    
    # CPU Usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    if [ -n "$cpu_usage" ]; then
        print_info "CPU Usage: ${cpu_usage}%"
    fi
    
    # Memory Usage
    local mem_info=$(vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free:\s+(\d+)/ and printf("%.2f", $1 * $size / 1073741824);')
    if [ -n "$mem_info" ]; then
        print_info "Free Memory: ${mem_info} GB"
    fi
    
    # Disk Usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    print_info "Disk Usage: $disk_usage"
    
    # Docker Container Resources
    if command -v docker &> /dev/null && docker ps &> /dev/null; then
        echo ""
        print_info "Container Resource Usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -n 10
    fi
}

check_logs_for_errors() {
    print_header "Recent Errors in Logs"
    
    local services=("python-api" "nodejs-api" "go-api")
    local error_count=0
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" --format "{{.Names}}" | grep -q "$service"; then
            local errors=$(docker logs --since 5m "$service" 2>&1 | grep -i "error" | wc -l | xargs)
            if [ "$errors" -gt 0 ]; then
                print_warning "$service: $errors errors in last 5 minutes"
                error_count=$((error_count + errors))
            fi
        fi
    done
    
    if [ $error_count -eq 0 ]; then
        print_success "No errors found in recent logs"
    fi
}

check_network_connectivity() {
    print_header "Network Connectivity"
    
    # Check internet connectivity
    if ping -c 1 google.com &> /dev/null; then
        print_success "Internet: Connected"
    else
        print_error "Internet: Disconnected"
    fi
    
    # Check GCP connectivity
    if [ -n "$PROJECT_ID" ]; then
        if gcloud projects describe "$PROJECT_ID" &> /dev/null; then
            print_success "GCP: Connected (Project: $PROJECT_ID)"
        else
            print_error "GCP: Cannot access project $PROJECT_ID"
        fi
    fi
    
    # Check Docker network
    if docker network inspect nexusforge &> /dev/null; then
        print_success "Docker Network: nexusforge exists"
    else
        print_warning "Docker Network: nexusforge not found"
    fi
}

check_cloud_run_services() {
    print_header "Cloud Run Services (GCP)"
    
    if [ -z "$PROJECT_ID" ]; then
        print_warning "GCP_PROJECT_ID not set. Skipping Cloud Run checks."
        return 0
    fi
    
    if ! command -v gcloud &> /dev/null; then
        print_warning "gcloud CLI not installed"
        return 0
    fi
    
    local services=("nexusforge-python" "nexusforge-nodejs" "nexusforge-go")
    
    for service in "${services[@]}"; do
        local status=$(gcloud run services describe "$service" \
            --region "$REGION" \
            --format 'value(status.conditions[0].status)' 2>/dev/null || echo "NotFound")
        
        if [ "$status" = "True" ]; then
            local url=$(gcloud run services describe "$service" \
                --region "$REGION" \
                --format 'value(status.url)' 2>/dev/null)
            print_success "$service: Running ($url)"
        elif [ "$status" = "NotFound" ]; then
            print_info "$service: Not deployed"
        else
            print_error "$service: $status"
        fi
    done
}

generate_json_output() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "timestamp": "$timestamp",
  "status": "monitoring_complete",
  "checks_completed": true
}
EOF
}

################################################################################
# Main Monitoring Function
################################################################################

run_monitoring() {
    if [ "$JSON_OUTPUT" = false ]; then
        clear
        echo -e "${BOLD}${MAGENTA}"
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║         NexusForge Platform - System Monitor                  ║"
        echo "║         Timestamp: $(date '+%Y-%m-%d %H:%M:%S')                         ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    fi
    
    check_docker_services
    check_service_health
    check_database_status
    check_resource_usage
    check_logs_for_errors
    check_network_connectivity
    check_cloud_run_services
    
    if [ "$JSON_OUTPUT" = true ]; then
        generate_json_output
    fi
    
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "\n${BOLD}${GREEN}Monitoring check completed at $(date '+%H:%M:%S')${NC}"
        
        if [ "$CONTINUOUS" = true ]; then
            echo -e "${CYAN}Refreshing in ${INTERVAL} seconds... (Press Ctrl+C to stop)${NC}"
        fi
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    if [ "$CONTINUOUS" = true ]; then
        while true; do
            run_monitoring
            sleep "$INTERVAL"
        done
    else
        run_monitoring
    fi
}

# Run main function
main

exit 0
