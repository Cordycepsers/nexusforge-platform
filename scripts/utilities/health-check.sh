#!/bin/bash

################################################################################
# Health Check Script
# 
# This script performs comprehensive health checks on all NexusForge Platform
# services, databases, and infrastructure components. It can be used for
# monitoring, CI/CD validation, and deployment verification.
#
# Usage:
#   ./health-check.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV  Environment to check (local|dev|staging|prod)
#   -s, --service NAME     Check specific service only
#   -t, --timeout SEC      Health check timeout in seconds (default: 30)
#   -r, --retries NUM      Number of retry attempts (default: 3)
#   -v, --verbose          Verbose output
#   -j, --json            Output results in JSON format
#   -h, --help            Show this help message
#
# Examples:
#   ./health-check.sh                              # Check all local services
#   ./health-check.sh -e prod                      # Check production services
#   ./health-check.sh -s python-api                # Check only Python API
#   ./health-check.sh -t 60 -r 5                   # Custom timeout and retries
#   ./health-check.sh -j                           # JSON output for monitoring
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed
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
ENVIRONMENT="local"
SERVICE_NAME="all"
TIMEOUT=30
RETRIES=3
VERBOSE=false
JSON_OUTPUT=false
CHECKS_PASSED=0
CHECKS_FAILED=0
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -r|--retries)
            RETRIES="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            head -n 40 "$0" | tail -n +2 | sed 's/^# //' | sed 's/^#//'
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

log_verbose() {
    if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

log_info() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${CYAN}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}[✓ PASS]${NC} $1"
    fi
}

log_failure() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}[✗ FAIL]${NC} $1"
    fi
}

log_warning() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}[⚠ WARN]${NC} $1"
    fi
}

################################################################################
# Health Check Functions
################################################################################

check_http_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    local attempt=1
    
    log_verbose "Checking HTTP endpoint: $url"
    
    while [ $attempt -le $RETRIES ]; do
        log_verbose "Attempt $attempt of $RETRIES..."
        
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
        
        if [ "$response" = "$expected_status" ]; then
            log_success "$name is healthy (HTTP $response)"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            return 0
        fi
        
        log_verbose "Got HTTP $response, expected $expected_status"
        attempt=$((attempt + 1))
        
        if [ $attempt -le $RETRIES ]; then
            sleep 2
        fi
    done
    
    log_failure "$name is unhealthy (HTTP $response after $RETRIES attempts)"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    return 1
}

check_tcp_port() {
    local name=$1
    local host=$2
    local port=$3
    
    log_verbose "Checking TCP connection: $host:$port"
    
    if timeout "$TIMEOUT" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        log_success "$name port is open ($host:$port)"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        log_failure "$name port is closed ($host:$port)"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

check_docker_container() {
    local name=$1
    
    log_verbose "Checking Docker container: $name"
    
    if ! docker ps --filter "name=$name" --format "{{.Names}}" | grep -q "$name"; then
        log_failure "$name container is not running"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
    
    local status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null)
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
    
    if [ "$status" = "running" ]; then
        if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
            log_success "$name container is running and healthy"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            return 0
        else
            log_failure "$name container is running but unhealthy"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            return 1
        fi
    else
        log_failure "$name container status: $status"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

check_database_connection() {
    local name=$1
    local command=$2
    
    log_verbose "Checking database: $name"
    
    if eval "$command" &> /dev/null; then
        log_success "$name database is accessible"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        log_failure "$name database is not accessible"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

check_cloud_run_service() {
    local service_name=$1
    
    log_verbose "Checking Cloud Run service: $service_name"
    
    if [ -z "$PROJECT_ID" ]; then
        log_warning "GCP_PROJECT_ID not set, skipping Cloud Run check"
        return 0
    fi
    
    local url=$(gcloud run services describe "$service_name" \
        --region "$REGION" \
        --format 'value(status.url)' 2>/dev/null || echo "")
    
    if [ -z "$url" ]; then
        log_failure "$service_name is not deployed"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
    
    check_http_endpoint "$service_name (Cloud Run)" "$url/health" 200
}

################################################################################
# Environment-Specific Checks
################################################################################

check_local_services() {
    log_info "Checking local services..."
    
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "python-api" ]; then
        check_docker_container "python-api"
        check_http_endpoint "Python API" "http://localhost:8000/health" 200
    fi
    
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "nodejs-api" ]; then
        check_docker_container "nodejs-api"
        check_http_endpoint "Node.js API" "http://localhost:3000/health" 200
    fi
    
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "go-api" ]; then
        check_docker_container "go-api"
        check_http_endpoint "Go API" "http://localhost:8080/health" 200
    fi
    
    if [ "$SERVICE_NAME" = "all" ]; then
        check_docker_container "postgres"
        check_database_connection "PostgreSQL" "docker exec postgres psql -U postgres -c 'SELECT 1'"
        
        check_docker_container "redis"
        check_database_connection "Redis" "docker exec redis redis-cli ping"
        
        check_docker_container "nginx"
        check_http_endpoint "Nginx" "http://localhost" 200
        
        check_docker_container "prometheus"
        check_http_endpoint "Prometheus" "http://localhost:9090/-/healthy" 200
        
        check_docker_container "grafana"
        check_http_endpoint "Grafana" "http://localhost:3001/api/health" 200
    fi
}

