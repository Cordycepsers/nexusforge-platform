#!/usr/bin/env bash

# ============================================
# NexusForge Platform - All-in-One VM Setup
# ============================================
# Create and configure a single VM with all services (PostgreSQL, Redis, Apps)
#
# Usage:
#   ./03-dev-vm-all-in-one-setup.sh --project-id PROJECT_ID --region REGION
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
VM_NAME="nexusforge-all-in-one"
MACHINE_TYPE="e2-standard-4"
DISK_SIZE="100"

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

Create all-in-one development VM with all services

Required Arguments:
  --project-id ID       GCP Project ID

Optional Arguments:
  --region REGION       GCP Region (default: us-central1)
  --zone ZONE          GCP Zone (default: REGION-a)
  --vm-name NAME       VM instance name (default: nexusforge-all-in-one)
  --machine-type TYPE  Machine type (default: e2-standard-4)
  -h, --help           Show this help message
EOF
}

# Create comprehensive startup script
create_startup_script() {
    cat > /tmp/startup-script-aio.sh << 'EOFSCRIPT'
#!/bin/bash

set -e

echo "==================================="
echo "NexusForge All-in-One VM Setup"
echo "==================================="

# Update system
echo "Updating system..."
apt-get update
apt-get upgrade -y

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Add default user to docker group
usermod -aG docker $(whoami) || true

# Install Docker Compose
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.23.0"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install development tools
echo "Installing development tools..."
apt-get install -y \
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    jq \
    make \
    build-essential \
    net-tools \
    software-properties-common

# Install Python 3.9
echo "Installing Python 3.9..."
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update
apt-get install -y python3.9 python3.9-venv python3.9-dev python3-pip

# Install Node.js 16
echo "Installing Node.js 16..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# Install Go 1.18
echo "Installing Go 1.18..."
wget -q https://go.dev/dl/go1.18.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.18.linux-amd64.tar.gz
rm go1.18.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/bash.bashrc

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
apt-get install -y postgresql-client

# Install Redis client
echo "Installing Redis client..."
apt-get install -y redis-tools

# Create application directory
echo "Creating application directories..."
mkdir -p /opt/nexusforge
cd /opt/nexusforge

# Clone repository (will be done manually)
cat > /opt/nexusforge/README.md << 'EOF'
# NexusForge All-in-One VM

## Getting Started

1. Clone your repository:
   git clone https://github.com/YOUR_ORG/nexusforge-platform.git
   cd nexusforge-platform

2. Start all services:
   docker-compose -f config/docker/docker-compose-all-in-one.yml up -d

3. Check status:
   docker-compose -f config/docker/docker-compose-all-in-one.yml ps

4. View logs:
   docker-compose -f config/docker/docker-compose-all-in-one.yml logs -f

## Services

- PostgreSQL: localhost:5432
- Redis: localhost:6379
- Python API: localhost:8000
- Node API: localhost:3000
- Go API: localhost:8080
- Nginx: localhost:80
- Prometheus: localhost:9090
- Grafana: localhost:3001

## Useful Commands

# Stop all services
docker-compose -f config/docker/docker-compose-all-in-one.yml down

# Rebuild and restart
docker-compose -f config/docker/docker-compose-all-in-one.yml up -d --build

# View logs for specific service
docker-compose -f config/docker/docker-compose-all-in-one.yml logs -f python-service
EOF

# Setup monitoring script
cat > /opt/nexusforge/monitor.sh << 'MONITOR_EOF'
#!/bin/bash
# Quick monitoring script

echo "==================================="
echo "NexusForge Services Status"
echo "==================================="
echo ""

# Check Docker
if systemctl is-active --quiet docker; then
    echo "✓ Docker: Running"
else
    echo "✗ Docker: Not running"
fi

echo ""
echo "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"

echo ""
echo "System Resources:"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
MONITOR_EOF

chmod +x /opt/nexusforge/monitor.sh

# Create systemd service for auto-start (optional)
cat > /etc/systemd/system/nexusforge.service << 'SERVICE_EOF'
[Unit]
Description=NexusForge Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/nexusforge/nexusforge-platform
ExecStart=/usr/local/bin/docker-compose -f config/docker/docker-compose-all-in-one.yml up -d
ExecStop=/usr/local/bin/docker-compose -f config/docker/docker-compose-all-in-one.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Don't enable yet - wait for repository to be cloned
# systemctl enable nexusforge.service

# Setup firewall rules (if ufw is installed)
if command -v ufw &> /dev/null; then
    echo "Configuring firewall..."
    ufw --force enable
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 8000/tcp  # Python
    ufw allow 3000/tcp  # Node
    ufw allow 8080/tcp  # Go
    ufw allow 9090/tcp  # Prometheus
    ufw allow 3001/tcp  # Grafana
fi

# Create welcome message
cat > /etc/motd << 'MOTD_EOF'

╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗                       ║
║   ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝                       ║
║   ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗                       ║
║   ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║                       ║
║   ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║                       ║
║   ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝                       ║
║                                                                       ║
║                 All-in-One Development VM                            ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝

Welcome to NexusForge All-in-One Development Environment!

Quick Start:
  cd /opt/nexusforge
  cat README.md

Monitoring:
  /opt/nexusforge/monitor.sh

Documentation:
  https://github.com/YOUR_ORG/nexusforge-platform

MOTD_EOF

echo "Setup complete!" > /var/log/startup-complete
echo "Setup completed at: $(date)" >> /var/log/startup-complete
EOFSCRIPT
}

