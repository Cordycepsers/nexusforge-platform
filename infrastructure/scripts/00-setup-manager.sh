#!/usr/bin/env bash

# ============================================
# NexusForge Platform - Interactive Setup Manager
# ============================================
# Interactive wizard to guide through the complete platform setup
# This script orchestrates all other setup scripts
#
# Usage:
#   ./00-setup-manager.sh
#
# Author: NexusForge Team
# Version: 1.0.0
# ============================================

set -euo pipefail

# ============================================
# Color Definitions
# ============================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# ============================================
# Global Variables
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/.setup-config"

# Setup state
SETUP_STAGE=""
GCP_PROJECT_ID=""
GCP_REGION=""
GITHUB_ORG=""
GITHUB_REPO=""
SETUP_TYPE=""

# ============================================
# Helper Functions
# ============================================

# Print colored messages
print_header() {
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║  $1${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_step() {
    echo -e "\n${MAGENTA}▶${NC} ${BOLD}$1${NC}"
}

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗                       ║
║   ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝                       ║
║   ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗                       ║
║   ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║                       ║
║   ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║                       ║
║   ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝                       ║
║                                                                       ║
║                    FORGE  PLATFORM                                   ║
║                    Setup Manager v1.0.0                              ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE}Welcome to the NexusForge Platform Setup Manager${NC}"
    echo -e "${WHITE}This wizard will guide you through the complete platform setup${NC}\n"
}

# Save configuration
save_config() {
    cat > "${CONFIG_FILE}" <<EOF
# NexusForge Platform Configuration
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

SETUP_STAGE="${SETUP_STAGE}"
GCP_PROJECT_ID="${GCP_PROJECT_ID}"
GCP_REGION="${GCP_REGION}"
GITHUB_ORG="${GITHUB_ORG}"
GITHUB_REPO="${GITHUB_REPO}"
SETUP_TYPE="${SETUP_TYPE}"
EOF
    print_success "Configuration saved to ${CONFIG_FILE}"
}

# Load existing configuration
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${CONFIG_FILE}"
        print_info "Loaded existing configuration from ${CONFIG_FILE}"
        return 0
    fi
    return 1
}

# Validate prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    local required_tools=(
        "gcloud:Google Cloud SDK"
        "git:Git"
        "docker:Docker"
        "jq:JQ (JSON processor)"
    )
    
    for tool_pair in "${required_tools[@]}"; do
        IFS=':' read -r tool description <<< "$tool_pair"
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$description ($tool)")
            print_error "$description is not installed"
        else
            print_success "$description is installed"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        print_info "Please install missing tools and run this script again"
        return 1
    fi
    
    print_success "All prerequisites are satisfied"
    return 0
}

# Prompt for user input with validation
prompt_input() {
    local prompt=$1
    local var_name=$2
    local default=${3:-}
    local validate_func=${4:-}
    
    while true; do
        if [[ -n "$default" ]]; then
            read -rp "$(echo -e "${CYAN}${prompt} [${default}]: ${NC}")" input
            input=${input:-$default}
        else
            read -rp "$(echo -e "${CYAN}${prompt}: ${NC}")" input
        fi
        
        if [[ -z "$input" ]]; then
            print_error "Input cannot be empty"
            continue
        fi
        
        # Run validation function if provided
        if [[ -n "$validate_func" ]] && ! $validate_func "$input"; then
            continue
        fi
        
        eval "$var_name='$input'"
        break
    done
}