check_cloud_services() {
    log_info "Checking cloud services ($ENVIRONMENT)..."
    
    if [ -z "$PROJECT_ID" ]; then
        log_failure "GCP_PROJECT_ID not set. Cannot check cloud services."
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
    
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "python-api" ]; then
        check_cloud_run_service "nexusforge-python"
    fi
    
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "nodejs-api" ]; then
        check_cloud_run_service "nexusforge-nodejs"
    fi
    
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "go-api" ]; then
        check_cloud_run_service "nexusforge-go"
    fi
}

################################################################################
# JSON Output
################################################################################

generate_json_output() {
    local total=$((CHECKS_PASSED + CHECKS_FAILED))
    local status="healthy"
    
    if [ $CHECKS_FAILED -gt 0 ]; then
        status="unhealthy"
    fi
    
    cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "$ENVIRONMENT",
  "status": "$status",
  "checks": {
    "total": $total,
    "passed": $CHECKS_PASSED,
    "failed": $CHECKS_FAILED
  },
  "success_rate": $(awk "BEGIN {printf \"%.2f\", ($CHECKS_PASSED / $total) * 100}")
}
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BOLD}${BLUE}"
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║        NexusForge Platform - Health Check Script              ║"
        echo "║        Environment: $(printf '%-44s' "$ENVIRONMENT")║"
        echo "║        Timestamp: $(date '+%Y-%m-%d %H:%M:%S')                         ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}\n"
    fi
    
    # Run appropriate checks based on environment
    case $ENVIRONMENT in
        local)
            check_local_services
            ;;
        dev|staging|prod)
            check_cloud_services
            ;;
        *)
            log_failure "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
    
    # Output results
    if [ "$JSON_OUTPUT" = true ]; then
        generate_json_output
    else
        echo ""
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}Health Check Summary${NC}"
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        
        local total=$((CHECKS_PASSED + CHECKS_FAILED))
        local success_rate=$(awk "BEGIN {printf \"%.1f\", ($CHECKS_PASSED / $total) * 100}")
        
        echo -e "  Total Checks: ${BOLD}$total${NC}"
        echo -e "  ${GREEN}Passed: $CHECKS_PASSED${NC}"
        echo -e "  ${RED}Failed: $CHECKS_FAILED${NC}"
        echo -e "  Success Rate: ${BOLD}${success_rate}%${NC}"
        
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        
        if [ $CHECKS_FAILED -eq 0 ]; then
            echo -e "\n${GREEN}${BOLD}✓ All health checks passed!${NC}\n"
        else
            echo -e "\n${RED}${BOLD}✗ Some health checks failed!${NC}\n"
        fi
    fi
    
    # Exit with appropriate code
    if [ $CHECKS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main

exit 0
