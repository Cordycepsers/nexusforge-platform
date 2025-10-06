#!/usr/bin/env bash

# ============================================
# NexusForge Platform - Development VM Setup
# ============================================
# Create and configure a development VM for testing
#
# Usage:
#   ./02-dev-vm-setup.sh --project-id PROJECT_ID --region REGION
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
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# ============================================
# Default Values
# ============================================
PROJECT_ID=""
REGION="us-central1"
ZONE=""
VM_NAME="nexusforge-dev-vm"
MACHINE_TYPE="e2-medium"
DISK_SIZE="50"

# ============================================
# Helper Functions
# ============================================

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_step() { echo -e "\n${CYAN}${BOLD}▶ $1${NC}"; }

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-id)
                PROJECT_ID="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --zone)
                ZONE="$2"
                shift 2
                ;;
            --vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            --machine-type)
                MACHINE_TYPE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$PROJECT_ID" ]]; then
        print_error "Project ID is required"
        show_help
        exit 1
    fi
    
    if [[ -z "$ZONE" ]]; then
        ZONE="${REGION}-a"
    fi
}

show_help() {
    cat << EOF
Usage: $0 --project-id PROJECT_ID [OPTIONS]

Create and configure development VM

Required Arguments:
  --project-id ID       GCP Project ID

Optional Arguments:
  --region REGION       GCP Region (default: us-central1)
  --zone ZONE          GCP Zone (default: REGION-a)
  --vm-name NAME       VM instance name (default: nexusforge-dev-vm)
  --machine-type TYPE  Machine type (default: e2-medium)
  -h, --help           Show this help message
EOF
}

# Create startup script
create_startup_script() {
    cat > /tmp/startup-script.sh << 'EOFSCRIPT'
#!/bin/bash

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install development tools
apt-get install -y git curl wget vim nano htop make build-essential

# Install Python
apt-get install -y python3 python3-pip python3-venv

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# Install Go
wget https://go.dev/dl/go1.18.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.18.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile

# Setup complete
echo "Development VM setup complete!" > /var/log/startup-complete
EOFSCRIPT
}

# Create VM instance
create_vm_instance() {
    print_step "Creating development VM..."
    
    if gcloud compute instances describe "${VM_NAME}" \
        --zone="${ZONE}" --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "VM '${VM_NAME}' already exists"
        return 0
    fi
    
    create_startup_script
    
    gcloud compute instances create "${VM_NAME}" \
        --project="${PROJECT_ID}" \
        --zone="${ZONE}" \
        --machine-type="${MACHINE_TYPE}" \
        --network=nexusforge-vpc \
        --subnet=nexusforge-subnet \
        --tags=allow-ssh,allow-http \
        --image-family=ubuntu-2204-lts \
        --image-project=ubuntu-os-cloud \
        --boot-disk-size="${DISK_SIZE}GB" \
        --boot-disk-type=pd-standard \
        --metadata-from-file=startup-script=/tmp/startup-script.sh \
        --scopes=cloud-platform
    
    rm /tmp/startup-script.sh
    
    print_success "VM created: ${VM_NAME}"
}

# Display connection info
show_connection_info() {
    print_step "VM Connection Information"
    
    local external_ip
    external_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    
    echo ""
    echo -e "${BOLD}SSH Connection:${NC}"
    echo "  gcloud compute ssh ${VM_NAME} --project=${PROJECT_ID} --zone=${ZONE}"
    echo ""
    echo -e "${BOLD}External IP:${NC}"
    echo "  ${external_ip}"
    echo ""
}

# Display summary
show_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}Development VM Setup Complete!${NC}"
    echo ""
    echo -e "${BOLD}VM Configuration:${NC}"
    echo "  Name: ${VM_NAME}"
    echo "  Zone: ${ZONE}"
    echo "  Machine Type: ${MACHINE_TYPE}"
    echo "  Disk Size: ${DISK_SIZE}GB"
    echo ""
}

# ============================================
# Main Script Execution
# ============================================

main() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║       NexusForge Platform - Development VM Setup             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    parse_args "$@"
    create_vm_instance
    show_connection_info
    show_summary
    
    print_success "Development VM setup completed!"
}

main "$@"