# Validate GCP project ID
validate_project_id() {
    local project_id=$1
    if [[ ! $project_id =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
        print_error "Invalid project ID. Must be 6-30 characters, lowercase letters, digits, and hyphens"
        return 1
    fi
    return 0
}

# Validate region
validate_region() {
    local region=$1
    local valid_regions=(
        "us-central1" "us-east1" "us-west1" "us-east4"
        "europe-west1" "europe-west2" "asia-east1" "asia-northeast1"
    )
    
    for valid_region in "${valid_regions[@]}"; do
        if [[ "$region" == "$valid_region" ]]; then
            return 0
        fi
    done
    
    print_error "Invalid region. Must be one of: ${valid_regions[*]}"
    return 1
}

# Collect setup information
collect_setup_info() {
    print_header "Setup Configuration"
    
    print_info "Let's configure your NexusForge Platform setup"
    echo ""
    
    # GCP Project ID
    prompt_input "Enter your GCP Project ID" GCP_PROJECT_ID "" validate_project_id
    
    # GCP Region
    prompt_input "Enter your GCP Region" GCP_REGION "us-central1" validate_region
    
    # GitHub Organization
    prompt_input "Enter your GitHub Organization/Username" GITHUB_ORG
    
    # GitHub Repository
    prompt_input "Enter your GitHub Repository name" GITHUB_REPO "nexusforge-platform"
    
    # Setup type
    echo ""
    print_info "Choose setup type:"
    echo "  1) Standard Setup (separate services)"
    echo "  2) All-in-One Setup (single VM with all services)"
    echo ""
    
    while true; do
        read -rp "$(echo -e "${CYAN}Select setup type [1-2]: ${NC}")" choice
        case $choice in
            1)
                SETUP_TYPE="standard"
                break
                ;;
            2)
                SETUP_TYPE="all-in-one"
                break
                ;;
            *)
                print_error "Invalid choice. Please select 1 or 2"
                ;;
        esac
    done
    
    # Save configuration
    SETUP_STAGE="configured"
    save_config
    
    # Display summary
    echo ""
    print_header "Setup Summary"
    echo -e "${WHITE}GCP Project ID:${NC} ${GCP_PROJECT_ID}"
    echo -e "${WHITE}GCP Region:${NC} ${GCP_REGION}"
    echo -e "${WHITE}GitHub Org:${NC} ${GITHUB_ORG}"
    echo -e "${WHITE}GitHub Repo:${NC} ${GITHUB_REPO}"
    echo -e "${WHITE}Setup Type:${NC} ${SETUP_TYPE}"
    echo ""
    
    read -rp "$(echo -e "${YELLOW}Continue with this configuration? [y/N]: ${NC}")" confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled by user"
        exit 0
    fi
}

# Execute setup step
execute_step() {
    local step_name=$1
    local script_name=$2
    local description=$3
    
    print_header "${step_name}"
    print_info "${description}"
    echo ""
    
    read -rp "$(echo -e "${YELLOW}Execute this step? [Y/n]: ${NC}")" confirm
    confirm=${confirm:-Y}
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_step "Executing ${script_name}..."
        
        # Execute the script with environment variables
        if bash "${SCRIPT_DIR}/${script_name}" \
            --project-id "${GCP_PROJECT_ID}" \
            --region "${GCP_REGION}" \
            --github-org "${GITHUB_ORG}" \
            --github-repo "${GITHUB_REPO}"; then
            print_success "${step_name} completed successfully"
            return 0
        else
            print_error "${step_name} failed"
            return 1
        fi
    else
        print_warning "${step_name} skipped"
        return 0
    fi
}

# Main setup flow
run_setup() {
    print_header "Setup Flow"
    
    # Step 1: GCP Initial Setup
    if ! execute_step \
        "Step 1: GCP Initial Setup" \
        "01-gcp-initial-setup.sh" \
        "Initialize GCP project, enable APIs, and configure basic settings"; then
        print_error "Setup failed at Step 1"
        return 1
    fi
    
    SETUP_STAGE="gcp_initialized"
    save_config
    
    # Step 2: Workload Identity Setup
    if ! execute_step \
        "Step 2: Workload Identity Setup" \
        "02-workload-identity-setup.sh" \
        "Configure Workload Identity Federation for GitHub Actions"; then
        print_error "Setup failed at Step 2"
        return 1
    fi
    
    SETUP_STAGE="workload_identity_configured"
    save_config
    
    # Step 3: Development VM Setup
    if [[ "$SETUP_TYPE" == "standard" ]]; then
        if ! execute_step \
            "Step 3: Development VM Setup" \
            "02-dev-vm-setup.sh" \
            "Create and configure development VM"; then
            print_error "Setup failed at Step 3"
            return 1
        fi
    else
        if ! execute_step \
            "Step 3: All-in-One VM Setup" \
            "03-dev-vm-all-in-one-setup.sh" \
            "Create and configure all-in-one development VM"; then
            print_error "Setup failed at Step 3"
            return 1
        fi
    fi
    
    SETUP_STAGE="vm_configured"
    save_config
    
    # Step 4: Monitoring Setup
    if ! execute_step \
        "Step 4: Monitoring Setup" \
        "04-monitoring-setup.sh" \
        "Configure Cloud Monitoring, Logging, and Alerting"; then
        print_warning "Monitoring setup failed, but continuing..."
    fi
    
    SETUP_STAGE="monitoring_configured"
    save_config
    
    # Step 5: Backup Setup
    if ! execute_step \
        "Step 5: Backup Configuration" \
        "05-backup-setup.sh" \
        "Configure automated backup schedules"; then
        print_warning "Backup setup failed, but continuing..."
    fi
    
    SETUP_STAGE="completed"
    save_config
    
    return 0
}