# Create VM instance
create_vm_instance() {
    print_step "Creating all-in-one VM..."
    
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
        --boot-disk-type=pd-ssd \
        --metadata-from-file=startup-script=/tmp/startup-script-aio.sh \
        --scopes=cloud-platform
    
    rm /tmp/startup-script-aio.sh
    
    print_success "VM created: ${VM_NAME}"
    print_info "Startup script is running in the background (5-10 minutes)"
}

# Wait for VM to be ready
wait_for_vm_ready() {
    print_step "Waiting for VM to be ready..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if gcloud compute ssh "${VM_NAME}" \
            --zone="${ZONE}" \
            --project="${PROJECT_ID}" \
            --command="test -f /var/log/startup-complete" &>/dev/null; then
            print_success "VM is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 10
    done
    
    print_warning "Timeout waiting for VM startup (continuing anyway)"
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
    echo -e "${BOLD}Service URLs (after starting services):${NC}"
    echo "  Python API:   http://${external_ip}:8000"
    echo "  Node.js API:  http://${external_ip}:3000"
    echo "  Go API:       http://${external_ip}:8080"
    echo "  Nginx:        http://${external_ip}"
    echo "  Prometheus:   http://${external_ip}:9090"
    echo "  Grafana:      http://${external_ip}:3001"
    echo ""
}

# Display summary
show_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}All-in-One VM Setup Complete!${NC}"
    echo ""
    echo -e "${BOLD}VM Configuration:${NC}"
    echo "  Name: ${VM_NAME}"
    echo "  Zone: ${ZONE}"
    echo "  Machine Type: ${MACHINE_TYPE}"
    echo "  Disk Size: ${DISK_SIZE}GB"
    echo ""
    echo -e "${BOLD}Installed Software:${NC}"
    echo "  ✓ Docker & Docker Compose"
    echo "  ✓ Python 3.9"
    echo "  ✓ Node.js 16"
    echo "  ✓ Go 1.18"
    echo "  ✓ PostgreSQL & Redis clients"
    echo "  ✓ Development tools"
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. SSH into the VM"
    echo "  2. Clone your repository: cd /opt/nexusforge && git clone ..."
    echo "  3. Start services: docker-compose -f config/docker/docker-compose-all-in-one.yml up -d"
    echo "  4. Monitor: /opt/nexusforge/monitor.sh"
    echo ""
}

# ============================================
# Main Script Execution
# ============================================

main() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║     NexusForge Platform - All-in-One VM Setup                ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    parse_args "$@"
    create_vm_instance
    wait_for_vm_ready
    show_connection_info
    show_summary
    
    print_success "All-in-One VM setup completed!"
}

main "$@"
