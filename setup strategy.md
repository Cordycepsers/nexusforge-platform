# Complete VM Setup Strategy

---

## 🎯 Recommended VM Setup Strategy

### Use Case Matrix

| Scenario | Recommended Setup | Script to Use |
|----------|------------------|---------------|
| **Development/Learning** | All-in-One VM | `03-dev-vm-all-in-one-setup.sh` |
| **Small Team (<5 devs)** | All-in-One VM | `03-dev-vm-all-in-one-setup.sh` |
| **Medium Team (5-15 devs)** | Standard Multi-VM | `02-dev-vm-setup.sh` |
| **Large Team/Production** | Full Platform | All infrastructure scripts |
| **Cost-Conscious** | All-in-One VM | `03-dev-vm-all-in-one-setup.sh` |

---

## 📋 Complete Setup Files Structure

Here's the **complete, non-duplicated** setup approach:

### File: `infrastructure/scripts/00-setup-manager.sh`

```bash
#!/bin/bash

###############################################################################
# NexusForge Platform - Setup Manager
# 
# Interactive script to guide users through the right setup option
#
# Usage: ./00-setup-manager.sh
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║             NexusForge Platform Setup Manager                  ║
║                                                                ║
║           Automated Development Platform on GCP                ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_step() {
    echo -e "${MAGENTA}➜${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    echo ""
    
    local missing=0
    
    # Check gcloud
    if command -v gcloud &> /dev/null; then
        print_success "gcloud CLI installed: $(gcloud version --format='value(core)' 2>/dev/null | head -1)"
    else
        print_error "gcloud CLI not found"
        missing=1
    fi
    
    # Check git
    if command -v git &> /dev/null; then
        print_success "git installed: $(git --version | cut -d' ' -f3)"
    else
        print_error "git not found"
        missing=1
    fi
    
    # Check current gcloud configuration
    if gcloud config get-value project &> /dev/null; then
        print_success "gcloud authenticated: $(gcloud config get-value account 2>/dev/null)"
    else
        print_warning "gcloud not authenticated"
        echo ""
        echo "  Run: gcloud auth login"
        missing=1
    fi
    
    echo ""
    
    if [ $missing -eq 1 ]; then
        print_error "Please install missing prerequisites before continuing"
        exit 1
    fi
}

# Display setup options
show_setup_options() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Setup Options                              ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${GREEN}1) All-in-One VM Setup${NC} ${YELLOW}(Recommended for getting started)${NC}"
    echo "   • Single VM with all services in Docker containers"
    echo "   • Python, Node.js, Go applications"
    echo "   • VS Code Server, PostgreSQL, Redis"
    echo "   • Monitoring (Prometheus, Grafana, Jaeger)"
    echo "   • Cost: ~\$100/month"
    echo "   • Best for: Learning, small teams, development"
    echo ""
    
    echo -e "${GREEN}2) Standard Multi-Environment Setup${NC}"
    echo "   • Separate VMs for dev, staging, prod"
    echo "   • Cloud Run for application hosting"
    echo "   • Cloud SQL for databases"
    echo "   • Full CI/CD pipeline"
    echo "   • Cost: ~\$390/month"
    echo "   • Best for: Production workloads, larger teams"
    echo ""
    
    echo -e "${GREEN}3) Custom Setup${NC}"
    echo "   • Choose specific components"
    echo "   • Mix of VM and Cloud Run"
    echo "   • Tailored to your needs"
    echo ""
    
    echo -e "${GREEN}4) Initial GCP Setup Only${NC}"
    echo "   • Configure GCP project"
    echo "   • Enable APIs"
    echo "   • Create service accounts"
    echo "   • No VM deployment"
    echo ""
    
    echo -e "${RED}5) Exit${NC}"
    echo ""
}

# Get user input
get_user_choice() {
    while true; do
        read -p "$(echo -e ${CYAN}Select an option [1-5]:${NC} )" choice
        case $choice in
            1|2|3|4|5) echo $choice; return;;
            *) print_error "Invalid choice. Please select 1-5.";;
        esac
    done
}

# Setup option 1: All-in-One
setup_all_in_one() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}             All-in-One VM Setup                               ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get configuration
    read -p "$(echo -e ${CYAN}Project ID [nexusforge-platform]:${NC} )" PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-nexusforge-platform}
    
    read -p "$(echo -e ${CYAN}Region [us-central1]:${NC} )" REGION
    REGION=${REGION:-us-central1}
    
    read -p "$(echo -e ${CYAN}Zone [us-central1-a]:${NC} )" ZONE
    ZONE=${ZONE:-us-central1-a}
    
    read -p "$(echo -e ${CYAN}Machine Type [e2-standard-4]:${NC} )" MACHINE_TYPE
    MACHINE_TYPE=${MACHINE_TYPE:-e2-standard-4}
    
    echo ""
    print_info "Configuration Summary:"
    echo "  Project ID:    $PROJECT_ID"
    echo "  Region:        $REGION"
    echo "  Zone:          $ZONE"
    echo "  Machine Type:  $MACHINE_TYPE"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Proceed with setup? [y/N]:${NC} )" confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled"
        return
    fi
    
    # Export variables
    export PROJECT_ID
    export REGION
    export ZONE
    export MACHINE_TYPE
    
    # Run initial setup first
    print_step "Running initial GCP setup..."
    ./01-gcp-initial-setup.sh
    
    # Run all-in-one setup
    print_step "Deploying All-in-One VM..."
    ./03-dev-vm-all-in-one-setup.sh
    
    print_success "All-in-One setup complete!"
}

# Setup option 2: Standard Multi-Environment
setup_standard() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}         Standard Multi-Environment Setup                      ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get configuration
    read -p "$(echo -e ${CYAN}Project ID [nexusforge-platform]:${NC} )" PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-nexusforge-platform}
    
    read -p "$(echo -e ${CYAN}Region [us-central1]:${NC} )" REGION
    REGION=${REGION:-us-central1}
    
    read -p "$(echo -e ${CYAN}Zone [us-central1-a]:${NC} )" ZONE
    ZONE=${ZONE:-us-central1-a}
    
    echo ""
    print_info "Environments to setup:"
    echo "  [x] Development"
    echo "  [ ] Staging"
    echo "  [ ] Production"
    echo ""
    
    read -p "$(echo -e ${CYAN}Setup staging environment? [y/N]:${NC} )" setup_staging
    read -p "$(echo -e ${CYAN}Setup production environment? [y/N]:${NC} )" setup_prod
    
    # Export variables
    export PROJECT_ID
    export REGION
    export ZONE
    
    # Run initial setup
    print_step "Running initial GCP setup..."
    ./01-gcp-initial-setup.sh
    
    # Setup Workload Identity
    print_step "Configuring Workload Identity Federation..."
    ./02-workload-identity-setup.sh
    
    # Setup development
    print_step "Setting up development environment..."
    export ENVIRONMENT=dev
    ./02-dev-vm-setup.sh
    
    # Setup staging if requested
    if [[ $setup_staging =~ ^[Yy]$ ]]; then
        print_step "Setting up staging environment..."
        export ENVIRONMENT=staging
        ./02-dev-vm-setup.sh
    fi
    
    # Setup production if requested
    if [[ $setup_prod =~ ^[Yy]$ ]]; then
        print_step "Setting up production environment..."
        export ENVIRONMENT=prod
        ./02-dev-vm-setup.sh
    fi
    
    print_success "Standard setup complete!"
    
    echo ""
    print_info "Next steps:"
    echo "  1. Configure GitHub secrets (see documentation)"
    echo "  2. Push code to trigger deployments"
    echo "  3. Access services via external IPs"
}

# Setup option 3: Custom
setup_custom() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                 Custom Setup                                  ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    print_info "Select components to install:"
    echo ""
    
    read -p "  Install initial GCP setup? [Y/n]: " install_gcp
    read -p "  Install Workload Identity? [Y/n]: " install_wif
    read -p "  Install development VM? [Y/n]: " install_dev
    read -p "  Install Cloud Run services? [Y/n]: " install_cloudrun
    read -p "  Install monitoring? [Y/n]: " install_monitoring
    
    # Run selected components
    if [[ ! $install_gcp =~ ^[Nn]$ ]]; then
        ./01-gcp-initial-setup.sh
    fi
    
    if [[ ! $install_wif =~ ^[Nn]$ ]]; then
        ./02-workload-identity-setup.sh
    fi
    
    if [[ ! $install_dev =~ ^[Nn]$ ]]; then
        read -p "  Use All-in-One or Standard VM? [all-in-one/standard]: " vm_type
        if [[ $vm_type == "all-in-one" ]]; then
            ./03-dev-vm-all-in-one-setup.sh
        else
            ./02-dev-vm-setup.sh
        fi
    fi
    
    print_success "Custom setup complete!"
}

# Setup option 4: Initial GCP Setup Only
setup_initial_only() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}              Initial GCP Setup                                ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "$(echo -e ${CYAN}Project ID [nexusforge-platform]:${NC} )" PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-nexusforge-platform}
    
    export PROJECT_ID
    
    print_step "Running initial GCP setup..."
    ./01-gcp-initial-setup.sh
    
    print_success "Initial GCP setup complete!"
    
    echo ""
    print_info "You can now:"
    echo "  1. Run this script again to deploy VMs"
    echo "  2. Use GitHub Actions for automated deployments"
    echo "  3. Manually deploy using gcloud commands"
}

# Main menu loop
main() {
    check_prerequisites
    
    while true; do
        show_setup_options
        choice=$(get_user_choice)
        
        case $choice in
            1)
                setup_all_in_one
                break
                ;;
            2)
                setup_standard
                break
                ;;
            3)
                setup_custom
                break
                ;;
            4)
                setup_initial_only
                break
                ;;
            5)
                echo ""
                print_info "Exiting setup manager"
                exit 0
                ;;
        esac
    done
    
    # Display completion message
    echo ""
    echo -e "${GREEN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                  Setup Complete! 🎉                            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo ""
    print_info "Documentation: docs/"
    print_info "GitHub Workflows: .github/workflows/"
    echo ""
}

# Run main
main
```