# Display completion summary
show_completion() {
    print_header "Setup Complete! 🎉"
    
    echo -e "${GREEN}${BOLD}Congratulations!${NC} Your NexusForge Platform is now configured.\n"
    
    echo -e "${WHITE}Next Steps:${NC}"
    echo "  1. Review the generated configuration files"
    echo "  2. Update GitHub repository secrets with GCP credentials"
    echo "  3. Push your code to trigger the first deployment"
    echo "  4. Monitor deployment progress in GitHub Actions"
    echo ""
    
    echo -e "${WHITE}Useful Commands:${NC}"
    echo "  # View Cloud Run services"
    echo "  gcloud run services list --project ${GCP_PROJECT_ID}"
    echo ""
    echo "  # SSH to development VM (if applicable)"
    echo "  gcloud compute ssh nexusforge-dev-vm --project ${GCP_PROJECT_ID} --zone ${GCP_REGION}-a"
    echo ""
    echo "  # View logs"
    echo "  gcloud logging read --project ${GCP_PROJECT_ID} --limit 50"
    echo ""
    
    echo -e "${WHITE}Documentation:${NC}"
    echo "  - Setup Guide: docs/01-SETUP.md"
    echo "  - Development Guide: docs/02-DEVELOPMENT-GUIDE.md"
    echo "  - Deployment Guide: docs/03-DEPLOYMENT-GUIDE.md"
    echo ""
    
    print_info "Configuration saved to: ${CONFIG_FILE}"
    print_success "Setup completed successfully!"
}

# Handle errors
handle_error() {
    local exit_code=$1
    print_error "An error occurred during setup (exit code: ${exit_code})"
    print_info "Check the logs above for details"
    print_info "You can re-run this script to continue from where it failed"
    exit "${exit_code}"
}

# Main menu
show_main_menu() {
    while true; do
        clear
        show_banner
        
        echo -e "${WHITE}Setup Menu:${NC}"
        echo "  1) Fresh Setup (Start from beginning)"
        echo "  2) Resume Setup (Continue from last checkpoint)"
        echo "  3) Re-run Specific Step"
        echo "  4) View Current Configuration"
        echo "  5) Clean Configuration and Exit"
        echo "  6) Exit"
        echo ""
        
        read -rp "$(echo -e "${CYAN}Select an option [1-6]: ${NC}")" choice
        
        case $choice in
            1)
                rm -f "${CONFIG_FILE}"
                check_prerequisites || exit 1
                collect_setup_info
                run_setup && show_completion
                read -rp "Press Enter to continue..."
                ;;
            2)
                if load_config; then
                    print_info "Resuming from stage: ${SETUP_STAGE}"
                    run_setup && show_completion
                else
                    print_error "No existing configuration found. Please run Fresh Setup."
                fi
                read -rp "Press Enter to continue..."
                ;;
            3)
                echo "Not implemented yet"
                read -rp "Press Enter to continue..."
                ;;
            4)
                if load_config; then
                    print_header "Current Configuration"
                    cat "${CONFIG_FILE}"
                else
                    print_error "No configuration file found"
                fi
                read -rp "Press Enter to continue..."
                ;;
            5)
                rm -f "${CONFIG_FILE}"
                print_success "Configuration cleaned"
                exit 0
                ;;
            6)
                print_info "Exiting setup manager"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please select 1-6"
                sleep 2
                ;;
        esac
    done
}

# ============================================
# Main Script Execution
# ============================================

main() {
    # Trap errors
    trap 'handle_error $?' ERR
    
    # Run main menu
    show_main_menu
}

# Execute main function
main "$@"
