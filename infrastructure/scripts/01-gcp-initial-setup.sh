#!/usr/bin/env bash

# ============================================
# NexusForge Platform - GCP Initial Setup
# ============================================
# Initialize GCP project with required APIs, services, and configurations
#
# Usage:
#   ./01-gcp-initial-setup.sh --project-id PROJECT_ID --region REGION
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
BILLING_ACCOUNT=""

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
            --billing-account)
                BILLING_ACCOUNT="$2"
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
    
    # Validate required arguments
    if [[ -z "$PROJECT_ID" ]]; then
        print_error "Project ID is required"
        show_help
        exit 1
    fi
    
    # Set zone if not provided
    if [[ -z "$ZONE" ]]; then
        ZONE="${REGION}-a"
    fi
}

show_help() {
    cat << EOF
Usage: $0 --project-id PROJECT_ID [OPTIONS]

Initialize GCP project for NexusForge Platform

Required Arguments:
  --project-id ID       GCP Project ID

Optional Arguments:
  --region REGION       GCP Region (default: us-central1)
  --zone ZONE          GCP Zone (default: REGION-a)
  --billing-account ID  Billing Account ID
  -h, --help           Show this help message

Example:
  $0 --project-id my-nexusforge-project --region us-central1
EOF
}

# Check if gcloud is authenticated
check_gcloud_auth() {
    print_step "Checking gcloud authentication..."
    
    if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" | grep -q .; then
        print_error "No active gcloud authentication found"
        print_info "Please run: gcloud auth login"
        exit 1
    fi
    
    local account
    account=$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" | head -n1)
    print_success "Authenticated as: ${account}"
}

# Set gcloud project
set_gcloud_project() {
    print_step "Setting gcloud project..."
    
    if ! gcloud config set project "${PROJECT_ID}" 2>/dev/null; then
        print_error "Failed to set project. Project may not exist."
        print_info "Creating project: ${PROJECT_ID}"
        
        if [[ -n "$BILLING_ACCOUNT" ]]; then
            gcloud projects create "${PROJECT_ID}" \
                --name="NexusForge Platform" \
                --set-as-default
            
            gcloud billing projects link "${PROJECT_ID}" \
                --billing-account="${BILLING_ACCOUNT}"
        else
            print_error "Project doesn't exist and no billing account provided"
            print_info "Please create the project manually or provide --billing-account"
            exit 1
        fi
    fi
    
    print_success "Project set to: ${PROJECT_ID}"
    gcloud config set compute/region "${REGION}"
    gcloud config set compute/zone "${ZONE}"
}

# Enable required GCP APIs
enable_apis() {
    print_step "Enabling required GCP APIs..."
    
    local apis=(
        "compute.googleapis.com"                 # Compute Engine
        "run.googleapis.com"                     # Cloud Run
        "cloudbuild.googleapis.com"              # Cloud Build
        "artifactregistry.googleapis.com"        # Artifact Registry
        "sqladmin.googleapis.com"                # Cloud SQL
        "redis.googleapis.com"                   # Cloud Memorystore (Redis)
        "vpcaccess.googleapis.com"               # VPC Access Connector
        "servicenetworking.googleapis.com"       # Service Networking
        "secretmanager.googleapis.com"           # Secret Manager
        "cloudresourcemanager.googleapis.com"    # Resource Manager
        "iam.googleapis.com"                     # IAM
        "iamcredentials.googleapis.com"          # IAM Credentials
        "cloudkms.googleapis.com"                # Cloud KMS
        "logging.googleapis.com"                 # Cloud Logging
        "monitoring.googleapis.com"              # Cloud Monitoring
        "cloudtrace.googleapis.com"              # Cloud Trace
        "cloudprofiler.googleapis.com"           # Cloud Profiler
        "storage.googleapis.com"                 # Cloud Storage
        "storage-api.googleapis.com"             # Cloud Storage JSON API
        "container.googleapis.com"               # GKE (optional)
    )
    
    print_info "Enabling ${#apis[@]} APIs (this may take a few minutes)..."
    
    # Enable APIs in batches to speed up
    gcloud services enable "${apis[@]}" --project="${PROJECT_ID}"
    
    print_success "All required APIs enabled"
}