### File: `infrastructure/scripts/README.md`

```markdown
# NexusForge Infrastructure Scripts

## Quick Start

Run the interactive setup manager:

```bash
cd infrastructure/scripts
chmod +x *.sh
./00-setup-manager.sh
```

## Script Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `00-setup-manager.sh` | **Interactive setup wizard** | First time setup |
| `01-gcp-initial-setup.sh` | GCP project initialization | Always run first |
| `02-workload-identity-setup.sh` | GitHub Actions authentication | For CI/CD setup |
| `02-dev-vm-setup.sh` | **Standard VM setup** | Production, multiple environments |
| `03-dev-vm-all-in-one-setup.sh` | **All-in-One VM setup** | Development, small teams |

## Setup Scenarios

### Scenario 1: Learning / Single Developer

**Best Choice: All-in-One VM**

```bash
./00-setup-manager.sh
# Select option 1
```

**What you get:**
- Single VM with everything
- VS Code in browser
- All tools pre-installed
- ~$100/month cost

---

### Scenario 2: Small Team (2-5 developers)

**Best Choice: All-in-One VM**

```bash
./00-setup-manager.sh
# Select option 1
# Use larger machine type: e2-standard-8
```

**What you get:**
- Shared development environment
- Collaborative tools
- ~$200/month cost

---

### Scenario 3: Medium Team (5-15 developers)

**Best Choice: Standard Multi-Environment**

```bash
./00-setup-manager.sh
# Select option 2
# Setup dev + staging
```

**What you get:**
- Separate dev/staging environments
- Cloud Run for applications
- CI/CD pipeline
- ~$300/month cost

---

### Scenario 4: Production Team / Enterprise

**Best Choice: Full Platform**

```bash
./00-setup-manager.sh
# Select option 2
# Setup all environments
```

**What you get:**
- Dev/Staging/Prod isolation
- High availability
- Full monitoring
- ~$400/month cost

---

## Manual Script Usage

### 1. Initial GCP Setup (Always First)

```bash
export PROJECT_ID="your-project-id"
export BILLING_ACCOUNT_ID="your-billing-account"
export REGION="us-central1"
export ZONE="us-central1-a"