# Create VPC network
create_vpc_network() {
    print_step "Creating VPC network..."
    
    local vpc_name="nexusforge-vpc"
    local subnet_name="nexusforge-subnet"
    local subnet_range="10.0.0.0/24"
    
    # Create VPC network
    if gcloud compute networks describe "${vpc_name}" --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "VPC network '${vpc_name}' already exists"
    else
        gcloud compute networks create "${vpc_name}" \
            --project="${PROJECT_ID}" \
            --subnet-mode=custom \
            --bgp-routing-mode=regional
        
        print_success "VPC network created: ${vpc_name}"
    fi
    
    # Create subnet
    if gcloud compute networks subnets describe "${subnet_name}" \
        --region="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "Subnet '${subnet_name}' already exists"
    else
        gcloud compute networks subnets create "${subnet_name}" \
            --project="${PROJECT_ID}" \
            --network="${vpc_name}" \
            --region="${REGION}" \
            --range="${subnet_range}" \
            --enable-private-ip-google-access
        
        print_success "Subnet created: ${subnet_name}"
    fi
}

# Create firewall rules
create_firewall_rules() {
    print_step "Creating firewall rules..."
    
    local vpc_name="nexusforge-vpc"
    
    # Allow internal traffic
    if gcloud compute firewall-rules describe nexusforge-allow-internal \
        --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "Firewall rule 'nexusforge-allow-internal' already exists"
    else
        gcloud compute firewall-rules create nexusforge-allow-internal \
            --project="${PROJECT_ID}" \
            --network="${vpc_name}" \
            --allow=tcp,udp,icmp \
            --source-ranges=10.0.0.0/24
        
        print_success "Internal firewall rule created"
    fi
    
    # Allow SSH
    if gcloud compute firewall-rules describe nexusforge-allow-ssh \
        --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "Firewall rule 'nexusforge-allow-ssh' already exists"
    else
        gcloud compute firewall-rules create nexusforge-allow-ssh \
            --project="${PROJECT_ID}" \
            --network="${vpc_name}" \
            --allow=tcp:22 \
            --source-ranges=0.0.0.0/0 \
            --target-tags=allow-ssh
        
        print_success "SSH firewall rule created"
    fi
    
    # Allow HTTP/HTTPS
    if gcloud compute firewall-rules describe nexusforge-allow-http \
        --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "Firewall rule 'nexusforge-allow-http' already exists"
    else
        gcloud compute firewall-rules create nexusforge-allow-http \
            --project="${PROJECT_ID}" \
            --network="${vpc_name}" \
            --allow=tcp:80,tcp:443 \
            --source-ranges=0.0.0.0/0 \
            --target-tags=allow-http
        
        print_success "HTTP/HTTPS firewall rule created"
    fi
}

# Create VPC Access Connector
create_vpc_connector() {
    print_step "Creating VPC Access Connector..."
    
    local connector_name="nexusforge-vpc-connector"
    
    if gcloud compute networks vpc-access connectors describe "${connector_name}" \
        --region="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "VPC connector '${connector_name}' already exists"
    else
        gcloud compute networks vpc-access connectors create "${connector_name}" \
            --project="${PROJECT_ID}" \
            --region="${REGION}" \
            --network=nexusforge-vpc \
            --range=10.8.0.0/28 \
            --min-instances=2 \
            --max-instances=10 \
            --machine-type=e2-micro
        
        print_success "VPC connector created: ${connector_name}"
    fi
}

# Create Artifact Registry
create_artifact_registry() {
    print_step "Creating Artifact Registry..."
    
    local repo_name="nexusforge-docker"
    
    if gcloud artifacts repositories describe "${repo_name}" \
        --location="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "Artifact Registry '${repo_name}' already exists"
    else
        gcloud artifacts repositories create "${repo_name}" \
            --project="${PROJECT_ID}" \
            --repository-format=docker \
            --location="${REGION}" \
            --description="Docker images for NexusForge Platform"
        
        print_success "Artifact Registry created: ${repo_name}"
    fi
    
    # Configure Docker authentication
    print_info "Configuring Docker authentication..."
    gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
    print_success "Docker authentication configured"
}

# Create Cloud Storage buckets
create_storage_buckets() {
    print_step "Creating Cloud Storage buckets..."
    
    local backup_bucket="${PROJECT_ID}-backups"
    
    # Backup bucket
    if gsutil ls "gs://${backup_bucket}" &>/dev/null; then
        print_warning "Backup bucket already exists"
    else
        gsutil mb -p "${PROJECT_ID}" -l "${REGION}" "gs://${backup_bucket}"
        
        # Set lifecycle policy for automatic deletion
        cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }
    ]
  }
}
EOF
        gsutil lifecycle set /tmp/lifecycle.json "gs://${backup_bucket}"
        rm /tmp/lifecycle.json
        
        print_success "Backup bucket created: ${backup_bucket}"
    fi
}

# Create service accounts
create_service_accounts() {
    print_step "Creating service accounts..."
    
    local sa_names=(
        "nexusforge-github-actions:GitHub Actions deployment service account"
        "nexusforge-dev:Development environment service account"
        "nexusforge-staging:Staging environment service account"
        "nexusforge-prod:Production environment service account"
    )
    
    for sa_pair in "${sa_names[@]}"; do
        IFS=':' read -r sa_name description <<< "$sa_pair"
        local sa_email="${sa_name}@${PROJECT_ID}.iam.gserviceaccount.com"
        
        if gcloud iam service-accounts describe "${sa_email}" \
            --project="${PROJECT_ID}" &>/dev/null; then
            print_warning "Service account '${sa_name}' already exists"
        else
            gcloud iam service-accounts create "${sa_name}" \
                --project="${PROJECT_ID}" \
                --display-name="${description}"
            
            print_success "Service account created: ${sa_name}"
        fi
    done
}

# Grant IAM roles to service accounts
grant_iam_roles() {
    print_step "Granting IAM roles to service accounts..."
    
    # GitHub Actions SA
    local github_sa="nexusforge-github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
    local github_roles=(
        "roles/run.admin"
        "roles/iam.serviceAccountUser"
        "roles/artifactregistry.writer"
        "roles/cloudbuild.builds.editor"
        "roles/compute.admin"
        "roles/cloudsql.admin"
        "roles/secretmanager.admin"
        "roles/storage.admin"
    )
    
    for role in "${github_roles[@]}"; do
        gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
            --member="serviceAccount:${github_sa}" \
            --role="${role}" \
            --quiet >/dev/null
    done
    print_success "GitHub Actions service account configured"
    
    # Dev/Staging/Prod SAs
    local env_roles=(
        "roles/cloudsql.client"
        "roles/secretmanager.secretAccessor"
        "roles/logging.logWriter"
        "roles/monitoring.metricWriter"
    )
    
    for env in dev staging prod; do
        local env_sa="nexusforge-${env}@${PROJECT_ID}.iam.gserviceaccount.com"
        
        for role in "${env_roles[@]}"; do
            gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
                --member="serviceAccount:${env_sa}" \
                --role="${role}" \
                --quiet >/dev/null
        done
        print_success "${env} service account configured"
    done
}

# Create initial secrets
create_secrets() {
    print_step "Creating Secret Manager secrets..."
    
    local secrets=(
        "dev-database-url:Development database connection URL"
        "staging-database-url:Staging database connection URL"
        "prod-database-url:Production database connection URL"
    )
    
    for secret_pair in "${secrets[@]}"; do
        IFS=':' read -r secret_name description <<< "$secret_pair"
        
        if gcloud secrets describe "${secret_name}" \
            --project="${PROJECT_ID}" &>/dev/null; then
            print_warning "Secret '${secret_name}' already exists"
        else
            echo "PLACEHOLDER_VALUE" | gcloud secrets create "${secret_name}" \
                --project="${PROJECT_ID}" \
                --replication-policy="automatic" \
                --data-file=-
            
            print_success "Secret created: ${secret_name}"
            print_info "Update with actual value later"
        fi
    done
}

# Display summary
show_summary() {
    print_step "Setup Summary"
    
    echo ""
    echo -e "${GREEN}${BOLD}GCP Initial Setup Completed Successfully!${NC}"
    echo ""
    echo -e "${BOLD}Project Configuration:${NC}"
    echo "  Project ID: ${PROJECT_ID}"
    echo "  Region: ${REGION}"
    echo "  Zone: ${ZONE}"
    echo ""
    echo -e "${BOLD}Resources Created:${NC}"
    echo "  ✓ VPC Network: nexusforge-vpc"
    echo "  ✓ Subnet: nexusforge-subnet (10.0.0.0/24)"
    echo "  ✓ Firewall Rules (internal, SSH, HTTP/HTTPS)"
    echo "  ✓ VPC Access Connector"
    echo "  ✓ Artifact Registry: nexusforge-docker"
    echo "  ✓ Storage Bucket: ${PROJECT_ID}-backups"
    echo "  ✓ Service Accounts (4)"
    echo "  ✓ IAM Roles Configured"
    echo "  ✓ Secret Manager Secrets (placeholders)"
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. Run: ./02-workload-identity-setup.sh"
    echo "  2. Configure GitHub repository secrets"
    echo "  3. Deploy development VM"
    echo ""
}

# ============================================
# Main Script Execution
# ============================================

main() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║       NexusForge Platform - GCP Initial Setup                ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    parse_args "$@"
    check_gcloud_auth
    set_gcloud_project
    enable_apis
    create_vpc_network
    create_firewall_rules
    create_vpc_connector
    create_artifact_registry
    create_storage_buckets
    create_service_accounts
    grant_iam_roles
    create_secrets
    show_summary
    
    print_success "GCP initial setup completed!"
}

main "$@"