./01-gcp-initial-setup.sh
```

### 2a. All-in-One VM Setup

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export MACHINE_TYPE="e2-standard-4"  # or e2-standard-8

./03-dev-vm-all-in-one-setup.sh
```

### 2b. Standard VM Setup

```bash
export PROJECT_ID="your-project-id"
export ENVIRONMENT="dev"  # or staging, prod
export REGION="us-central1"
export ZONE="us-central1-a"

./02-dev-vm-setup.sh
```

### 3. Workload Identity (For GitHub Actions)

```bash
export PROJECT_ID="your-project-id"
export GITHUB_ORG="your-github-org"
export GITHUB_REPO="your-repo-name"

./02-workload-identity-setup.sh
```

## Comparison: All-in-One vs Standard

| Feature | All-in-One | Standard |
|---------|------------|----------|
| **Setup Time** | 10 minutes | 30 minutes |
| **Number of VMs** | 1 | 3 (dev/staging/prod) |
| **Services** | Docker containers | Cloud Run + VM |
| **Database** | PostgreSQL in Docker | Cloud SQL |
| **Cost** | $100-200/month | $300-500/month |
| **Scaling** | Vertical (bigger VM) | Horizontal (more instances) |
| **High Availability** | No | Yes |
| **Best For** | Dev/Test | Production |
| **Team Size** | 1-5 | 5+ |

## Migration Path

Start with All-in-One, migrate to Standard when needed:

1. **Start**: All-in-One VM for development
2. **Grow**: Add staging environment (Standard)
3. **Scale**: Full platform with production

```bash
# Step 1: Start with All-in-One
./03-dev-vm-all-in-one-setup.sh

# Step 2: Later, add Standard environments
export ENVIRONMENT=staging
./02-dev-vm-setup.sh

export ENVIRONMENT=prod
./02-dev-vm-setup.sh
```

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PROJECT_ID` | Yes | - | GCP Project ID |
| `REGION` | No | us-central1 | GCP Region |
| `ZONE` | No | us-central1-a | GCP Zone |
| `ENVIRONMENT` | No | dev | Environment name |
| `MACHINE_TYPE` | No | e2-standard-4 | VM machine type |
| `DISK_SIZE` | No | 100 | Disk size in GB |
| `TEAM_NAME` | No | nexusforge | Team/project name |

## Troubleshooting

### Issue: "Permission denied"

```bash
chmod +x *.sh
```

### Issue: "Project not found"

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Issue: "Insufficient permissions"

Ensure your account has:
- Project Owner or Editor role
- Billing Account User role

### Issue: "API not enabled"

The scripts enable APIs automatically, but you can manually enable:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable run.googleapis.com
```

## Support

For issues:
1. Check script logs
2. Review GCP console
3. See docs/05-TROUBLESHOOTING.md
4. Create GitHub issue
```

---

## 🎯 Final Recommendation

### For Your Case, Use:

```bash
# Run the interactive manager
./00-setup-manager.sh
```

**Then select:**
- **Option 1** if you're learning or have a small team
- **Option 2** if you're building for production
- **Option 4** if you just want to initialize GCP first

### Why Not Use Only All-in-One Script?

The all-in-one script is **great for development** but has limitations:

❌ **Don't use All-in-One for:**
- Production workloads
- Teams larger than 5-10 people
- When you need high availability
- When you need separate environments

✅ **Use All-in-One for:**
- Learning and experimentation
- Small team development
- Cost optimization
- Proof of concepts
- Individual developer environments

### Best Practice: Start Small, Scale Up

1. **Week 1-2**: Use All-in-One for development
2. **Week 3-4**: Add Standard staging environment
3. **Week 5+**: Deploy production with full platform
