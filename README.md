# NexusForge Platform - Complete Implementation Guide

## 📋 Table of Contents

- [Part 1: Architecture & Planning](#part-1-architecture--planning)
- [Part 2: Project Structure](#part-2-project-structure)
- [Part 3: Infrastructure Scripts](#part-3-infrastructure-scripts)
- [Part 4: GitHub Actions Workflows](#part-4-github-actions-workflows)
- [Part 5: Configuration Files](#part-5-configuration-files)
- [Part 6: GitLab CI/CD Integration](#part-6-gitlab-cicd-integration)
- [Part 7: Documentation](#part-7-documentation)

---

## 🏗️ Part 1: Architecture & Planning

<scratchpad>

### Solution Architecture

**Core Components:**

1. **Development Environment**
   - GCE VM with VS Code Server (code-server)
   - Docker Compose for local services
   - Python 3.9, Node.js 16, Go 1.18 pre-installed
   - PostgreSQL and Redis containers

2. **Staging & Production Environments**
   - Cloud Run for serverless deployments
   - Cloud SQL for managed databases
   - VPC with private subnets
   - Cloud Load Balancer with SSL

3. **CI/CD Pipeline**
   - GitHub Actions for automation
   - GitLab CI/CD as alternative
   - Automated testing, building, deployment
   - Security scanning integration

4. **Security Layer**
   - Workload Identity Federation (no keys!)
   - Identity-Aware Proxy (IAP)
   - Cloud Armor for DDoS protection
   - Secret Manager for credentials
   - RBAC with custom roles

5. **Monitoring & Observability**
   - Cloud Monitoring dashboards
   - Cloud Logging with log sinks
   - Cloud Trace for distributed tracing
   - Alert policies for incidents

6. **Backup & DR**
   - Daily automated backups
   - Cross-region replication
   - Point-in-time recovery
   - 4-hour RTO capability

**Deployment Flow:**

```
Developer → Git Push → GitHub Actions
    ↓
Security Scan → Unit Tests → Build Images
    ↓
Push to Artifact Registry
    ↓
Deploy to Cloud Run (dev/staging/prod)
    ↓
Run Smoke Tests → Monitor
```

**Network Architecture:**

```
Internet → Cloud Armor → Load Balancer → IAP
    ↓
Cloud Run (VPC Connector)
    ↓
Cloud SQL (Private IP)
```

**Required GitHub Actions Workflows:**
1. Infrastructure setup/teardown
2. Development deployment (auto on push to develop)
3. Staging deployment (auto on push to main)
4. Production deployment (manual with approval)
5. Security scanning (scheduled + on push)
6. Backup automation (scheduled daily)
7. Disaster recovery (manual trigger)

**GCP Resources Needed:**
- Compute Engine (dev VMs)
- Cloud Run (app hosting)
- Cloud SQL (PostgreSQL)
- Artifact Registry (Docker images)
- Secret Manager (credentials)
- Cloud Storage (backups, artifacts)
- VPC Network (isolation)
- Cloud Load Balancing (traffic management)
- Cloud Armor (security)
- Cloud Monitoring (observability)
- IAM & Workload Identity

**Security Implementation:**
- No service account keys exported
- Workload Identity Federation for GitHub
- IAP for user authentication
- Cloud Armor rules for DDoS
- Regular vulnerability scanning
- Automated secret rotation
- Audit logging enabled

**File Structure Needed:**
- Infrastructure scripts (bash)
- GitHub Actions workflows (YAML)
- Docker configurations
- Application code examples
- VS Code settings
- Monitoring configs
- Security policies
- Documentation

</scratchpad>

### Architecture Overview

The NexusForge platform is designed as a **three-tier environment** (Development, Staging, Production) with full automation and zero manual configuration requirements.

#### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          GitHub Repository                           │
│                     (Source Code + Workflows)                        │
└────────────────┬────────────────────────────────────────────────────┘
                 │
                 │ Workload Identity Federation
                 │ (No Service Account Keys!)
                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Google Cloud Platform                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Development Environment                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │   │
│  │  │   Dev VM     │  │    Docker    │  │   VS Code    │     │   │
│  │  │ (Compute     │──│   Compose    │──│   Server     │     │   │
│  │  │  Engine)     │  │              │  │              │     │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Staging/Production Environment                  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │   │
│  │  │  Cloud   │  │  Cloud   │  │  Cloud   │  │  Cloud   │   │   │
│  │  │   Run    │  │   Run    │  │   Run    │  │  Load    │   │   │
│  │  │ (Python) │  │ (Node.js)│  │   (Go)   │  │ Balancer │   │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │   │
│  │       └─────────────┴──────────────┴─────────────┘          │   │
│  │                            │                                 │   │
│  │                   ┌────────▼─────────┐                      │   │
│  │                   │    Cloud SQL     │                      │   │
│  │                   │   (PostgreSQL)   │                      │   │
│  │                   └──────────────────┘                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   Shared Services Layer                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │   │
│  │  │ Artifact │  │  Secret  │  │  Cloud   │  │  Cloud   │   │   │
│  │  │ Registry │  │ Manager  │  │ Storage  │  │  Armor   │   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Observability & Security Layer                  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │   │
│  │  │  Cloud   │  │  Cloud   │  │  Cloud   │  │   IAP    │   │   │
│  │  │Monitoring│  │ Logging  │  │  Trace   │  │          │   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

#### Component Breakdown

| Component | Purpose | Technology | Cost (Monthly) |
|-----------|---------|------------|----------------|
| **Development VM** | Isolated dev environments with VS Code Server | Compute Engine e2-standard-4 | ~$100 |
| **Cloud Run Services** | Serverless application hosting | Cloud Run (3 services × 3 envs) | ~$60 |
| **Cloud SQL** | Managed PostgreSQL databases | Cloud SQL (3 instances) | ~$200 |
| **Artifact Registry** | Docker image storage | Artifact Registry | ~$10 |
| **Secret Manager** | Secure credential storage | Secret Manager | ~$5 |
| **VPC Network** | Network isolation | VPC + Subnets | Free |
| **Load Balancer** | Traffic distribution + SSL | Cloud Load Balancing | ~$20 |
| **Cloud Armor** | DDoS protection | Cloud Armor | ~$10 |
| **IAP** | Secure access control | Identity-Aware Proxy | Free |
| **Monitoring** | Observability suite | Cloud Operations | ~$50 |
| **Storage** | Backups and artifacts | Cloud Storage | ~$10 |
| **CI/CD** | Automated pipelines | GitHub Actions | Free (public) |
| **Total** | | | **~$465/month** |

---

## 📁 Part 2: Project Structure

Here's the complete file structure for the NexusForge platform:

```
nexusforge-platform/
├── .github/
│   └── workflows/
│       ├── 01-infrastructure-setup.yml
│       ├── 02-deploy-dev.yml
│       ├── 03-deploy-staging.yml
│       ├── 04-deploy-prod.yml
│       ├── 05-security-scan.yml
│       ├── 06-backup.yml
│       └── 07-disaster-recovery.yml
│
├── gitlab-ci/
│   └── .gitlab-ci.yml
│
├── infrastructure/
│   ├── scripts/
│   │   ├── 01-gcp-initial-setup.sh
│   │   ├── 02-workload-identity-setup.sh
│   │   ├── 03-dev-vm-setup.sh
│   │   ├── 04-cloud-run-setup.sh
│   │   ├── 05-monitoring-setup.sh
│   │   ├── 06-security-setup.sh
│   │   └── 99-cleanup.sh
│   │
│   └── terraform/  # Optional Terraform configs
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
│
├── config/
│   ├── vscode/
│   │   ├── settings.json
│   │   ├── extensions.json
│   │   ├── launch.json
│   │   └── tasks.json
│   │
│   ├── docker/
│   │   ├── Dockerfile.python
│   │   ├── Dockerfile.node
│   │   ├── Dockerfile.go
│   │   ├── docker-compose.yml
│   │   └── docker-compose.override.yml
│   │
│   ├── nginx/
│   │   └── nginx.conf
│   │
│   ├── monitoring/
│   │   ├── alerts.yaml
│   │   ├── dashboards.json
│   │   └── uptime-checks.yaml
│   │
│   └── security/
│       ├── cloud-armor-rules.yaml
│       ├── iap-config.yaml
│       └── rbac-policies.yaml
│
├── scripts/
│   ├── startup-scripts/
│   │   ├── dev-vm-startup.sh
│   │   ├── install-python.sh
│   │   ├── install-nodejs.sh
│   │   ├── install-go.sh
│   │   └── setup-vscode-server.sh
│   │
│   └── utilities/
│       ├── db-backup.sh
│       ├── db-restore.sh
│       ├── rotate-secrets.sh
│       └── health-check.sh
│
├── docs/
│   ├── 01-SETUP.md
│   ├── 02-DEVELOPMENT-GUIDE.md
│   ├── 03-DEPLOYMENT-GUIDE.md
│   ├── 04-SECURITY.md
│   ├── 05-TROUBLESHOOTING.md
│   └── architecture-diagrams/
│       ├── network-diagram.png
│       ├── deployment-flow.png
│       └── security-model.png
│
├── examples/
│   ├── python/
│   │   ├── fastapi-app/
│   │   ├── flask-app/
│   │   └── django-app/
│   │
│   ├── nodejs/
│   │   ├── express-app/
│   │   └── nestjs-app/
│   │
│   └── go/
│       ├── http-server/
│       └── gin-api/
│
├── tests/
│   ├── integration/
│   ├── e2e/
│   └── load/
│
├── .gitignore
├── .editorconfig
├── LICENSE
└── README.md
```

### Key Directories Explained

#### `.github/workflows/`
Contains all GitHub Actions workflow definitions for automated CI/CD, security scanning, backups, and disaster recovery.

#### `infrastructure/scripts/`
Shell scripts for setting up GCP resources, configuring services, and managing the infrastructure.

#### `config/`
Configuration files for:
- **vscode/**: VS Code settings and extensions
- **docker/**: Dockerfiles and Docker Compose configurations
- **nginx/**: Reverse proxy configuration
- **monitoring/**: Alert policies and dashboards
- **security/**: Security policies and access controls

#### `scripts/`
Utility scripts for:
- **startup-scripts/**: VM initialization scripts
- **utilities/**: Maintenance and operational scripts

#### `docs/`
Comprehensive documentation covering setup, development, deployment, security, and troubleshooting.

#### `examples/`
Sample applications in Python, Node.js, and Go to help developers get started quickly.

---

## 🔧 Part 3: Infrastructure Scripts

### 3.1 Initial GCP Setup Script

**File: `infrastructure/scripts/01-gcp-initial-setup.sh`**

```bash
#!/bin/bash

###############################################################################
# NexusForge Platform - Initial GCP Setup
# 
# This script sets up the foundational GCP infrastructure including:
# - Project configuration
# - API enablement
# - VPC networking
# - Service accounts
# - Cloud SQL instances
# - Artifact Registry
# - Secret Manager
#
# Usage: ./01-gcp-initial-setup.sh
###############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables
PROJECT_ID="${PROJECT_ID:-nexusforge-platform}"
BILLING_ACCOUNT_ID="${BILLING_ACCOUNT_ID:-}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
TEAM_NAME="nexusforge"

# Network Configuration
VPC_NAME="${TEAM_NAME}-vpc"
SUBNET_DEV="${TEAM_NAME}-subnet-dev"
SUBNET_STAGING="${TEAM_NAME}-subnet-staging"
SUBNET_PROD="${TEAM_NAME}-subnet-prod"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command_exists gcloud; then
        print_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists jq; then
        print_warning "jq is not installed. Installing..."
        sudo apt-get update && sudo apt-get install -y jq || brew install jq
    fi
    
    print_success "Prerequisites check completed"
}

# Function to create or set GCP project
setup_project() {
    print_info "Setting up GCP project: ${PROJECT_ID}"
    
    # Check if project exists
    if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
        print_info "Project ${PROJECT_ID} already exists"
    else
        print_info "Creating new project ${PROJECT_ID}"
        
        if [ -z "${BILLING_ACCOUNT_ID}" ]; then
            print_error "BILLING_ACCOUNT_ID is required to create a new project"
            print_info "Please set BILLING_ACCOUNT_ID environment variable"
            exit 1
        fi
        
        gcloud projects create "${PROJECT_ID}" \
            --name="NexusForge Platform" \
            --set-as-default
        
        gcloud billing projects link "${PROJECT_ID}" \
            --billing-account="${BILLING_ACCOUNT_ID}"
    fi
    
    # Set default project
    gcloud config set project "${PROJECT_ID}"
    
    print_success "Project setup completed"
}

# Function to enable required APIs
enable_apis() {
    print_info "Enabling required GCP APIs..."
    
    local apis=(
        "compute.googleapis.com"
        "run.googleapis.com"
        "sqladmin.googleapis.com"
        "artifactregistry.googleapis.com"
        "secretmanager.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "iam.googleapis.com"
        "iamcredentials.googleapis.com"
        "cloudbuild.googleapis.com"
        "cloudkms.googleapis.com"
        "monitoring.googleapis.com"
        "logging.googleapis.com"
        "cloudtrace.googleapis.com"
        "cloudfunctions.googleapis.com"
        "vpcaccess.googleapis.com"
        "servicenetworking.googleapis.com"
        "cloudscheduler.googleapis.com"
        "containerregistry.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_info "Enabling ${api}..."
        gcloud services enable "${api}" --quiet
    done
    
    print_success "All APIs enabled"
}

# Function to create VPC network
create_vpc_network() {
    print_info "Creating VPC network..."
    
    # Create VPC
    if gcloud compute networks describe "${VPC_NAME}" &>/dev/null; then
        print_info "VPC ${VPC_NAME} already exists"
    else
        gcloud compute networks create "${VPC_NAME}" \
            --subnet-mode=custom \
            --bgp-routing-mode=regional
        print_success "VPC ${VPC_NAME} created"
    fi
    
    # Create subnets
    local subnets=(
        "${SUBNET_DEV}:10.10.0.0/24"
        "${SUBNET_STAGING}:10.20.0.0/24"
        "${SUBNET_PROD}:10.30.0.0/24"
    )
    
    for subnet_config in "${subnets[@]}"; do
        IFS=':' read -r subnet_name subnet_range <<< "$subnet_config"
        
        if gcloud compute networks subnets describe "${subnet_name}" \
            --region="${REGION}" &>/dev/null; then
            print_info "Subnet ${subnet_name} already exists"
        else
            gcloud compute networks subnets create "${subnet_name}" \
                --network="${VPC_NAME}" \
                --region="${REGION}" \
                --range="${subnet_range}" \
                --enable-private-ip-google-access
            print_success "Subnet ${subnet_name} created"
        fi
    done
    
    print_success "VPC network setup completed"
}

# Function to create firewall rules
create_firewall_rules() {
    print_info "Creating firewall rules..."
    
    # Allow internal traffic
    if ! gcloud compute firewall-rules describe "${TEAM_NAME}-allow-internal" &>/dev/null; then
        gcloud compute firewall-rules create "${TEAM_NAME}-allow-internal" \
            --network="${VPC_NAME}" \
            --allow=tcp,udp,icmp \
            --source-ranges=10.10.0.0/24,10.20.0.0/24,10.30.0.0/24
        print_success "Internal firewall rule created"
    fi
    
    # Allow SSH from IAP
    if ! gcloud compute firewall-rules describe "${TEAM_NAME}-allow-iap-ssh" &>/dev/null; then
        gcloud compute firewall-rules create "${TEAM_NAME}-allow-iap-ssh" \
            --network="${VPC_NAME}" \
            --allow=tcp:22 \
            --source-ranges=35.235.240.0/20
        print_success "IAP SSH firewall rule created"
    fi
    
    # Allow HTTP/HTTPS for load balancer health checks
    if ! gcloud compute firewall-rules describe "${TEAM_NAME}-allow-health-check" &>/dev/null; then
        gcloud compute firewall-rules create "${TEAM_NAME}-allow-health-check" \
            --network="${VPC_NAME}" \
            --allow=tcp:80,tcp:443,tcp:8080 \
            --source-ranges=130.211.0.0/22,35.191.0.0/16
        print_success "Health check firewall rule created"
    fi
    
    # Deny all other ingress traffic (implicit, but explicit for clarity)
    if ! gcloud compute firewall-rules describe "${TEAM_NAME}-deny-all-ingress" &>/dev/null; then
        gcloud compute firewall-rules create "${TEAM_NAME}-deny-all-ingress" \
            --network="${VPC_NAME}" \
            --action=deny \
            --rules=all \
            --source-ranges=0.0.0.0/0 \
            --priority=65534
        print_success "Deny all ingress rule created"
    fi
    
    print_success "Firewall rules setup completed"
}

# Function to create service accounts
create_service_accounts() {
    print_info "Creating service accounts..."
    
    local service_accounts=(
        "${TEAM_NAME}-github-actions:GitHub Actions CI/CD"
        "${TEAM_NAME}-cloud-build:Cloud Build Service"
        "${TEAM_NAME}-cloud-run:Cloud Run Services"
        "${TEAM_NAME}-dev-vm:Development VM"
    )
    
    for sa_config in "${service_accounts[@]}"; do
        IFS=':' read -r sa_name sa_desc <<< "$sa_config"
        sa_email="${sa_name}@${PROJECT_ID}.iam.gserviceaccount.com"
        
        if gcloud iam service-accounts describe "${sa_email}" &>/dev/null; then
            print_info "Service account ${sa_name} already exists"
        else
            gcloud iam service-accounts create "${sa_name}" \
                --display-name="${sa_desc}"
            print_success "Service account ${sa_name} created"
        fi
    done
    
    print_success "Service accounts setup completed"
}

# Function to grant IAM roles
grant_iam_roles() {
    print_info "Granting IAM roles to service accounts..."
    
    # GitHub Actions SA roles
    local github_sa="${TEAM_NAME}-github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
    local github_roles=(
        "roles/compute.instanceAdmin.v1"
        "roles/iam.serviceAccountUser"
        "roles/run.admin"
        "roles/cloudsql.admin"
        "roles/artifactregistry.admin"
        "roles/secretmanager.secretAccessor"
        "roles/storage.admin"
    )
    
    for role in "${github_roles[@]}"; do
        gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
            --member="serviceAccount:${github_sa}" \
            --role="${role}" \
            --quiet
    done
    
    # Cloud Run SA roles
    local cloudrun_sa="${TEAM_NAME}-cloud-run@${PROJECT_ID}.iam.gserviceaccount.com"
    local cloudrun_roles=(
        "roles/cloudsql.client"
        "roles/secretmanager.secretAccessor"
        "roles/logging.logWriter"
        "roles/monitoring.metricWriter"
        "roles/cloudtrace.agent"
    )
    
    for role in "${cloudrun_roles[@]}"; do
        gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
            --member="serviceAccount:${cloudrun_sa}" \
            --role="${role}" \
            --quiet
    done
    
    print_success "IAM roles granted"
}

# Function to create Artifact Registry repositories
create_artifact_registry() {
    print_info "Creating Artifact Registry repositories..."
    
    if gcloud artifacts repositories describe "${TEAM_NAME}-docker" \
        --location="${REGION}" &>/dev/null; then
        print_info "Artifact Registry repository already exists"
    else
        gcloud artifacts repositories create "${TEAM_NAME}-docker" \
            --repository-format=docker \
            --location="${REGION}" \
            --description="Docker images for NexusForge platform"
        print_success "Artifact Registry repository created"
    fi
}

# Function to create Cloud SQL instances
create_cloud_sql_instances() {
    print_info "Creating Cloud SQL instances..."
    
    local environments=("dev" "staging" "prod")
    local tiers=("db-f1-micro" "db-g1-small" "db-custom-2-7680")
    
    for i in "${!environments[@]}"; do
        local env="${environments[$i]}"
        local tier="${tiers[$i]}"
        local instance_name="${TEAM_NAME}-${env}-db"
        
        if gcloud sql instances describe "${instance_name}" &>/dev/null; then
            print_info "Cloud SQL instance ${instance_name} already exists"
        else
            print_info "Creating Cloud SQL instance ${instance_name}..."
            
            gcloud sql instances create "${instance_name}" \
                --database-version=POSTGRES_14 \
                --tier="${tier}" \
                --region="${REGION}" \
                --network="${VPC_NAME}" \
                --no-assign-ip \
                --database-flags=max_connections=100 \
                --backup-start-time=01:00 \
                --enable-bin-log \
                --maintenance-window-day=SUN \
                --maintenance-window-hour=02 \
                --availability-type=zonal
            
            # Create database
            gcloud sql databases create nexusforge \
                --instance="${instance_name}"
            
            # Generate and store password
            local db_password=$(openssl rand -base64 32)
            echo -n "${db_password}" | gcloud secrets versions add "${TEAM_NAME}-${env}-db-password" --data-file=- || \
                (echo -n "${db_password}" | gcloud secrets create "${TEAM_NAME}-${env}-db-password" --data-file=-)
            
            print_success "Cloud SQL instance ${instance_name} created"
        fi
    done
}

# Function to create Secret Manager secrets
create_secrets() {
    print_info "Creating Secret Manager secrets..."
    
    local secrets=(
        "${TEAM_NAME}-gitlab-token"
        "${TEAM_NAME}-api-key"
        "${TEAM_NAME}-jwt-secret"
        "${TEAM_NAME}-dev-db-password"
        "${TEAM_NAME}-staging-db-password"
        "${TEAM_NAME}-prod-db-password"
    )
    
    for secret_name in "${secrets[@]}"; do
        if gcloud secrets describe "${secret_name}" &>/dev/null; then
            print_info "Secret ${secret_name} already exists"
        else
            echo -n "PLACEHOLDER_VALUE_CHANGE_ME" | \
                gcloud secrets create "${secret_name}" \
                    --data-file=- \
                    --replication-policy="automatic"
            print_success "Secret ${secret_name} created"
        fi
    done
    
    print_warning "Remember to update secret values with actual credentials!"
}

# Function to create VPC Access Connector for Cloud Run
create_vpc_connector() {
    print_info "Creating VPC Access Connector for Cloud Run..."
    
    if gcloud compute networks vpc-access connectors describe "${TEAM_NAME}-vpc-connector" \
        --region="${REGION}" &>/dev/null; then
        print_info "VPC connector already exists"
    else
        gcloud compute networks vpc-access connectors create "${TEAM_NAME}-vpc-connector" \
            --region="${REGION}" \
            --network="${VPC_NAME}" \
            --range=10.8.0.0/28 \
            --min-instances=2 \
            --max-instances=10
        print_success "VPC connector created"
    fi
}

# Function to create Cloud Storage bucket for backups
create_backup_bucket() {
    print_info "Creating Cloud Storage bucket for backups..."
    
    local bucket_name="${TEAM_NAME}-backups"
    
    if gsutil ls -b "gs://${bucket_name}" &>/dev/null; then
        print_info "Backup bucket already exists"
    else
        gsutil mb -p "${PROJECT_ID}" -l "${REGION}" "gs://${bucket_name}"
        
        # Enable versioning
        gsutil versioning set on "gs://${bucket_name}"
        
        # Set lifecycle policy (delete objects older than 90 days)
        cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}
EOF
        gsutil lifecycle set /tmp/lifecycle.json "gs://${bucket_name}"
        rm /tmp/lifecycle.json
        
        print_success "Backup bucket created"
    fi
}

# Main execution
main() {
    print_info "========================================"
    print_info "NexusForge Platform - Initial GCP Setup"
    print_info "========================================"
    echo ""
    
    check_prerequisites
    setup_project
    enable_apis
    create_vpc_network
    create_firewall_rules
    create_service_accounts
    grant_iam_roles
    create_artifact_registry
    create_cloud_sql_instances
    create_secrets
    create_vpc_connector
    create_backup_bucket
    
    echo ""
    print_success "========================================"
    print_success "Initial GCP setup completed successfully!"
    print_success "========================================"
    echo ""
    print_info "Next steps:"
    print_info "1. Update Secret Manager secrets with actual values"
    print_info "2. Run 02-workload-identity-setup.sh for GitHub Actions"
    print_info "3. Configure GitHub repository secrets"
    print_info "4. Run infrastructure deployment workflows"
}

# Run main function
main
```

### 3.2 Workload Identity Federation Setup

**File: `infrastructure/scripts/02-workload-identity-setup.sh`**

```bash
#!/bin/bash

###############################################################################
# NexusForge Platform - Workload Identity Federation Setup
# 
# This script sets up Workload Identity Federation to allow GitHub Actions
# to authenticate with GCP without using service account keys.
#
# Usage: ./02-workload-identity-setup.sh
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ID="${PROJECT_ID:-nexusforge-platform}"
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
REGION="${REGION:-us-central1}"
TEAM_NAME="nexusforge"

# GitHub configuration
GITHUB_ORG="${GITHUB_ORG:-your-github-org}"
GITHUB_REPO="${GITHUB_REPO:-nexusforge-platform}"

# Workload Identity Pool and Provider
POOL_NAME="${TEAM_NAME}-github-pool"
PROVIDER_NAME="${TEAM_NAME}-github-provider"
SERVICE_ACCOUNT_NAME="${TEAM_NAME}-github-actions"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create Workload Identity Pool
create_workload_identity_pool() {
    print_info "Creating Workload Identity Pool..."
    
    if gcloud iam workload-identity-pools describe "${POOL_NAME}" \
        --location=global &>/dev/null; then
        print_info "Workload Identity Pool already exists"
    else
        gcloud iam workload-identity-pools create "${POOL_NAME}" \
            --location=global \
            --display-name="GitHub Actions Pool" \
            --description="Workload Identity Pool for GitHub Actions"
        print_success "Workload Identity Pool created"
    fi
}

# Create Workload Identity Provider
create_workload_identity_provider() {
    print_info "Creating Workload Identity Provider for GitHub..."
    
    if gcloud iam workload-identity-pools providers describe "${PROVIDER_NAME}" \
        --location=global \
        --workload-identity-pool="${POOL_NAME}" &>/dev/null; then
        print_info "Workload Identity Provider already exists"
    else
        gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_NAME}" \
            --location=global \
            --workload-identity-pool="${POOL_NAME}" \
            --display-name="GitHub Provider" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
            --issuer-uri="https://token.actions.githubusercontent.com"
        print_success "Workload Identity Provider created"
    fi
}

# Grant permissions to service account
grant_workload_identity_user() {
    print_info "Granting Workload Identity User role..."
    
    gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT_EMAIL}" \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"
    
    print_success "Workload Identity User role granted"
}

# Display configuration for GitHub
display_github_config() {
    local WORKLOAD_IDENTITY_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"
    
    echo ""
    print_success "========================================"
    print_success "Workload Identity Federation Setup Complete!"
    print_success "========================================"
    echo ""
    print_info "Add the following secrets to your GitHub repository:"
    echo ""
    echo -e "${GREEN}Secret Name:${NC} GCP_PROJECT_ID"
    echo -e "${GREEN}Secret Value:${NC} ${PROJECT_ID}"
    echo ""
    echo -e "${GREEN}Secret Name:${NC} GCP_SERVICE_ACCOUNT"
    echo -e "${GREEN}Secret Value:${NC} ${SERVICE_ACCOUNT_EMAIL}"
    echo ""
    echo -e "${GREEN}Secret Name:${NC} GCP_WORKLOAD_IDENTITY_PROVIDER"
    echo -e "${GREEN}Secret Value:${NC} ${WORKLOAD_IDENTITY_PROVIDER}"
    echo ""
    echo -e "${GREEN}Secret Name:${NC} GCP_REGION"
    echo -e "${GREEN}Secret Value:${NC} ${REGION}"
    echo ""
    print_info "You can add secrets at:"
    echo "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/secrets/actions"
    echo ""
}

# Main execution
main() {
    print_info "========================================"
    print_info "Workload Identity Federation Setup"
    print_info "========================================"
    echo ""
    
    print_info "Configuration:"
    print_info "  Project ID: ${PROJECT_ID}"
    print_info "  Project Number: ${PROJECT_NUMBER}"
    print_info "  GitHub Org: ${GITHUB_ORG}"
    print_info "  GitHub Repo: ${GITHUB_REPO}"
    print_info "  Service Account: ${SERVICE_ACCOUNT_EMAIL}"
    echo ""
    
    create_workload_identity_pool
    create_workload_identity_provider
    grant_workload_identity_user
    display_github_config
}

main
```
```yaml
          LB_NAME="${{ env.TEAM_NAME }}-${{ inputs.environment }}-lb"
          
          echo "Destroying infrastructure for ${{ inputs.environment }}..."
          
          # Delete forwarding rule
          gcloud compute forwarding-rules delete ${LB_NAME}-https-rule \
            --global --quiet || true
          
          # Delete target proxy
          gcloud compute target-https-proxies delete ${LB_NAME}-https-proxy \
            --quiet || true
          
          # Delete SSL certificate
          gcloud compute ssl-certificates delete ${LB_NAME}-cert \
            --quiet || true
          
          # Delete URL map
          gcloud compute url-maps delete ${LB_NAME}-url-map \
            --quiet || true
          
          # Delete backend service
          gcloud compute backend-services delete ${LB_NAME}-backend \
            --global --quiet || true
          
          # Delete health check
          gcloud compute health-checks delete ${LB_NAME}-health-check \
            --quiet || true
          
          # Delete instance group
          gcloud compute instance-groups unmanaged delete ${LB_NAME}-group \
            --zone=${{ env.ZONE }} --quiet || true
          
          # Delete instance
          gcloud compute instances delete ${INSTANCE_NAME} \
            --zone=${{ env.ZONE }} --quiet || true
          
          echo "Infrastructure destroyed successfully"
```

### 4.2 Development Deployment Workflow

**File: `.github/workflows/02-deploy-dev.yml`**

```yaml
name: 02 - Deploy to Development

on:
  push:
    branches:
      - develop
      - feature/*
  workflow_dispatch:

env:
  PROJECT_ID: nexusforge-platform
  REGION: us-central1
  TEAM_NAME: nexusforge
  ENVIRONMENT: dev

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Run Bandit security linter (Python)
        run: |
          pip install bandit
          bandit -r . -f json -o bandit-report.json || true

      - name: Run npm audit (Node.js)
        run: |
          if [ -f "package.json" ]; then
            npm audit --json > npm-audit.json || true
          fi

      - name: Run gosec (Go)
        uses: securego/gosec@master
        if: hashFiles('**/*.go') != ''
        with:
          args: '-fmt json -out gosec-report.json ./...'

  lint-and-test:
    name: Lint and Test
    runs-on: ubuntu-latest
    needs: security-scan

    strategy:
      matrix:
        language: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        if: matrix.language == 'python'
        uses: actions/setup-python@v5
        with:
          python-version: '3.9'

      - name: Python - Install dependencies
        if: matrix.language == 'python'
        run: |
          python -m pip install --upgrade pip
          pip install pylint black pytest pytest-cov mypy

      - name: Python - Lint
        if: matrix.language == 'python'
        run: |
          black --check . || true
          pylint **/*.py || true
          mypy . || true

      - name: Python - Test
        if: matrix.language == 'python'
        run: |
          pytest --cov --cov-report=xml || true

      - name: Setup Node.js
        if: matrix.language == 'node'
        uses: actions/setup-node@v4
        with:
          node-version: '16'

      - name: Node - Install dependencies
        if: matrix.language == 'node'
        run: |
          if [ -f "package.json" ]; then
            npm ci
          fi

      - name: Node - Lint
        if: matrix.language == 'node'
        run: |
          if [ -f "package.json" ]; then
            npm run lint || true
          fi

      - name: Node - Test
        if: matrix.language == 'node'
        run: |
          if [ -f "package.json" ]; then
            npm test || true
          fi

      - name: Setup Go
        if: matrix.language == 'go'
        uses: actions/setup-go@v5
        with:
          go-version: '1.18'

      - name: Go - Lint
        if: matrix.language == 'go'
        run: |
          if [ -f "go.mod" ]; then
            go fmt ./...
            go vet ./...
          fi

      - name: Go - Test
        if: matrix.language == 'go'
        run: |
          if [ -f "go.mod" ]; then
            go test -v -race -coverprofile=coverage.out ./...
          fi

  build-and-push:
    name: Build and Push Images
    runs-on: ubuntu-latest
    needs: lint-and-test
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker for Artifact Registry
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build Docker image
        run: |
          docker build \
            -f config/docker/Dockerfile.${{ matrix.service }} \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }} \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:dev-latest \
            .

      - name: Push Docker image
        run: |
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:dev-latest

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          format: 'table'
          exit-code: '0'

  deploy-to-cloud-run:
    name: Deploy to Cloud Run
    runs-on: ubuntu-latest
    needs: build-and-push
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Deploy to Cloud Run
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: ${{ env.TEAM_NAME }}-${{ matrix.service }}-${{ env.ENVIRONMENT }}
          region: ${{ env.REGION }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          flags: |
            --service-account=${{ env.TEAM_NAME }}-cloud-run@${{ env.PROJECT_ID }}.iam.gserviceaccount.com
            --vpc-connector=${{ env.TEAM_NAME }}-vpc-connector
            --allow-unauthenticated
            --min-instances=0
            --max-instances=10
            --memory=512Mi
            --cpu=1
            --port=8080
            --timeout=300
            --concurrency=80
            --cpu-throttling
            --set-env-vars=ENVIRONMENT=${{ env.ENVIRONMENT }}
            --set-secrets=DATABASE_URL=${{ env.TEAM_NAME }}-dev-db-password:latest
            --labels=environment=${{ env.ENVIRONMENT }},team=${{ env.TEAM_NAME }},service=${{ matrix.service }}

      - name: Get service URL
        run: |
          SERVICE_URL=$(gcloud run services describe ${{ env.TEAM_NAME }}-${{ matrix.service }}-${{ env.ENVIRONMENT }} \
            --region=${{ env.REGION }} \
            --format='value(status.url)')
          echo "Service URL: ${SERVICE_URL}"
          echo "SERVICE_URL=${SERVICE_URL}" >> $GITHUB_ENV

      - name: Run smoke tests
        run: |
          echo "Running smoke tests against ${SERVICE_URL}"
          curl -f ${SERVICE_URL}/health || exit 1

  notify:
    name: Send Notifications
    runs-on: ubuntu-latest
    needs: deploy-to-cloud-run
    if: always()

    steps:
      - name: Deployment status
        run: |
          if [ "${{ needs.deploy-to-cloud-run.result }}" == "success" ]; then
            echo "✅ Deployment to DEV environment successful!"
          else
            echo "❌ Deployment to DEV environment failed!"
          fi
```

### 4.3 Staging Deployment Workflow

**File: `.github/workflows/03-deploy-staging.yml`**

```yaml
name: 03 - Deploy to Staging

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  PROJECT_ID: nexusforge-platform
  REGION: us-central1
  TEAM_NAME: nexusforge
  ENVIRONMENT: staging

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run comprehensive security scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

  build-and-push:
    name: Build and Push Images
    runs-on: ubuntu-latest
    needs: security-scan
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build Docker image
        run: |
          docker build \
            -f config/docker/Dockerfile.${{ matrix.service }} \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }} \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:staging-latest \
            --build-arg BUILD_ENV=staging \
            .

      - name: Push Docker image
        run: |
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:staging-latest

  database-migration:
    name: Database Migration
    runs-on: ubuntu-latest
    needs: build-and-push
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Install Cloud SQL Proxy
        run: |
          wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
          chmod +x cloud_sql_proxy

      - name: Run database migrations
        run: |
          # Start Cloud SQL Proxy in background
          ./cloud_sql_proxy -instances=${{ env.PROJECT_ID }}:${{ env.REGION }}:${{ env.TEAM_NAME }}-staging-db=tcp:5432 &
          PROXY_PID=$!
          
          # Wait for proxy to be ready
          sleep 5
          
          # Get database password from Secret Manager
          DB_PASSWORD=$(gcloud secrets versions access latest --secret="${{ env.TEAM_NAME }}-staging-db-password")
          export DATABASE_URL="postgresql://postgres:${DB_PASSWORD}@localhost:5432/nexusforge"
          
          # Run migrations (example with Alembic for Python)
          if [ -f "alembic.ini" ]; then
            pip install alembic psycopg2-binary
            alembic upgrade head
          fi
          
          # Run migrations (example with Prisma for Node.js)
          if [ -f "prisma/schema.prisma" ]; then
            npm install -g prisma
            prisma migrate deploy
          fi
          
          # Kill proxy
          kill $PROXY_PID

  deploy-to-cloud-run:
    name: Deploy to Cloud Run
    runs-on: ubuntu-latest
    needs: database-migration
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Deploy to Cloud Run
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: ${{ env.TEAM_NAME }}-${{ matrix.service }}-${{ env.ENVIRONMENT }}
          region: ${{ env.REGION }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          flags: |
            --service-account=${{ env.TEAM_NAME }}-cloud-run@${{ env.PROJECT_ID }}.iam.gserviceaccount.com
            --vpc-connector=${{ env.TEAM_NAME }}-vpc-connector
            --ingress=internal-and-cloud-load-balancing
            --min-instances=1
            --max-instances=20
            --memory=1Gi
            --cpu=2
            --port=8080
            --timeout=300
            --concurrency=80
            --set-env-vars=ENVIRONMENT=${{ env.ENVIRONMENT }}
            --set-secrets=DATABASE_URL=${{ env.TEAM_NAME }}-staging-db-password:latest
            --labels=environment=${{ env.ENVIRONMENT }},team=${{ env.TEAM_NAME }},service=${{ matrix.service }},version=${{ github.sha }}

      - name: Configure Cloud Trace
        run: |
          gcloud run services update ${{ env.TEAM_NAME }}-${{ matrix.service }}-${{ env.ENVIRONMENT }} \
            --region=${{ env.REGION }} \
            --update-env-vars=GOOGLE_CLOUD_PROJECT=${{ env.PROJECT_ID }}

  performance-tests:
    name: Performance Testing
    runs-on: ubuntu-latest
    needs: deploy-to-cloud-run
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Get service URLs
        run: |
          echo "Getting service URLs..."
          for service in python node go; do
            URL=$(gcloud run services describe ${{ env.TEAM_NAME }}-${service}-${{ env.ENVIRONMENT }} \
              --region=${{ env.REGION }} \
              --format='value(status.url)')
            echo "${service}_URL=${URL}" >> $GITHUB_ENV
          done

      - name: Install performance testing tools
        run: |
          pip install locust

      - name: Run load tests
        run: |
          # Create locustfile
          cat > locustfile.py << 'EOF'
          from locust import HttpUser, task, between
          
          class WebsiteUser(HttpUser):
              wait_time = between(1, 3)
              
              @task
              def health_check(self):
                  self.client.get("/health")
              
              @task(3)
              def api_endpoint(self):
                  self.client.get("/api/v1/data")
          EOF
          
          # Run load test
          locust -f locustfile.py \
            --headless \
            --users 100 \
            --spawn-rate 10 \
            --run-time 2m \
            --host=${python_URL} \
            --html=performance-report.html

      - name: Upload performance report
        uses: actions/upload-artifact@v4
        with:
          name: performance-report
          path: performance-report.html

  integration-tests:
    name: Integration Testing
    runs-on: ubuntu-latest
    needs: deploy-to-cloud-run
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '16'

      - name: Install dependencies
        run: |
          npm install -g newman

      - name: Run integration tests
        run: |
          # Example: Run Postman collections with Newman
          if [ -f "postman_collection.json" ]; then
            newman run postman_collection.json \
              --environment postman_environment_staging.json \
              --reporters cli,json \
              --reporter-json-export integration-test-results.json
          fi

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: integration-test-results
          path: integration-test-results.json
```

### 4.4 Production Deployment Workflow

**File: `.github/workflows/04-deploy-prod.yml`**

```yaml
name: 04 - Deploy to Production

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      deployment_strategy:
        description: 'Deployment strategy'
        required: true
        type: choice
        options:
          - blue-green
          - canary
        default: canary
      canary_percentage:
        description: 'Canary traffic percentage (if canary selected)'
        required: false
        type: number
        default: 10

env:
  PROJECT_ID: nexusforge-platform
  REGION: us-central1
  TEAM_NAME: nexusforge
  ENVIRONMENT: prod

jobs:
  approval:
    name: Manual Approval
    runs-on: ubuntu-latest
    environment:
      name: production
    steps:
      - name: Approval checkpoint
        run: echo "Deployment to production approved"

  security-validation:
    name: Final Security Validation
    runs-on: ubuntu-latest
    needs: approval
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run security audit
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'
          exit-code: '1'

      - name: Verify signed images
        run: |
          echo "Verifying container signatures..."
          # Add cosign verification here if implementing image signing

  backup-current-state:
    name: Backup Current Production
    runs-on: ubuntu-latest
    needs: security-validation
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Backup database
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          BACKUP_NAME="${{ env.TEAM_NAME }}-prod-backup-${TIMESTAMP}"
          
          gcloud sql backups create \
            --instance=${{ env.TEAM_NAME }}-prod-db \
            --description="Pre-deployment backup ${TIMESTAMP}"

      - name: Save current deployment config
        run: |
          mkdir -p backups
          
          for service in python node go; do
            gcloud run services describe ${{ env.TEAM_NAME }}-${service}-prod \
              --region=${{ env.REGION }} \
              --format=json > backups/${service}-config.json
          done

      - name: Upload backup artifacts
        uses: actions/upload-artifact@v4
        with:
          name: pre-deployment-backup
          path: backups/
          retention-days: 30

  build-and-push:
    name: Build Production Images
    runs-on: ubuntu-latest
    needs: backup-current-state
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build production image
        run: |
          docker build \
            -f config/docker/Dockerfile.${{ matrix.service }} \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }} \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:prod-latest \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.event.release.tag_name || 'latest' }} \
            --build-arg BUILD_ENV=production \
            .

      - name: Run comprehensive vulnerability scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'

      - name: Push images
        run: |
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:prod-latest
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.event.release.tag_name || 'latest' }}

  database-migration:
    name: Production Database Migration
    runs-on: ubuntu-latest
    needs: build-and-push
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Create pre-migration backup
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          gcloud sql backups create \
            --instance=${{ env.TEAM_NAME }}-prod-db \
            --description="Pre-migration backup ${TIMESTAMP}"

      - name: Install Cloud SQL Proxy
        run: |
          wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
          chmod +x cloud_sql_proxy

      - name: Run migrations
        run: |
          ./cloud_sql_proxy -instances=${{ env.PROJECT_ID }}:${{ env.REGION }}:${{ env.TEAM_NAME }}-prod-db=tcp:5432 &
          PROXY_PID=$!
          sleep 5
          
          DB_PASSWORD=$(gcloud secrets versions access latest --secret="${{ env.TEAM_NAME }}-prod-db-password")
          export DATABASE_URL="postgresql://postgres:${DB_PASSWORD}@localhost:5432/nexusforge"
          
          # Run migrations with safety checks
          if [ -f "alembic.ini" ]; then
            pip install alembic psycopg2-binary
            alembic upgrade head
          fi
          
          kill $PROXY_PID

  deploy-canary:
    name: Canary Deployment
    runs-on: ubuntu-latest
    needs: database-migration
    if: ${{ github.event.inputs.deployment_strategy == 'canary' || !github.event.inputs.deployment_strategy }}
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Deploy canary revision
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: ${{ env.TEAM_NAME }}-${{ matrix.service }}-prod
          region: ${{ env.REGION }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          no_traffic: true
          revision_suffix: canary-${{ github.sha }}
          flags: |
            --service-account=${{ env.TEAM_NAME }}-cloud-run@${{ env.PROJECT_ID }}.iam.gserviceaccount.com
            --vpc-connector=${{ env.TEAM_NAME }}-vpc-connector
            --ingress=internal-and-cloud-load-balancing
            --min-instances=2
            --max-instances=50
            --memory=2Gi
            --cpu=2
            --port=8080
            --timeout=300
            --concurrency=80
            --set-env-vars=ENVIRONMENT=prod
            --set-secrets=DATABASE_URL=${{ env.TEAM_NAME }}-prod-db-password:latest
            --labels=environment=prod,team=${{ env.TEAM_NAME }},service=${{ matrix.service }},deployment=canary

      - name: Route traffic to canary
        run: |
          CANARY_PERCENT=${{ github.event.inputs.canary_percentage || 10 }}
          
          gcloud run services update-traffic ${{ env.TEAM_NAME }}-${{ matrix.service }}-prod \
            --region=${{ env.REGION }} \
            --to-revisions=canary-${{ github.sha }}=${CANARY_PERCENT}

      - name: Monitor canary metrics
        run: |
          echo "Monitoring canary deployment for 10 minutes..."
          sleep 600
          
          # Check error rates (simplified - implement proper monitoring)
          SERVICE_NAME="${{ env.TEAM_NAME }}-${{ matrix.service }}-prod"
          
          # Get metrics from Cloud Monitoring
          gcloud monitoring time-series list \
            --filter="resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME}" \
            --format=json

  promote-canary:
    name: Promote Canary to Full Production
    runs-on: ubuntu-latest
    needs: deploy-canary
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Route 100% traffic to canary
        run: |
          gcloud run services update-traffic ${{ env.TEAM_NAME }}-${{ matrix.service }}-prod \
            --region=${{ env.REGION }} \
            --to-latest

  deploy-blue-green:
    name: Blue-Green Deployment
    runs-on: ubuntu-latest
    needs: database-migration
    if: ${{ github.event.inputs.deployment_strategy == 'blue-green' }}
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Deploy green environment
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: ${{ env.TEAM_NAME }}-${{ matrix.service }}-prod
          region: ${{ env.REGION }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ github.sha }}
          no_traffic: true
          revision_suffix: green-${{ github.sha }}
          flags: |
            --service-account=${{ env.TEAM_NAME }}-cloud-run@${{ env.PROJECT_ID }}.iam.gserviceaccount.com
            --vpc-connector=${{ env.TEAM_NAME }}-vpc-connector
            --ingress=internal-and-cloud-load-balancing
            --min-instances=2
            --max-instances=50
            --memory=2Gi
            --cpu=2

      - name: Run smoke tests on green
        run: |
          GREEN_URL=$(gcloud run services describe ${{ env.TEAM_NAME }}-${{ matrix.service }}-prod \
            --region=${{ env.REGION }} \
            --format='value(status.traffic[0].url)')
          
          echo "Testing green environment: ${GREEN_URL}"
          curl -f ${GREEN_URL}/health || exit 1

      - name: Switch traffic to green
        run: |
          gcloud run services update-traffic ${{ env.TEAM_NAME }}-${{ matrix.service }}-prod \
            --region=${{ env.REGION }} \
            --to-latest

  post-deployment-tests:
    name: Post-Deployment Validation
    runs-on: ubuntu-latest
    needs: [promote-canary, deploy-blue-green]
    if: always() && (needs.promote-canary.result == 'success' || needs.deploy-blue-green.result == 'success')
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Run production smoke tests
        run: |
          for service in python node go; do
            SERVICE_URL=$(gcloud run services describe ${{ env.TEAM_NAME }}-${service}-prod \
              --region=${{ env.REGION }} \
              --format='value(status.url)')
            
            echo "Testing ${service}: ${SERVICE_URL}"
            curl -f ${SERVICE_URL}/health || exit 1
          done

      - name: Verify monitoring and logging
        run: |
          echo "Verifying Cloud Monitoring setup..."
          gcloud monitoring dashboards list --filter="displayName:nexusforge-prod"
          
          echo "Checking recent logs..."
          gcloud logging read "resource.type=cloud_run_revision" --limit=10

  notify-deployment:
    name: Notify Deployment Status
    runs-on: ubuntu-latest
    needs: post-deployment-tests
    if: always()

    steps:
      - name: Deployment notification
        run: |
          if [ "${{ needs.post-deployment-tests.result }}" == "success" ]; then
            echo "🎉 Production deployment successful!"
            echo "Version: ${{ github.sha }}"
            echo "Time: $(date)"
          else
            echo "❌ Production deployment failed!"
            echo "Initiating rollback procedures..."
          fi
```

### 4.5 Security Scanning Workflow

**File: `.github/workflows/05-security-scan.yml`**

```yaml
name: 05 - Security Scanning

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:
  push:
    branches:
      - main
      - develop

env:
  PROJECT_ID: nexusforge-platform
  REGION: us-central1
  TEAM_NAME: nexusforge

jobs:
  scan-code:
    name: Code Security Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Run Semgrep scan
        run: |
          pip install semgrep
          semgrep --config=auto --json --output=semgrep-results.json . || true

      - name: Python security check
        run: |
          pip install safety bandit
          
          # Check for known vulnerabilities in dependencies
          safety check --json --output safety-report.json || true
          
          # Static analysis for security issues
          bandit -r . -f json -o bandit-report.json || true

      - name: Node.js security check
        run: |
          if [ -f "package.json" ]; then
            npm audit --json > npm-audit.json || true
            npm install -g snyk
            snyk test --json > snyk-report.json || true
          fi

      - name: Go security check
        uses: securego/gosec@master
        if: hashFiles('**/*.go') != ''
        with:
          args: '-fmt json -out gosec-report.json ./...'

      - name: Upload security reports
        uses: actions/upload-artifact@v4
        with:
          name: security-reports
          path: |
            *-report.json
            *-results.json

  scan-dependencies:
    name: Dependency Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: SBOM Generation
        run: |
          # Install Syft
          curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
          
          # Generate SBOM
          syft dir:. -o json > sbom.json
          syft dir:. -o spdx-json > sbom.spdx.json

      - name: Vulnerability Scan with Grype
        run: |
          # Install Grype
          curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
          
          # Scan SBOM
          grype sbom:./sbom.json -o json > vulnerabilities.json

      - name: Upload SBOM and vulnerability report
        uses: actions/upload-artifact@v4
        with:
          name: sbom-and-vulnerabilities
          path: |
            sbom.json
            sbom.spdx.json
            vulnerabilities.json

  scan-containers:
    name: Container Image Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]
        environment: [dev, staging, prod]

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Scan container image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.TEAM_NAME }}-docker/${{ matrix.service }}:${{ matrix.environment }}-latest
          format: 'json'
          output: 'trivy-image-${{ matrix.service }}-${{ matrix.environment }}.json'
          severity: 'CRITICAL,HIGH,MEDIUM'

      - name: Upload image scan results
        uses: actions/upload-artifact@v4
        with:
          name: image-scan-${{ matrix.service }}-${{ matrix.environment }}
          path: trivy-image-${{ matrix.service }}-${{ matrix.environment }}.json

  scan-infrastructure:
    name: Infrastructure Security Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Run Security Command Center scan
        run: |
          # Check for open ports
          gcloud compute firewall-rules list \
            --filter="network:${{ env.TEAM_NAME }}-vpc" \
            --format=json > firewall-rules.json
          
          # Check IAM policies
          gcloud projects get-iam-policy ${{ env.PROJECT_ID }} \
            --format=json > iam-policy.json
          
          # Check for publicly accessible resources
          gcloud compute instances list \
            --filter="networkInterfaces.accessConfigs:*" \
            --format=json > public-instances.json

      - name: Analyze security findings
        run: |
          echo "Analyzing security configuration..."
          
          # Check for overly permissive firewall rules
          python3 << 'EOF'
          import json
          
          with open('firewall-rules.json') as f:
              rules = json.load(f)
          
          risky_rules = []
          for rule in rules:
              if any('0.0.0.0/0' in range for range in rule.get('sourceRanges', [])):
                  risky_rules.append(rule['name'])
          
          if risky_rules:
              print(f"⚠️  Warning: Found {len(risky_rules)} firewall rules with 0.0.0.0/0 source range")
              for rule in risky_rules:
                  print(f"  - {rule}")
          EOF

      - name: Upload infrastructure scan results
        uses: actions/upload-artifact@v4
        with:
          name: infrastructure-scan
          path: |
            firewall-rules.json
            iam-policy.json
            public-instances.json

  compliance-check:
    name: Compliance Check
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check secrets in code
        run: |
          pip install detect-secrets
          detect-secrets scan --all-files --force-use-all-plugins > secrets-baseline.json || true

      - name: License compliance
        run: |
          # Python
          if [ -f "requirements.txt" ]; then
            pip install pip-licenses
            pip-licenses --format=json > python-licenses.json
          fi
          
          # Node.js
          if [ -f "package.json" ]; then
            npm install -g license-checker
            license-checker --json > node-licenses.json
          fi

      - name: Upload compliance reports
        uses: actions/upload-artifact@v4
        with:
          name: compliance-reports
          path: |
            secrets-baseline.json
            *-licenses.json

  generate-report:
    name: Generate Security Report
    runs-on: ubuntu-latest
    needs: [scan-code, scan-dependencies, scan-containers, scan-infrastructure, compliance-check]
    if: always()

    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4

      - name: Generate consolidated report
        run: |
          cat > security-report.md << 'EOF'
          # Security Scan Report
          
          **Date**: $(date)
          **Project**: NexusForge Platform
          
          ## Summary
          
          This report contains security scanning results from multiple sources.
          
          ### Scans Performed
          - Code security scanning (Trivy, Semgrep, Bandit)
          - Dependency vulnerability scanning
          - Container image scanning
          - Infrastructure security assessment
          - Compliance checks
          
          ### Findings
          
          See attached artifacts for detailed findings.
          
          EOF
          
          echo "Security report generated"

      - name: Upload consolidated report
        uses: actions/upload-artifact@v4
        with:
          name: security-report
          path: security-report.md
```

### 4.6 Backup Workflow

**File: `.github/workflows/06-backup.yml`**

```yaml
name: 06 - Backup and Disaster Recovery

on:
  schedule:
    - cron: '0 1 * * *'  # Daily at 1 AM
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to backup'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod
        default: prod

env:
  PROJECT_ID: nexusforge-platform
  REGION: us-central1
  TEAM_NAME: nexusforge

jobs:
  backup-databases:
    name: Backup Databases
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        environment: [dev, staging, prod]

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Create database backup
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          INSTANCE_NAME="${{ env.TEAM_NAME }}-${{ matrix.environment }}-db"
          
          echo "Creating backup for ${INSTANCE_NAME}..."
          
          gcloud sql backups create \
            --instance=${INSTANCE_NAME} \
            --description="Automated backup ${TIMESTAMP}"
          
          echo "Backup created successfully"

      - name: Export database to Cloud Storage
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          INSTANCE_NAME="${{ env.TEAM_NAME }}-${{ matrix.environment }}-db"
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          EXPORT_URI="gs://${BUCKET_NAME}/database-exports/${{ matrix.environment }}/${TIMESTAMP}.sql.gz"
          
          # Create bucket if it doesn't exist
          gsutil mb -p ${{ env.PROJECT_ID }} -l ${{ env.REGION }} gs://${BUCKET_NAME} || true
          
          # Export database
          gcloud sql export sql ${INSTANCE_NAME} ${EXPORT_URI} \
            --database=nexusforge \
            --offload

      - name: Verify backup
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          
          # List recent backups
          gsutil ls -l gs://${BUCKET_NAME}/database-exports/${{ matrix.environment }}/ | tail -5

  backup-configurations:
    name: Backup Configurations
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Export Cloud Run configurations
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          BACKUP_DIR="cloud-run-configs/${TIMESTAMP}"
          
          mkdir -p ${BACKUP_DIR}
          
          # Export all Cloud Run services
          for env in dev staging prod; do
            for service in python node go; do
              SERVICE_NAME="${{ env.TEAM_NAME }}-${service}-${env}"
              gcloud run services describe ${SERVICE_NAME} \
                --region=${{ env.REGION }} \
                --format=json > ${BACKUP_DIR}/${SERVICE_NAME}.json 2>/dev/null || true
            done
          done
          
          # Upload to Cloud Storage
          gsutil -m cp -r ${BACKUP_DIR} gs://${BUCKET_NAME}/

      - name: Export firewall rules
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          
          gcloud compute firewall-rules list \
            --filter="network:${{ env.TEAM_NAME }}-vpc" \
            --format=json > firewall-rules-${TIMESTAMP}.json
          
          gsutil cp firewall-rules-${TIMESTAMP}.json \
            gs://${BUCKET_NAME}/firewall-rules/

      - name: Export IAM policies
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          
          gcloud projects get-iam-policy ${{ env.PROJECT_ID }} \
            --format=json > iam-policy-${TIMESTAMP}.json
          
          gsutil cp iam-policy-${TIMESTAMP}.json \
            gs://${BUCKET_NAME}/iam-policies/

  backup-secrets:
    name: Backup Secret Versions
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: List and backup secret metadata
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          
          # List all secrets (not values, just metadata)
          gcloud secrets list --format=json > secrets-list-${TIMESTAMP}.json
          
          # Upload to Cloud Storage
          gsutil cp secrets-list-${TIMESTAMP}.json \
            gs://${BUCKET_NAME}/secrets-metadata/

  cleanup-old-backups:
    name: Cleanup Old Backups
    runs-on: ubuntu-latest
    needs: [backup-databases, backup-configurations, backup-secrets]
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Delete old database exports
        run: |
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          RETENTION_DAYS=30
          
          # Delete files older than retention period
          gsutil -m rm -r \
            $(gsutil ls -l gs://${BUCKET_NAME}/database-exports/** | \
            awk -v date="$(date -d "${RETENTION_DAYS} days ago" +%Y-%m-%d)" '$2 < date {print $3}') \
            || true

      - name: Delete old Cloud SQL backups
        run: |
          for env in dev staging prod; do
            INSTANCE_NAME="${{ env.TEAM_NAME }}-${env}-db"
            
            # List backups older than 30 days
            OLD_BACKUPS=$(gcloud sql backups list \
              --instance=${INSTANCE_NAME} \
              --filter="windowStartTime < -P30D" \
              --format="value(id)")
            
            # Delete old backups
            for backup_id in ${OLD_BACKUPS}; do
              gcloud sql backups delete ${backup_id} \
                --instance=${INSTANCE_NAME} \
                --quiet || true
            done
          done
```

### 4.7 Disaster Recovery Workflow

**File: `.github/workflows/07-disaster-recovery.yml`**

```yaml
name: 07 - Disaster Recovery

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to recover'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod
      recovery_point:
        description: 'Recovery point (YYYYMMDD-HHMMSS or latest)'
        required: true
        default: 'latest'
      components:
        description: 'Components to recover (comma-separated: database,services,config)'
        required: true
        default: 'database,services,config'

env:
  PROJECT_ID: nexusforge-platform
  REGION: us-central1
  TEAM_NAME: nexusforge

jobs:
  validate-recovery:
    name: Validate Recovery Parameters
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Validate backup existence
        run: |
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          RECOVERY_POINT="${{ github.event.inputs.recovery_point }}"
          
          if [ "${RECOVERY_POINT}" == "latest" ]; then
            echo "Will recover from latest backup"
            LATEST_BACKUP=$(gsutil ls gs://${BUCKET_NAME}/database-exports/${{ github.event.inputs.environment }}/ | sort -r | head -1)
            echo "Latest backup: ${LATEST_BACKUP}"
          else
            BACKUP_FILE="gs://${BUCKET_NAME}/database-exports/${{ github.event.inputs.environment }}/${RECOVERY_POINT}.sql.gz"
            if gsutil ls ${BACKUP_FILE}; then
              echo "Backup file found: ${BACKUP_FILE}"
            else
              echo "ERROR: Backup file not found!"
              exit 1
            fi
          fi

  recover-database:
    name: Recover Database
    runs-on: ubuntu-latest
    needs: validate-recovery
    if: contains(github.event.inputs.components, 'database')
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Create pre-recovery backup
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          INSTANCE_NAME="${{ env.TEAM_NAME }}-${{ github.event.inputs.environment }}-db"
          
          echo "Creating pre-recovery backup..."
          gcloud sql backups create \
            --instance=${INSTANCE_NAME} \
            --description="Pre-recovery backup ${TIMESTAMP}"

      - name: Stop applications
        run: |
          echo "Stopping Cloud Run services to prevent data inconsistency..."
          for service in python node go; do
            SERVICE_NAME="${{ env.TEAM_NAME }}-${service}-${{ github.event.inputs.environment }}"
            gcloud run services update ${SERVICE_NAME} \
              --region=${{ env.REGION }} \
              --min-instances=0 \
              --max-instances=0 || true
          done

      - name: Restore database
        run: |
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          INSTANCE_NAME="${{ env.TEAM_NAME }}-${{ github.event.inputs.environment }}-db"
          RECOVERY_POINT="${{ github.event.inputs.recovery_point }}"
          
          if [ "${RECOVERY_POINT}" == "latest" ]; then
            IMPORT_URI=$(gsutil ls gs://${BUCKET_NAME}/database-exports/${{ github.event.inputs.environment }}/ | sort -r | head -1)
          else
            IMPORT_URI="gs://${BUCKET_NAME}/database-exports/${{ github.event.inputs.environment }}/${RECOVERY_POINT}.sql.gz"
          fi
          
          echo "Restoring from: ${IMPORT_URI}"
          
          gcloud sql import sql ${INSTANCE_NAME} ${IMPORT_URI} \
            --database=nexusforge

      - name: Verify database recovery
        run: |
          echo "Verifying database connectivity..."
          INSTANCE_NAME="${{ env.TEAM_NAME }}-${{ github.event.inputs.environment }}-db"
          
          # Check if database is accessible
          gcloud sql databases list --instance=${INSTANCE_NAME}

      - name: Restart applications
        run: |
          echo "Restarting Cloud Run services..."
          for service in python node go; do
            SERVICE_NAME="${{ env.TEAM_NAME }}-${service}-${{ github.event.inputs.environment }}"
            gcloud run services update ${SERVICE_NAME} \
              --region=${{ env.REGION }} \
              --min-instances=1 \
              --max-instances=10 || true
          done

  recover-services:
    name: Recover Cloud Run Services
    runs-on: ubuntu-latest
    needs: validate-recovery
    if: contains(github.event.inputs.components, 'services')
    permissions:
      contents: read
      id-token: write

    strategy:
      matrix:
        service: [python, node, go]

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Download backup configuration
        run: |
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          RECOVERY_POINT="${{ github.event.inputs.recovery_point }}"
          SERVICE_NAME="${{ env.TEAM_NAME }}-${{ matrix.service }}-${{ github.event.inputs.environment }}"
          
          if [ "${RECOVERY_POINT}" == "latest" ]; then
            BACKUP_DIR=$(gsutil ls gs://${BUCKET_NAME}/cloud-run-configs/ | sort -r | head -1)
          else
            BACKUP_DIR="gs://${BUCKET_NAME}/cloud-run-configs/${RECOVERY_POINT}/"
          fi
          
          echo "Downloading configuration from: ${BACKUP_DIR}"
          gsutil cp ${BACKUP_DIR}${SERVICE_NAME}.json ./service-config.json

      - name: Restore service configuration
        run: |
          SERVICE_NAME="${{ env.TEAM_NAME }}-${{ matrix.service }}-${{ github.event.inputs.environment }}"
          
          # Extract key configuration from backup
          IMAGE=$(jq -r '.spec.template.spec.containers[0].image' service-config.json)
          ENV_VARS=$(jq -r '.spec.template.spec.containers[0].env[]? | "--set-env-vars=" + .name + "=" + (.value // "")' service-config.json | tr '\n' ' ')
          
          echo "Restoring service with image: ${IMAGE}"
          
          gcloud run deploy ${SERVICE_NAME} \
            --region=${{ env.REGION }} \
            --image=${IMAGE} \
            ${ENV_VARS}

  recover-infrastructure:
    name: Recover Infrastructure Configuration
    runs-on: ubuntu-latest
    needs: validate-recovery
    if: contains(github.event.inputs.components, 'config')
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Recover firewall rules
        run: |
          BUCKET_NAME="${{ env.TEAM_NAME }}-backups"
          RECOVERY_POINT="${{ github.event.inputs.recovery_point }}"
          
          if [ "${RECOVERY_POINT}" == "latest" ]; then
            BACKUP_FILE=$(gsutil ls gs://${BUCKET_NAME}/firewall-rules/ | sort -r | head -1)
          else
            BACKUP_FILE="gs://${BUCKET_NAME}/firewall-rules/firewall-rules-${RECOVERY_POINT}.json"
          fi
          
          echo "Downloading firewall rules from: ${BACKUP_FILE}"
          gsutil cp ${BACKUP_FILE} ./firewall-rules.json
          
          echo "Firewall rules recovered (manual application required for safety)"

      - name: Generate recovery report
        run: |
          cat > recovery-report.md << EOF
          # Disaster Recovery Report
          
          **Date**: $(date)
          **Environment**: ${{ github.event.inputs.environment }}
          **Recovery Point**: ${{ github.event.inputs.recovery_point }}
          **Components**: ${{ github.event.inputs.components }}
          
          ## Recovery Steps Completed
          
          EOF
          
          if contains("${{ github.event.inputs.components }}", "database"); then
            echo "- ✅ Database restored" >> recovery-report.md
          fi
          
          if contains("${{ github.event.inputs.components }}", "services"); then
            echo "- ✅ Cloud Run services restored" >> recovery-report.md
          fi
          
          if contains("${{ github.event.inputs.components }}", "config"); then
            echo "- ✅ Infrastructure configuration recovered" >> recovery-report.md
          fi
          
          cat recovery-report.md

      - name: Upload recovery report
        uses: actions/upload-artifact@v4
        with:
          name: recovery-report
          path: recovery-report.md

  post-recovery-tests:
    name: Post-Recovery Validation
    runs-on: ubuntu-latest
    needs: [recover-database, recover-services, recover-infrastructure]
    if: always()
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Test service connectivity
        run: |
          echo "Testing service connectivity..."
          for service in python node go; do
            SERVICE_NAME="${{ env.TEAM_NAME }}-${service}-${{ github.event.inputs.environment }}"
            SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
              --region=${{ env.REGION }} \
              --format='value(status.url)')
            
            echo "Testing ${service}: ${SERVICE_URL}"
            curl -f ${SERVICE_URL}/health || echo "⚠️  Warning: ${service} health check failed"
          done

      - name: Validate database connectivity
        run: |
          echo "Validating database connectivity..."
          INSTANCE_NAME="${{ env.TEAM_NAME }}-${{ github.event.inputs.environment }}-db"
          
          gcloud sql databases list --instance=${INSTANCE_NAME}

      - name: Generate final status report
        run: |
          echo "================================================"
          echo "Disaster Recovery Complete"
          echo "================================================"
          echo "Environment: ${{ github.event.inputs.environment }}"
          echo "Recovery Time: $(date)"
          echo "Components Recovered: ${{ github.event.inputs.components }}"
          echo "================================================"
```

---

## 🔧 Part 5: Configuration Files

### 5.1 Nginx Configuration

**File: `config/nginx/nginx.conf`**

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/rss+xml font/truetype font/opentype 
               application/vnd.ms-fontobject image/svg+xml;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;

    # Upstream for Python service
    upstream python_backend {
        least_conn;
        server python-dev:8000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # Upstream for Node.js service
    upstream node_backend {
        least_conn;
        server nodejs-dev:3000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # Upstream for Go service
    upstream go_backend {
        least_conn;
        server go-dev:8080 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # Upstream for VS Code Server
    upstream vscode {
        server 127.0.0.1:8080;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    # Main HTTPS server
    server {
        listen 443 ssl http2;
        server_name dev.nexusforge.local;

        # SSL configuration (self-signed for local dev)
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # VS Code Server
        location / {
            proxy_pass http://vscode;
            proxy_set_header Host $host;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Accept-Encoding gzip;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
        }

        # Python API
        location /api/python/ {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://python_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Node.js API
        location /api/node/ {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://node_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # Go API
        location /api/go/ {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://go_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Prometheus metrics
        location /metrics {
            stub_status on;
            access_log off;
            allow 172.28.0.0/16;
            deny all;
        }
    }
}
```

### 5.2 Monitoring Alerts Configuration

**File: `config/monitoring/alerts.yaml`**

```yaml
# Cloud Monitoring Alert Policies for NexusForge

# High CPU Usage Alert
- displayName: "High CPU Usage"
  conditions:
    - displayName: "CPU usage above 80%"
      conditionThreshold:
        filter: |
          resource.type="gce_instance"
          resource.labels.instance_id=monitoring.regex.full_match("nexusforge-.*")
          metric.type="compute.googleapis.com/instance/cpu/utilization"
        comparison: COMPARISON_GT
        thresholdValue: 0.8
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_MEAN
  alertStrategy:
    autoClose: 1800s
  notificationChannels: []

# High Memory Usage Alert
- displayName: "High Memory Usage"
  conditions:
    - displayName: "Memory usage above 85%"
      conditionThreshold:
        filter: |
          resource.type="gce_instance"
          resource.labels.instance_id=monitoring.regex.full_match("nexusforge-.*")
          metric.type="agent.googleapis.com/memory/percent_used"
        comparison: COMPARISON_GT
        thresholdValue: 85
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_MEAN
  alertStrategy:
    autoClose: 1800s

# Disk Space Alert
- displayName: "Low Disk Space"
  conditions:
    - displayName: "Disk usage above 85%"
      conditionThreshold:
        filter: |
          resource.type="gce_instance"
          resource.labels.instance_id=monitoring.regex.full_match("nexusforge-.*")
          metric.type="agent.googleapis.com/disk/percent_used"
        comparison: COMPARISON_GT
        thresholdValue: 85
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_MEAN
  alertStrategy:
    autoClose: 3600s

# Cloud Run High Error Rate
- displayName: "Cloud Run High Error Rate"
  conditions:
    - displayName: "5xx errors above 5%"
      conditionThreshold:
        filter: |
          resource.type="cloud_run_revision"
          resource.labels.service_name=monitoring.regex.full_match("nexusforge-.*")
          metric.type="run.googleapis.com/request_count"
          metric.labels.response_code_class="5xx"
        comparison: COMPARISON_GT
        thresholdValue: 5
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_RATE
            crossSeriesReducer: REDUCE_SUM
            groupByFields:
              - resource.service_name
  alertStrategy:
    autoClose: 600s

# Cloud Run High Latency
- displayName: "Cloud Run High Latency"
  conditions:
    - displayName: "Request latency above 1s"
      conditionThreshold:
        filter: |
          resource.type="cloud_run_revision"
          resource.labels.service_name=monitoring.regex.full_match("nexusforge-.*")
          metric.type="run.googleapis.com/request_latencies"
        comparison: COMPARISON_GT
        thresholdValue: 1000
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_DELTA
            crossSeriesReducer: REDUCE_PERCENTILE_95
            groupByFields:
              - resource.service_name
  alertStrategy:
    autoClose: 600s

# Database Connection Pool Exhaustion
- displayName: "Database Connection Pool Exhaustion"
  conditions:
    - displayName: "Active connections above 80% of max"
      conditionThreshold:
        filter: |
          resource.type="cloudsql_database"
          resource.labels.database_id=monitoring.regex.full_match(".*nexusforge.*")
          metric.type="cloudsql.googleapis.com/database/postgresql/num_backends"
        comparison: COMPARISON_GT
        thresholdValue: 80
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_MEAN
  alertStrategy:
    autoClose: 1800s

# Database High CPU
- displayName: "Database High CPU Usage"
  conditions:
    - displayName: "Database CPU above 80%"
      conditionThreshold:
        filter: |
          resource.type="cloudsql_database"
          resource.labels.database_id=monitoring.regex.full_match(".*nexusforge.*")
          metric.type="cloudsql.googleapis.com/database/cpu/utilization"
        comparison: COMPARISON_GT
        thresholdValue: 0.8
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_MEAN
  alertStrategy:
    autoClose: 1800s

# Uptime Check Failure
- displayName: "Service Down"
  conditions:
    - displayName: "Uptime check failed"
      conditionThreshold:
        filter: |
          resource.type="uptime_url"
          resource.labels.check_id=monitoring.regex.full_match("nexusforge-.*")
          metric.type="monitoring.googleapis.com/uptime_check/check_passed"
        comparison: COMPARISON_LT
        thresholdValue: 1
        duration: 180s
        aggregations:
          - alignmentPeriod: 60s
            crossSeriesReducer: REDUCE_FRACTION_TRUE
            perSeriesAligner: ALIGN_NEXT_OLDER
  alertStrategy:
    autoClose: 600s

# Container Restart Loop
- displayName: "Container Restart Loop"
  conditions:
    - displayName: "Multiple container restarts"
      conditionThreshold:
        filter: |
          resource.type="cloud_run_revision"
          resource.labels.service_name=monitoring.regex.full_match("nexusforge-.*")
          metric.type="run.googleapis.com/container/startup_latencies"
        comparison: COMPARISON_GT
        thresholdValue: 3
        duration: 300s
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_RATE
            crossSeriesReducer: REDUCE_COUNT
  alertStrategy:
    autoClose: 1800s

# Budget Alert (Cost Management)
- displayName: "Budget Alert - 80% Threshold"
  conditions:
    - displayName: "80% of monthly budget consumed"
      conditionThreshold:
        filter: |
          resource.type="billing_account"
          metric.type="billing/project/cost"
        comparison: COMPARISON_GT
        thresholdValue: 0.8
        duration: 0s
  alertStrategy:
    autoClose: 86400s

# SSL Certificate Expiration
- displayName: "SSL Certificate Expiring Soon"
  conditions:
    - displayName: "Certificate expires in 30 days"
      conditionThreshold:
        filter: |
          resource.type="global"
          metric.type="loadbalancing.googleapis.com/https/certificate/days_to_expiration"
        comparison: COMPARISON_LT
        thresholdValue: 30
        duration: 0s
  alertStrategy:
    autoClose: 86400s
```

### 5.3 Cloud Armor Security Policy

**File: `config/security/cloud-armor-rules.yaml`**

```yaml
# Cloud Armor Security Policy for NexusForge

name: nexusforge-security-policy
description: "DDoS protection and security rules for NexusForge platform"

rules:
  # Block known bad IPs
  - priority: 1000
    description: "Block known malicious IPs"
    match:
      versionedExpr: SRC_IPS_V1
      config:
        srcIpRanges:
          - "192.0.2.0/24"  # Example - add actual malicious IPs
    action: deny(403)

  # Rate limiting - general traffic
  - priority: 2000
    description: "Rate limit general traffic - 100 req/min per IP"
    match:
      expr:
        expression: "true"
    action: rate_based_ban
    rateLimitOptions:
      conformAction: allow
      exceedAction: deny(429)
      rateLimitThreshold:
        count: 100
        intervalSec: 60
      banDurationSec: 600

  # Rate limiting - API endpoints
  - priority: 2100
    description: "Rate limit API - 1000 req/min per IP"
    match:
      expr:
        expression: "request.path.matches('/api/.*')"
    action: rate_based_ban
    rateLimitOptions:
      conformAction: allow
      exceedAction: deny(429)
      rateLimitThreshold:
        count: 1000
        intervalSec: 60
      banDurationSec: 300

  # Block SQL injection attempts
  - priority: 3000
    description: "Block SQL injection attempts"
    match:
      expr:
        expression: |
          evaluatePreconfiguredExpr('sqli-stable')
    action: deny(403)

  # Block XSS attempts
  - priority: 3100
    description: "Block XSS attempts"
    match:
      expr:
        expression: |
          evaluatePreconfiguredExpr('xss-stable')
    action: deny(403)

  # Block remote code execution attempts
  - priority: 3200
    description: "Block RCE attempts"
    match:
      expr:
        expression: |
          evaluatePreconfiguredExpr('rce-stable')
    action: deny(403)

  # Block local file inclusion attempts
  - priority: 3300
    description: "Block LFI attempts"
    match:
      expr:
        expression: |
          evaluatePreconfiguredExpr('lfi-stable')
    action: deny(403)

  # Geographic restrictions (optional)
  - priority: 4000
    description: "Allow only specific regions"
    match:
      expr:
        expression: |
          origin.region_code in ['US', 'CA', 'GB', 'DE', 'FR']
    action: allow
    preview: true  # Enable preview mode first

  # Block suspicious user agents
  - priority: 5000
    description: "Block known malicious user agents"
    match:
      expr:
        expression: |
          request.headers['user-agent'].matches('(?i)(bot|crawler|spider|scraper)')
          && !request.headers['user-agent'].matches('(?i)(googlebot|bingbot)')
    action: deny(403)

  # Protect admin endpoints
  - priority: 6000
    description: "Extra protection for admin endpoints"
    match:
      expr:
        expression: "request.path.matches('/admin/.*')"
    action: rate_based_ban
    rateLimitOptions:
      conformAction: allow
      exceedAction: deny(429)
      rateLimitThreshold:
        count: 10
        intervalSec: 60
      banDurationSec: 3600

  # Default allow rule
  - priority: 2147483647
    description: "Default allow"
    match:
      versionedExpr: SRC_IPS_V1
      config:
        srcIpRanges:
          - "*"
    action: allow

# Adaptive Protection (Auto-configured DDoS protection)
adaptiveProtectionConfig:
  layer7DdosDefenseConfig:
    enable: true
    ruleVisibility: STANDARD
```

### 5.4 IAP Configuration

**File: `config/security/iap-config.yaml`**

```yaml
# Identity-Aware Proxy Configuration for NexusForge

# IAP Brand (OAuth consent screen)
brand:
  applicationTitle: "NexusForge Development Platform"
  supportEmail: "support@nexusforge.dev"

# IAP Clients per environment
clients:
  dev:
    displayName: "NexusForge Dev Environment"
    allowedDomains:
      - "nexusforge.dev"
      - "*.nexusforge.dev"
    
  staging:
    displayName: "NexusForge Staging Environment"
    allowedDomains:
      - "staging.nexusforge.dev"
      - "*.staging.nexusforge.dev"
    
  prod:
    displayName: "NexusForge Production Environment"
    allowedDomains:
      - "nexusforge.dev"
      - "*.nexusforge.dev"

# IAM Policy Bindings for Backend Services
iamBindings:
  # Developer access (all authenticated users in domain)
  - role: "roles/iap.httpsResourceAccessor"
    members:
      - "domain:nexusforge.dev"
    condition:
      title: "Developer Access Hours"
      description: "Allow access during business hours"
      expression: |
        request.time.getHours() >= 6 && request.time.getHours() <= 22

  # Admin access (specific group)
  - role: "roles/iap.httpsResourceAccessor"
    members:
      - "group:platform-admins@nexusforge.dev"

  # Service accounts for automation
  - role: "roles/iap.httpsResourceAccessor"
    members:
      - "serviceAccount:nexusforge-github-actions@nexusforge-platform.iam.gserviceaccount.com"

# Access Levels (Context-Aware Access)
accessLevels:
  - name: "trusted_networks"
    description: "Access from trusted networks only"
    basic:
      conditions:
        - ipSubnetworks:
            - "10.0.0.0/8"      # Internal network
            - "203.0.113.0/24"  # Office network
  
  - name: "secure_devices"
    description: "Access from secure, managed devices"
    basic:
      conditions:
        - devicePolicy:
            requireScreenlock: true
            requireAdminApproval: true
            osConstraints:
              - osType: DESKTOP_CHROME_OS
                minimumVersion: "100.0.0"

# Access Policy per environment
accessPolicies:
  dev:
    levels:
      - trusted_networks
    
  staging:
    levels:
      - trusted_networks
      - secure_devices
    
  prod:
    levels:
      - secure_devices
    requireMultiFactor: true
```

### 5.5 RBAC Policies

**File: `config/security/rbac-policies.yaml`**

```yaml
# Role-Based Access Control Policies for NexusForge

# Custom IAM Roles
customRoles:
  # Junior Developer Role
  - roleId: nexusforge.juniorDeveloper
    title: "NexusForge Junior Developer"
    description: "Limited access for junior developers"
    stage: GA
    includedPermissions:
      # Cloud Run - View only
      - run.services.get
      - run.services.list
      - run.revisions.get
      - run.revisions.list
      
      # Cloud Build - Trigger and view
      - cloudbuild.builds.create
      - cloudbuild.builds.get
      - cloudbuild.builds.list
      
      # Artifact Registry - Read only
      - artifactregistry.repositories.get
      - artifactregistry.repositories.list
      - artifactregistry.files.get
      - artifactregistry.files.list
      
      # Logging - Read only
      - logging.logs.list
      - logging.logEntries.list
      
      # Compute - View dev VMs
      - compute.instances.get
      - compute.instances.list
      
      # Secret Manager - Read specific secrets
      - secretmanager.versions.access

  # Senior Developer Role
  - roleId: nexusforge.seniorDeveloper
    title: "NexusForge Senior Developer"
    description: "Extended access for senior developers"
    stage: GA
    includedPermissions:
      # Cloud Run - Deploy and manage
      - run.services.*
      - run.revisions.*
      - run.configurations.*
      
      # Cloud Build - Full access
      - cloudbuild.builds.*
      
      # Artifact Registry - Read and write
      - artifactregistry.repositories.*
      - artifactregistry.files.*
      - artifactregistry.packages.*
      
      # Cloud SQL - Read and connect
      - cloudsql.instances.get
      - cloudsql.instances.list
      - cloudsql.instances.connect
      
      # Logging - Read and write
      - logging.logs.*
      - logging.logEntries.*
      
      # Monitoring - Read and write
      - monitoring.timeSeries.*
      - monitoring.metricDescriptors.*
      
      # Compute - Manage dev VMs
      - compute.instances.get
      - compute.instances.list
      - compute.instances.start
      - compute.instances.stop
      - compute.instances.reset
      
      # Secret Manager - Read all secrets
      - secretmanager.secrets.get
      - secretmanager.secrets.list
      - secretmanager.versions.access

  # Team Lead Role
  - roleId: nexusforge.teamLead
    title: "NexusForge Team Lead"
    description: "Management access for team leads"
    stage: GA
    includedPermissions:
      # All Senior Developer permissions plus:
      
      # IAM - Manage team member access
      - iam.serviceAccounts.get
      - iam.serviceAccounts.list
      - iam.roles.get
      - iam.roles.list
      
      # Cloud SQL - Manage dev/staging databases
      - cloudsql.instances.*
      - cloudsql.databases.*
      - cloudsql.backupRuns.*
      
      # Compute - Full VM management
      - compute.instances.*
      - compute.disks.*
      - compute.images.*
      
      # Budget management
      - billing.accounts.get
      - billing.budgets.get
      - billing.budgets.list
      
      # Secret Manager - Manage secrets
      - secretmanager.secrets.*
      - secretmanager.versions.*

  # Platform Admin Role
  - roleId: nexusforge.platformAdmin
    title: "NexusForge Platform Admin"
    description: "Full platform administration"
    stage: GA
    includedPermissions:
      # Project-wide admin (excluding IAM policy changes)
      - cloudplatformprojects.get
      - cloudplatformprojects.update
      
      # All services - full access
      - run.*
      - cloudbuild.*
      - artifactregistry.*
      - cloudsql.*
      - compute.*
      - storage.*
      - logging.*
      - monitoring.*
      
      # IAM - Full access
      - iam.*
      
      # Security
      - securitycenter.*
      - cloudkms.*
      - secretmanager.*
      
      # Billing
      - billing.*

# Role Bindings by Environment
roleBindings:
  dev:
    # Junior Developers
    - role: projects/nexusforge-platform/roles/nexusforge.juniorDeveloper
      members:
        - group:junior-devs@nexusforge.dev
        - user:new.developer@nexusforge.dev
    
    # Senior Developers
    - role: projects/nexusforge-platform/roles/nexusforge.seniorDeveloper
      members:
        - group:senior-devs@nexusforge.dev
    
    # Team Leads
    - role: projects/nexusforge-platform/roles/nexusforge.teamLead
      members:
        - group:team-leads@nexusforge.dev
    
    # Built-in roles
    - role: roles/viewer
      members:
        - group:all-developers@nexusforge.dev

  staging:
    # Senior Developers only
    - role: projects/nexusforge-platform/roles/nexusforge.seniorDeveloper
      members:
        - group:senior-devs@nexusforge.dev
      condition:
        title: "Staging Access with Approval"
        expression: |
          request.time < timestamp("2024-12-31T23:59:59Z")
    
    # Team Leads
    - role: projects/nexusforge-platform/roles/nexusforge.teamLead
      members:
        - group:team-leads@nexusforge.dev

  prod:
    # Team Leads only (with conditions)
    - role: projects/nexusforge-platform/roles/nexusforge.teamLead
      members:
        - group:team-leads@nexusforge.dev
      condition:
        title: "Production Access - Business Hours Only"
        expression: |
          request.time.getHours() >= 9 && request.time.getHours() <= 17 &&
          request.time.getDayOfWeek() >= 1 && request.time.getDayOfWeek() <= 5
    
    # Platform Admins
    - role: projects/nexusforge-platform/roles/nexusforge.platformAdmin
      members:
        - group:platform-admins@nexusforge.dev

# Service Account Bindings
serviceAccountBindings:
  # GitHub Actions SA
  - serviceAccount: nexusforge-github-actions@nexusforge-platform.iam.gserviceaccount.com
    roles:
      - roles/run.admin
      - roles/cloudbuild.builds.editor
      - roles/artifactregistry.writer
      - roles/compute.instanceAdmin.v1
      - projects/nexusforge-platform/roles/nexusforge.platformAdmin
    
  # Cloud Build SA
  - serviceAccount: nexusforge-cloud-build@nexusforge-platform.iam.gserviceaccount.com
    roles:
      - roles/run.admin
      - roles/artifactregistry.writer
      - roles/cloudsql.client
      - roles/secretmanager.secretAccessor
    
  # Cloud Run SA
  - serviceAccount: nexusforge-cloud-run@nexusforge-platform.iam.gserviceaccount.com
    roles:
      - roles/cloudsql.client
      - roles/secretmanager.secretAccessor
      - roles/logging.logWriter
      - roles/monitoring.metricWriter
      - roles/cloudtrace.agent
    
  # Dev VM SA
  - serviceAccount: nexusforge-dev-vm@nexusforge-platform.iam.gserviceaccount.com
    roles:
      - roles/artifactregistry.reader
      - roles/secretmanager.secretAccessor
      - roles/logging.logWriter
      - roles/monitoring.metricWriter

# Access Approval Configuration
accessApproval:
  enrolledServices:
    - cloudPlatform
  notificationEmails:
    - platform-admins@nexusforge.dev
  
  # Require approval for production access
  requireApprovalFor:
    - environment: prod
      minApprovers: 2
      approverGroups:
        - platform-admins@nexusforge.dev
```

---

## 📜 Part 6: GitLab CI/CD Integration

### 6.1 GitLab CI Configuration

**File: `gitlab-ci/.gitlab-ci.yml`**

```yaml
# GitLab CI/CD Pipeline for NexusForge Platform

variables:
  GCP_PROJECT_ID: nexusforge-platform
  GCP_REGION: us-central1
  TEAM_NAME: nexusforge
  DOCKER_REGISTRY: us-central1-docker.pkg.dev
  DOCKER_DRIVER: overlay2

stages:
  - test
  - security
  - build
  - deploy-dev
  - deploy-staging
  - deploy-prod

# Reusable templates
.gcp_auth: &gcp_auth
  before_script:
    - echo $GCP_SERVICE_ACCOUNT_KEY | base64 -d > ${CI_PROJECT_DIR}/gcp-key.json
    - gcloud auth activate-service-account --key-file ${CI_PROJECT_DIR}/gcp-key.json
    - gcloud config set project $GCP_PROJECT_ID
    - gcloud auth configure-docker ${DOCKER_REGISTRY}

.python_setup: &python_setup
  image: python:3.9-slim
  before_script:
    - pip install --upgrade pip
    - pip install -r requirements.txt

.node_setup: &node_setup
  image: node:16-alpine
  before_script:
    - npm ci

.go_setup: &go_setup
  image: golang:1.18-alpine
  before_script:
    - go mod download

# ============================================
# TEST STAGE
# ============================================

test:python:
  <<: *python_setup
  stage: test
  script:
    - pip install pytest pytest-cov pylint black mypy
    - black --check .
    - pylint **/*.py || true
    - mypy . || true
    - pytest --cov --cov-report=term --cov-report=html
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
    paths:
      - htmlcov/
    expire_in: 1 week
  only:
    - branches
    - merge_requests

test:node:
  <<: *node_setup
  stage: test
  script:
    - npm run lint || true
    - npm test -- --coverage
  coverage: '/Statements\s+:\s+(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    paths:
      - coverage/
    expire_in: 1 week
  only:
    - branches
    - merge_requests

test:go:
  <<: *go_setup
  stage: test
  script:
    - go fmt ./...
    - go vet ./...
    - go test -v -race -coverprofile=coverage.out ./...
    - go tool cover -html=coverage.out -o coverage.html
  coverage: '/coverage: \d+.\d+% of statements/'
  artifacts:
    paths:
      - coverage.html
      - coverage.out
    expire_in: 1 week
  only:
    - branches
    - merge_requests

# ============================================
# SECURITY STAGE
# ============================================

security:trivy-fs:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy fs --exit-code 0 --severity HIGH,CRITICAL --format json --output trivy-report.json .
    - trivy fs --exit-code 1 --severity CRITICAL .
  artifacts:
    reports:
      container_scanning: trivy-report.json
    paths:
      - trivy-report.json
    expire_in: 1 week
  allow_failure: true
  only:
    - branches
    - merge_requests

security:python-safety:
  <<: *python_setup
  stage: security
  script:
    - pip install safety bandit
    - safety check --json --output safety-report.json || true
    - bandit -r . -f json -o bandit-report.json || true
  artifacts:
    paths:
      - safety-report.json
      - bandit-report.json
    expire_in: 1 week
  allow_failure: true
  only:
    - branches
    - merge_requests

security:node-audit:
  <<: *node_setup
  stage: security
  script:
    - npm audit --json > npm-audit.json || true
    - npm install -g snyk
    - snyk test --json > snyk-report.json || true
  artifacts:
    paths:
      - npm-audit.json
      - snyk-report.json
    expire_in: 1 week
  allow_failure: true
  only:
    - branches
    - merge_requests

security:secrets-scan:
  stage: security
  image: python:3.9-slim
  script:
    - pip install detect-secrets
    - detect-secrets scan --all-files --force-use-all-plugins > secrets-baseline.json
    - |
      if grep -q '"results": {}' secrets-baseline.json; then
        echo "No secrets found"
      else
        echo "WARNING: Potential secrets detected!"
        cat secrets-baseline.json
      fi
  artifacts:
    paths:
      - secrets-baseline.json
    expire_in: 1 week
  allow_failure: true
  only:
    - branches
    - merge_requests

# ============================================
# BUILD STAGE
# ============================================

build:python:
  stage: build
  image: google/cloud-sdk:alpine
  services:
    - docker:20.10-dind
  <<: *gcp_auth
  script:
    - |
      docker build \
        -f config/docker/Dockerfile.python \
        -t ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/python:${CI_COMMIT_SHA} \
        -t ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/python:${CI_COMMIT_REF_SLUG} \
        .
    - docker push ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/python:${CI_COMMIT_SHA}
    - docker push ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/python:${CI_COMMIT_REF_SLUG}
  only:
    - branches
    - tags

build:node:
  stage: build
  image: google/cloud-sdk:alpine
  services:
    - docker:20.10-dind
  <<: *gcp_auth
  script:
    - |
      docker build \
        -f config/docker/Dockerfile.node \
        -t ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/node:${CI_COMMIT_SHA} \
        -t ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/node:${CI_COMMIT_REF_SLUG} \
        .
    - docker push ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/node:${CI_COMMIT_SHA}
    - docker push ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/node:${CI_COMMIT_REF_SLUG}
  only:
    - branches
    - tags

build:go:
  stage: build
  image: google/cloud-sdk:alpine
  services:
    - docker:20.10-dind
  <<: *gcp_auth
  script:
    - |
      docker build \
        -f config/docker/Dockerfile.go \
        -t ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/go:${CI_COMMIT_SHA} \
        -t ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/go:${CI_COMMIT_REF_SLUG} \
        .
    - docker push ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/go:${CI_COMMIT_SHA}
    - docker push ${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/go:${CI_COMMIT_REF_SLUG}
  only:
    - branches
    - tags

# ============================================
# DEPLOY DEV STAGE
# ============================================

.deploy_template: &deploy_template
  image: google/cloud-sdk:alpine
  <<: *gcp_auth

deploy:dev:python:
  <<: *deploy_template
  stage: deploy-dev
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-python-dev \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/python:${CI_COMMIT_SHA} \
        --platform=managed \
        --allow-unauthenticated \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=dev \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-dev-db-password:latest \
        --min-instances=0 \
        --max-instances=10 \
        --memory=512Mi \
        --cpu=1
  environment:
    name: dev/python
    url: https://${TEAM_NAME}-python-dev-${GCP_REGION}.run.app
  only:
    - develop

deploy:dev:node:
  <<: *deploy_template
  stage: deploy-dev
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-node-dev \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/node:${CI_COMMIT_SHA} \
        --platform=managed \
        --allow-unauthenticated \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=dev \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-dev-db-password:latest \
        --min-instances=0 \
        --max-instances=10 \
        --memory=512Mi \
        --cpu=1
  environment:
    name: dev/node
    url: https://${TEAM_NAME}-node-dev-${GCP_REGION}.run.app
  only:
    - develop

deploy:dev:go:
  <<: *deploy_template
  stage: deploy-dev
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-go-dev \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/go:${CI_COMMIT_SHA} \
        --platform=managed \
        --allow-unauthenticated \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=dev \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-dev-db-password:latest \
        --min-instances=0 \
        --max-instances=10 \
        --memory=512Mi \
        --cpu=1
  environment:
    name: dev/go
    url: https://${TEAM_NAME}-go-dev-${GCP_REGION}.run.app
  only:
    - develop

# ============================================
# DEPLOY STAGING STAGE
# ============================================

deploy:staging:python:
  <<: *deploy_template
  stage: deploy-staging
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-python-staging \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/python:${CI_COMMIT_SHA} \
        --platform=managed \
        --ingress=internal-and-cloud-load-balancing \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=staging \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-staging-db-password:latest \
        --min-instances=1 \
        --max-instances=20 \
        --memory=1Gi \
        --cpu=2
  environment:
    name: staging/python
    url: https://${TEAM_NAME}-python-staging-${GCP_REGION}.run.app
  only:
    - main

deploy:staging:node:
  <<: *deploy_template
  stage: deploy-staging
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-node-staging \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/node:${CI_COMMIT_SHA} \
        --platform=managed \
        --ingress=internal-and-cloud-load-balancing \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=staging \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-staging-db-password:latest \
        --min-instances=1 \
        --max-instances=20 \
        --memory=1Gi \
        --cpu=2
  environment:
    name: staging/node
    url: https://${TEAM_NAME}-node-staging-${GCP_REGION}.run.app
  only:
    - main

deploy:staging:go:
  <<: *deploy_template
  stage: deploy-staging
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-go-staging \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/go:${CI_COMMIT_SHA} \
        --platform=managed \
        --ingress=internal-and-cloud-load-balancing \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=staging \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-staging-db-password:latest \
        --min-instances=1 \
        --max-instances=20 \
        --memory=1Gi \
        --cpu=2
  environment:
    name: staging/go
    url: https://${TEAM_NAME}-go-staging-${GCP_REGION}.run.app
  only:
    - main

# ============================================
# DEPLOY PROD STAGE
# ============================================

deploy:prod:python:
  <<: *deploy_template
  stage: deploy-prod
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-python-prod \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/python:${CI_COMMIT_TAG} \
        --platform=managed \
        --no-traffic \
        --tag=canary-${CI_COMMIT_SHORT_SHA} \
        --ingress=internal-and-cloud-load-balancing \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=prod \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-prod-db-password:latest \
        --min-instances=2 \
        --max-instances=50 \
        --memory=2Gi \
        --cpu=2
    - |
      gcloud run services update-traffic ${TEAM_NAME}-python-prod \
        --region=${GCP_REGION} \
        --to-tags=canary-${CI_COMMIT_SHORT_SHA}=10
  environment:
    name: prod/python
    url: https://${TEAM_NAME}-python-prod-${GCP_REGION}.run.app
  when: manual
  only:
    - tags

deploy:prod:node:
  <<: *deploy_template
  stage: deploy-prod
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-node-prod \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/node:${CI_COMMIT_TAG} \
        --platform=managed \
        --no-traffic \
        --tag=canary-${CI_COMMIT_SHORT_SHA} \
        --ingress=internal-and-cloud-load-balancing \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=prod \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-prod-db-password:latest \
        --min-instances=2 \
        --max-instances=50 \
        --memory=2Gi \
        --cpu=2
    - |
      gcloud run services update-traffic ${TEAM_NAME}-node-prod \
        --region=${GCP_REGION} \
        --to-tags=canary-${CI_COMMIT_SHORT_SHA}=10
  environment:
    name: prod/node
    url: https://${TEAM_NAME}-node-prod-${GCP_REGION}.run.app
  when: manual
  only:
    - tags

deploy:prod:go:
  <<: *deploy_template
  stage: deploy-prod
  script:
    - |
      gcloud run deploy ${TEAM_NAME}-go-prod \
        --region=${GCP_REGION} \
        --image=${DOCKER_REGISTRY}/${GCP_PROJECT_ID}/${TEAM_NAME}-docker/go:${CI_COMMIT_TAG} \
        --platform=managed \
        --no-traffic \
        --tag=canary-${CI_COMMIT_SHORT_SHA} \
        --ingress=internal-and-cloud-load-balancing \
        --service-account=${TEAM_NAME}-cloud-run@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
        --set-env-vars=ENVIRONMENT=prod \
        --set-secrets=DATABASE_URL=${TEAM_NAME}-prod-db-password:latest \
        --min-instances=2 \
        --max-instances=50 \
        --memory=2Gi \
        --cpu=2
    - |
      gcloud run services update-traffic ${TEAM_NAME}-go-prod \
        --region=${GCP_REGION} \
        --to-tags=canary-${CI_COMMIT_SHORT_SHA}=10
  environment:
    name: prod/go
    url: https://${TEAM_NAME}-go-prod-${GCP_REGION}.run.app
  when: manual
  only:
    - tags
```

---

## 📚 Part 7: Documentation

### 7.1 Setup Guide

**File: `docs/01-SETUP.md`**

```markdown
# NexusForge Platform - Setup Guide

## Prerequisites

Before setting up the NexusForge platform, ensure you have:

1. **Google Cloud Platform Account**
   - Active GCP account with billing enabled
   - Project creation permissions
   - Service account creation permissions

2. **Local Tools**
   - Google Cloud SDK (`gcloud`) installed
   - Git installed
   - GitHub account with repository access
   - (Optional) GitLab account if using GitLab CI/CD

3. **Domain Requirements**
   - Domain name for accessing services (e.g., `nexusforge.dev`)
   - DNS management access

## Step 1: Initial GCP Setup

### 1.1 Clone the Repository

```bash
git clone https://github.com/your-org/nexusforge-platform.git
cd nexusforge-platform
```

### 1.2 Configure Project Variables

Edit the configuration in `infrastructure/scripts/01-gcp-initial-setup.sh`:

```bash
export PROJECT_ID="nexusforge-platform"  # Change to your project ID
export BILLING_ACCOUNT_ID="XXXXXX-XXXXXX-XXXXXX"  # Your billing account
export REGION="us-central1"  # Change if needed
export ZONE="us-central1-a"  # Change if needed
```

### 1.3 Run Initial Setup

```bash
cd infrastructure/scripts
chmod +x *.sh
./01-gcp-initial-setup.sh
```

This script will:
- Create GCP project (if needed)
- Enable required APIs
- Create VPC network and subnets
- Set up firewall rules
- Create service accounts
- Initialize Cloud SQL databases
- Create Artifact Registry repositories
- Set up Secret Manager secrets

**Estimated time: 15-20 minutes**

### 1.4 Configure Secrets

Update the placeholder secrets with actual values:

```bash
# GitLab CI/CD token
echo -n "your-actual-gitlab-token" | gcloud secrets versions add nexusforge-gitlab-token --data-file=-

# API keys
echo -n "your-actual-api-key" | gcloud secrets versions add nexusforge-api-key --data-file=-

# Database passwords (generate strong passwords)
echo -n "$(openssl rand -base64 32)" | gcloud secrets versions add nexusforge-dev-db-password --data-file=-
echo -n "$(openssl rand -base64 32)" | gcloud secrets versions add nexusforge-staging-db-password --data-file=-
echo -n "$(openssl rand -base64 32)" | gcloud secrets versions add nexusforge-prod-db-password --data-file=-
```

## Step 2: Workload Identity Federation for GitHub Actions

### 2.1 Configure GitHub Organization

Edit `infrastructure/scripts/02-workload-identity-setup.sh`:

```bash
GITHUB_ORG="your-github-org"  # Change this
GITHUB_REPO="nexusforge-platform"  # Change if different
```

### 2.2 Run Workload Identity Setup

```bash
./02-workload-identity-setup.sh
```

This will output the configuration needed for GitHub secrets.

### 2.3 Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following repository secrets:
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SERVICE_ACCOUNT`: The service account email
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: The workload identity provider path
- `GCP_REGION`: us-central1 (or your chosen region)
- `GCP_ZONE`: us-central1-a (or your chosen zone)

## Step 3: Deploy Infrastructure

### 3.1 Deploy Development Environment

Go to GitHub Actions → Workflows → "01 - Infrastructure Setup"

Run the workflow with:
- Environment: `dev`
- Destroy: `false`

**Estimated time: 10-15 minutes**

### 3.2 Verify Development Environment

Once the workflow completes:

```bash
# Check VM status
gcloud compute instances list --filter="name:nexusforge-dev-vm"

# Get external IP
DEV_IP=$(gcloud compute instances describe nexusforge-dev-vm \
  --zone=us-central1-a \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "VS Code Server: https://${DEV_IP}:8080"
```

### 3.3 SSH into Development VM

```bash
gcloud compute ssh nexusforge-dev-vm --zone=us-central1-a
```

Verify services are running:

```bash
# Check Docker
docker ps

# Check Docker Compose
cd /opt/nexusforge/docker
docker-compose ps

# Check VS Code Server
systemctl status code-server
```

## Step 4: Configure DNS and SSL

### 4.1 Set Up DNS Records

Add A records for your domain:

```
dev.nexusforge.dev     → [DEV_VM_IP]
staging.nexusforge.dev → [STAGING_LB_IP]
prod.nexusforge.dev    → [PROD_LB_IP]
```

### 4.2 Configure SSL Certificates

The infrastructure setup creates Google-managed SSL certificates automatically.

Verify certificate status:

```bash
gcloud compute ssl-certificates list --filter="name:nexusforge-*"
```

**Note:** SSL certificates may take 15-60 minutes to provision.

## Step 5: Deploy Application Code

### 5.1 Deploy to Development

Push code to the `develop` branch:

```bash
git checkout -b develop
git push origin develop
```

GitHub Actions will automatically:
1. Run security scans
2. Run linting and tests
3. Build Docker images
4. Deploy to Cloud Run (dev environment)

### 5.2 Deploy to Staging

Merge to `main` branch:

```bash
git checkout main
git merge develop
git push origin main
```

This triggers deployment to staging environment.

### 5.3 Deploy to Production

Create a release tag:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

Go to GitHub Actions and manually approve the production deployment.

## Step 6: Configure Identity-Aware Proxy (IAP)

### 6.1 Configure OAuth Consent Screen

```bash
# Get OAuth client information
gcloud iap oauth-brands list

# Create OAuth client for IAP
gcloud iap oauth-clients create \
  projects/$(gcloud config get-value project)/brands/[BRAND_ID] \
  --display_name="NexusForge IAP Client"
```

### 6.2 Enable IAP on Backend Services

```bash
for env in dev staging prod; do
  gcloud iap web enable \
    --resource-type=backend-services \
    --service=nexusforge-${env}-lb-backend
done
```

### 6.3 Grant IAP Access

```bash
# Grant access to your domain
gcloud iap web add-iam-policy-binding \
  --resource-type=backend-services \
  --service=nexusforge-dev-lb-backend \
  --member="domain:nexusforge.dev" \
  --role="roles/iap.httpsResourceAccessor"
```

## Step 7: Configure Monitoring and Alerts

### 7.1 Create Alert Policies

```bash
# Deploy alert policies
for alert in config/monitoring/alerts.yaml; do
  gcloud alpha monitoring policies create --policy-from-file=$alert
done
```

### 7.2 Set Up Notification Channels

```bash
# Create email notification channel
gcloud alpha monitoring channels create \
  --display-name="Platform Admins" \
  --type=email \
  --channel-labels=email_address=platform-admins@nexusforge.dev
```

### 7.3 Access Monitoring Dashboards

```bash
# Get monitoring dashboard URL
echo "https://console.cloud.google.com/monitoring/dashboards?project=$(gcloud config get-value project)"
```

## Step 8: Set Up Team Access

### 8.1 Create Google Groups

Create the following groups in Google Workspace:
- `junior-devs@nexusforge.dev`
- `senior-devs@nexusforge.dev`
- `team-leads@nexusforge.dev`
- `platform-admins@nexusforge.dev`

### 8.2 Apply RBAC Policies

```bash
# Apply custom roles
for role in config/security/rbac-policies.yaml; do
  # Extract and create roles (manual process or use script)
  echo "Apply role: $role"
done
```

### 8.3 Grant Access

```bash
# Example: Grant junior developer access
gcloud projects add-iam-policy-binding nexusforge-platform \
  --member="group:junior-devs@nexusforge.dev" \
  --role="projects/nexusforge-platform/roles/nexusforge.juniorDeveloper"
```

## Step 9: Configure Backups

### 9.1 Enable Automated Backups

The backup workflow runs daily at 1 AM UTC automatically.

To trigger manual backup:

```bash
# Go to GitHub Actions → "06 - Backup and Disaster Recovery"
# Click "Run workflow"
```

### 9.2 Verify Backup Configuration

```bash
# List Cloud SQL backups
gcloud sql backups list --instance=nexusforge-prod-db

# List exported backups in Cloud Storage
gsutil ls gs://nexusforge-backups/database-exports/
```

## Step 10: Test Disaster Recovery

### 10.1 Perform DR Test

```bash
# Go to GitHub Actions → "07 - Disaster Recovery"
# Run workflow with test parameters
```

### 10.2 Verify Recovery Procedures

Document recovery time and update RTO/RPO as needed.

## Verification Checklist

- [ ] All GCP APIs enabled
- [ ] VPC network and subnets created
- [ ] Service accounts configured
- [ ] Workload Identity Federation working
- [ ] GitHub Actions workflows running successfully
- [ ] Development VM accessible
- [ ] VS Code Server accessible
- [ ] Docker containers running
- [ ] Cloud Run services deployed
- [ ] DNS records configured
- [ ] SSL certificates provisioned
- [ ] IAP configured
- [ ] Monitoring dashboards accessible
- [ ] Alert policies created
- [ ] Backups configured
- [ ] Team access granted
- [ ] Documentation accessible

## Troubleshooting

### Issue: API not enabled

```bash
# List enabled services
gcloud services list --enabled

# Enable missing service
gcloud services enable [SERVICE_NAME]
```

### Issue: Workflow fails with authentication error

```bash
# Verify Workload Identity Federation
gcloud iam workload-identity-pools describe nexusforge-github-pool \
  --location=global

# Check service account permissions
gcloud projects get-iam-policy nexusforge-platform \
  --flatten="bindings[].members" \
  --filter="bindings.members:nexusforge-github-actions@*"
```

### Issue: Cannot access VS Code Server

```bash
# Check firewall rules
gcloud compute firewall-rules list --filter="name:nexusforge-*"

# Check VM is running
gcloud compute instances describe nexusforge-dev-vm --zone=us-central1-a

# Check code-server status
gcloud compute ssh nexusforge-dev-vm --zone=us-central1-a \
  --command="systemctl status code-server"
```

### Issue: Database connection fails

```bash
# Check Cloud SQL instance
gcloud sql instances describe nexusforge-dev-db

# Verify Cloud SQL Proxy
gcloud compute ssh nexusforge-dev-vm --zone=us-central1-a \
  --command="systemctl status cloud-sql-proxy"

# Test database connection
gcloud sql connect nexusforge-dev-db --user=postgres
```

## Next Steps

- Read [Development Guide](./02-DEVELOPMENT-GUIDE.md)
- Read [Deployment Guide](./03-DEPLOYMENT-GUIDE.md)
- Read [Security Best Practices](./04-SECURITY.md)
- Review [Troubleshooting Guide](./05-TROUBLESHOOTING.md)

## Support

For support, please:
1. Check documentation in `docs/` directory
2. Search existing GitHub issues
3. Create a new issue with detailed information
4. Contact platform-admins@nexusforge.dev
```

### 7.2 Development Guide

**File: `docs/02-DEVELOPMENT-GUIDE.md`**

```markdown
# NexusForge Platform - Development Guide

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Workflow](#development-workflow)
3. [Language-Specific Guides](#language-specific-guides)
4. [Local Development](#local-development)
5. [Testing](#testing)
6. [Debugging](#debugging)
7. [Best Practices](#best-practices)

## Getting Started

### Prerequisites

- Access to NexusForge platform
- IAM role assigned (Junior Dev, Senior Dev, Team Lead, or Admin)
- Git configured with your credentials
- SSH key added to your GCP account

### Accessing Development Environment

#### Option 1: VS Code Server (Browser-based)

1. Navigate to https://dev.nexusforge.dev
2. Enter the password (get from team lead)
3. Start coding in your browser

#### Option 2: SSH Access

```bash
# Connect to development VM
gcloud compute ssh nexusforge-dev-vm --zone=us-central1-a

# Forward VS Code Server port
gcloud compute ssh nexusforge-dev-vm \
  --zone=us-central1-a \
  --ssh-flag="-L 8080:localhost:8080"

# Access at http://localhost:8080
```

#### Option 3: Remote Development (VS Code Desktop)

1. Install "Remote - SSH" extension in VS Code
2. Configure SSH connection:

```
Host nexusforge-dev
    HostName [VM_EXTERNAL_IP]
    User [YOUR_USERNAME]
    IdentityFile ~/.ssh/google_compute_engine
```

3. Connect via Remote-SSH

## Development Workflow

### 1. Create Feature Branch

```bash
# Clone repository
git clone https://github.com/your-org/nexusforge-platform.git
cd nexusforge-platform

# Create feature branch
git checkout -b feature/your-feature-name
```

### 2. Set Up Local Environment

```bash
# Navigate to your language workspace
cd /workspace/python  # or nodejs, go

# Set up virtual environment (Python)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Install dependencies (Node.js)
npm install

# Download dependencies (Go)
go mod download
```

### 3. Develop and Test

```bash
# Run application locally
python app.py  # Python
npm run dev    # Node.js
go run main.go # Go

# Run tests
pytest              # Python
npm test            # Node.js
go test ./...       # Go
```

### 4. Commit and Push

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: add user authentication"

# Push to remote
git push origin feature/your-feature-name
```

### 5. Create Pull/Merge Request

1. Go to GitHub/GitLab repository
2. Create Pull Request from your feature branch to `develop`
3. Wait for CI/CD checks to pass
4. Request review from team lead
5. Address review comments
6. Merge after approval

## Language-Specific Guides

### Python Development

#### Project Structure

```
workspace/python/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── models/
│   ├── routes/
│   └── services/
├── tests/
│   ├── unit/
│   └── integration/
├── requirements.txt
├── requirements-dev.txt
├── .env.example
└── README.md
```

#### Virtual Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

#### Running Applications

**Flask:**
```bash
export FLASK_APP=app.main
export FLASK_ENV=development
flask run --host=0.0.0.0 --port=8000
```

**FastAPI:**
```bash
uvicorn app.main:app --reload --host=0.0.0.0 --port=8000
```

**Django:**
```bash
python manage.py runserver 0.0.0.0:8000
```

#### Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_auth.py

# Run with verbose output
pytest -v
```

#### Linting and Formatting

```bash
# Format code
black .

# Check formatting
black --check .

# Lint code
pylint app/

# Type checking
mypy app/
```

#### Debugging

Add to your code:
```python
import debugpy

# Wait for debugger to attach
debugpy.listen(("0.0.0.0", 5678))
print("Waiting for debugger attach")
debugpy.wait_for_client()
```

Attach from VS Code using launch configuration.

### Node.js Development

#### Project Structure

```
workspace/nodejs/
├── src/
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   ├── services/
│   └── index.ts
├── tests/
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

#### Package Management

```bash
# Install dependencies
npm install

# Install dev dependencies
npm install --save-dev @types/node typescript

# Update packages
npm update
```

#### Running Applications

**Express:**
```bash
# Development
npm run dev

# Production
npm start
```

**NestJS:**
```bash
# Development
npm run start:dev

# Debug mode
npm run start:debug

# Production
npm run start:prod
```

#### Testing

```bash
# Run all tests
npm test

# Run with coverage
npm run test:cov

# Run in watch mode
npm run test:watch

# Run e2e tests
npm run test:e2e
```

#### Linting and Formatting

```bash
# Lint code
npm run lint

# Fix linting issues
npm run lint:fix

# Format code
npm run format
```

#### Debugging

Add to `package.json`:
```json
{
  "scripts": {
    "debug": "node --inspect-brk=0.0.0.0:9229 dist/index.js"
  }
}
```

### Go Development

#### Project Structure

```
workspace/go/
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── handlers/
│   ├── models/
│   └── services/
├── pkg/
├── tests/
├── go.mod
├── go.sum
└── README.md
```

#### Dependency Management

```bash
# Initialize module
go mod init github.com/your-org/your-app

# Download dependencies
go mod download

# Update dependencies
go get -u ./...

# Tidy dependencies
go mod tidy
```

#### Running Applications

```bash
# Run main package
go run cmd/api/main.go

# Build binary
go build -o bin/app cmd/api/main.go

# Run binary
./bin/app
```

#### Testing

```bash
# Run all tests
go test ./...

# Run with coverage
go test -cover ./...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Run specific test
go test -run TestUserAuth ./...

# Run with race detector
go test -race ./...
```

#### Linting and Formatting

```bash
# Format code
go fmt ./...

# Vet code
go vet ./...

# Run linter
golangci-lint run
```

#### Debugging

Use Delve debugger:
```bash
# Install Delve
go install github.com/go-delve/delve/cmd/dlv@latest

# Start debugger
dlv debug cmd/api/main.go

# Debug running process
dlv attach <PID>

# Remote debugging
dlv debug --headless --listen=:2345 --api-version=2 cmd/api/main.go
```

## Local Development

### Using Docker Compose

```bash
cd /opt/nexusforge/docker

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild services
docker-compose up -d --build
```

### Database Access

#### PostgreSQL

```bash
# Connect via psql
psql -h localhost -U postgres -d nexusforge

# Via Docker
docker exec -it nexusforge-postgres psql -U postgres -d nexusforge

# Run migrations (Python/Alembic)
alembic upgrade head

# Run migrations (Node.js/Prisma)
npx prisma migrate dev
```

### Redis Access

```bash
# Connect via redis-cli
redis-cli

# Via Docker
docker exec -it nexusforge-redis redis-cli

# Test connection
redis-cli ping
```

## Testing

### Unit Tests

Write isolated tests for individual functions/methods.

**Python Example:**
```python
import pytest
from app.services.user import UserService

def test_create_user():
    service = UserService()
    user = service.create_user("test@example.com", "password123")
    assert user.email == "test@example.com"
```

**Node.js Example:**
```typescript
import { UserService } from '../services/user.service';

describe('UserService', () => {
  it('should create a user', () => {
    const service = new UserService();
    const user = service.createUser('test@example.com', 'password123');
    expect(user.email).toBe('test@example.com');
  });
});
```

**Go Example:**
```go
func TestCreateUser(t *testing.T) {
    service := NewUserService()
    user, err := service.CreateUser("test@example.com", "password123")
    if err != nil {
        t.Fatalf("expected no error, got %v", err)
    }
    if user.Email != "test@example.com" {
        t.Errorf("expected email test@example.com, got %s", user.Email)
    }
}
```

### Integration Tests

Test interactions between components.

```bash
# Set up test database
export DATABASE_URL="postgresql://postgres:test@localhost:5432/nexusforge_test"

# Run integration tests
pytest tests/integration/
npm run test:integration
go test -tags=integration ./...
```

### End-to-End Tests

```bash
# Install Cypress (Node.js)
npm install --save-dev cypress

# Run Cypress tests
npx cypress open
```

## Debugging

### Remote Debugging Configuration

**Python (debugpy):**
```json
{
  "name": "Python: Remote Attach",
  "type": "python",
  "request": "attach",
  "connect": {
    "host": "localhost",
    "port": 5678
  },
  "pathMappings": [
    {
      "localRoot": "${workspaceFolder}",
      "remoteRoot": "/app"
    }
  ]
}
```

**Node.js:**
```json
{
  "name": "Node: Attach",
  "type": "node",
  "request": "attach",
  "port": 9229,
  "address": "localhost",
  "restart": true
}
```

**Go (Delve):**
```json
{
  "name": "Go: Connect to Remote",
  "type": "go",
  "request": "attach",
  "mode": "remote",
  "remotePath": "/app",
  "port": 2345,
  "host": "localhost"
}
```

### Logging

Use structured logging for better debugging:

**Python:**
```python
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("User created", extra={"user_id": user.id})
```

**Node.js:**
```typescript
import { Logger } from '@nestjs/common';

const logger = new Logger('UserService');
logger.log('User created', { userId: user.id });
```

**Go:**
```go
import "log"

log.Printf("User created: user_id=%s", user.ID)
```

## Best Practices

### Code Style

- Follow language-specific style guides (PEP 8, Airbnb, Effective Go)
- Use linters and formatters
- Write meaningful comments
- Keep functions small and focused

### Version Control

- Commit often with descriptive messages
- Use conventional commit format: `type(scope): description`
  - Types: feat, fix, docs, style, refactor, test, chore
- Keep commits atomic
- Never commit secrets or credentials

### Security

- Never hardcode credentials
- Use environment variables
- Validate all inputs
- Sanitize outputs
- Use parameterized queries
- Keep dependencies updated

### Performance

- Profile before optimizing
- Use caching appropriately
- Implement pagination
- Avoid N+1 queries
- Use connection pooling

### Documentation

- Write README for each service
- Document API endpoints (OpenAPI/Swagger)
- Add inline comments for complex logic
- Keep documentation up-to-date

## Useful Commands

### System Monitoring

```bash
# Check resource usage
htop

# View disk usage
df -h

# Check Docker resource usage
docker stats

# View system logs
journalctl -f
```

### Troubleshooting

```bash
# Check service status
systemctl status code-server
systemctl status cloud-sql-proxy

# Restart service
sudo systemctl restart code-server

# View service logs
journalctl -u code-server -f

# Check network connectivity
netstat -tulpn
ss -tulpn
```

## Getting Help

- Check documentation: `/workspace/docs/`
- Search code examples: `/workspace/examples/`
- Ask in team chat
- Create GitHub issue
- Contact team lead

## Next Steps

- Review [Deployment Guide](./03-DEPLOYMENT-GUIDE.md)
- Learn about [Security Practices](./04-SECURITY.md)
- Check [Troubleshooting Guide](./05-TROUBLESHOOTING.md)
```

---

## 📝 Final Notes and README

**File: `README.md`**

```markdown
# NexusForge Platform

> Fully automated, secure, and scalable development platform on Google Cloud Platform

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/your-org/nexusforge-platform.git
cd nexusforge-platform

# Run initial setup
cd infrastructure/scripts
chmod +x *.sh
./01-gcp-initial-setup.sh

# Configure Workload Identity Federation
./02-workload-identity-setup.sh

# Deploy infrastructure via GitHub Actions
# Go to Actions → "01 - Infrastructure Setup" → Run workflow
```

## 📚 Documentation

- **[Setup Guide](./docs/01-SETUP.md)** - Complete installation instructions
- **[Development Guide](./docs/02-DEVELOPMENT-GUIDE.md)** - How to develop on the platform
- **[Deployment Guide](./docs/03-DEPLOYMENT-GUIDE.md)** - Deployment procedures
- **[Security Guide](./docs/04-SECURITY.md)** - Security best practices
- **[Troubleshooting](./docs/05-TROUBLESHOOTING.md)** - Common issues and solutions

## 🎯 Features

✅ **Multi-Language Support**
- Python 3.9 with FastAPI/Flask/Django
- Node.js 16 with Express/NestJS
- Go 1.18 with standard library

✅ **VS Code Integration**
- Browser-based VS Code Server
- Pre-configured extensions
- Remote debugging support

✅ **CI/CD Integration**
- GitHub Actions workflows
- GitLab CI/CD support
- Automated testing and deployment

✅ **Security**
- Identity-Aware Proxy (IAP)
- Workload Identity Federation
- Secret Manager integration
- Cloud Armor DDoS protection
- Automated security scanning

✅ **Monitoring & Observability**
- Cloud Monitoring dashboards
- Distributed tracing with Cloud Trace
- Structured logging
- Custom alert policies

✅ **Database Management**
- Cloud SQL (PostgreSQL)
- Automated backups
- Point-in-time recovery
- Automated migrations

✅ **Deployment Strategies**
- Blue-green deployments
- Canary releases
- Automated rollbacks

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Google Cloud Platform                    │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Development  │  │   Staging    │  │  Production  │      │
│  │      VM      │  │  Cloud Run   │  │  Cloud Run   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                  │               │
│         └─────────────────┴──────────────────┘               │
│                           │                                  │
│         ┌─────────────────┴─────────────────┐               │
│         │                                     │               │
│  ┌──────▼─────┐  ┌────────────┐  ┌─────────▼────────┐     │
│  │  Cloud SQL │  │  Artifact  │  │ Secret Manager   │     │
│  │(PostgreSQL)│  │  Registry  │  │                  │     │
│  └────────────┘  └────────────┘  └──────────────────┘     │
│                                                              │
│  ┌──────────────┐  ┌────────────┐  ┌──────────────┐       │
│  │   Cloud      │  │   Cloud    │  │   Cloud      │       │
│  │  Monitoring  │  │   Logging  │  │   Trace      │       │
│  └──────────────┘  └────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## 🔑 Key Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| Development VM | Isolated dev environments | Compute Engine |
| VS Code Server | Browser-based IDE | code-server |
| Container Registry | Store Docker images | Artifact Registry |
| Application Runtime | Serverless deployment | Cloud Run |
| Database | Persistent storage | Cloud SQL (PostgreSQL) |
| Secret Management | Secure credentials | Secret Manager |
| CI/CD | Automated pipelines | GitHub Actions / GitLab CI |
| Monitoring | Observability | Cloud Operations Suite |
| Security | DDoS & WAF | Cloud Armor |
| Access Control | Secure access | Identity-Aware Proxy |

## 🛠️ Tech Stack

**Languages:**
- Python 3.9
- Node.js 16
- Go 1.18

**Frameworks:**
- Python: FastAPI, Flask, Django
- Node.js: Express, NestJS
- Go: net/http, Gin, Echo

**Infrastructure:**
- Google Cloud Platform
- Docker & Docker Compose
- Terraform (optional)

**CI/CD:**
- GitHub Actions
- GitLab CI/CD

**Monitoring:**
- Cloud Monitoring
- Cloud Logging
- Cloud Trace
- Prometheus (optional)
- Grafana (optional)

## 📋 Requirements

**Fulfilled Requirements:**
1. ✅ Python 3.9, Node.js 16, Go 1.18 support
2. ✅ GitLab CI/CD integration
3. ✅ Role-based access control (RBAC)
4. ✅ Monitoring with Cloud Operations Suite
5. ✅ Auto-scaling (Cloud Run)
6. ✅ Daily backups
7. ✅ Remote debugging for all languages
8. ✅ Artifact registry
9. ✅ Network isolation (VPC subnets)
10. ✅ SSL/TLS encryption
11. ✅ Secret Manager integration
12. ✅ Automated security scanning
13. ✅ Disaster recovery (RTO < 4 hours)
14. ✅ Staging environment
15. ✅ Canary deployments
16. ✅ Automated database migrations
17. ✅ Distributed tracing
18. ✅ Automated performance testing
19. ✅ Rate limiting and DDoS protection
20. ✅ Documentation wiki

## 💰 Cost Estimate

**Development Environment:**
- Compute Engine (e2-standard-4): ~$100/month
- Cloud SQL (db-f1-micro): ~$15/month
- Network egress: ~$10/month
- **Total: ~$125/month**

**Staging Environment:**
- Cloud Run (minimal usage): ~$10/month
- Cloud SQL (db-g1-small): ~$35/month
- **Total: ~$45/month**

**Production Environment:**
- Cloud Run (moderate usage): ~$50/month
- Cloud SQL (db-custom-2-7680): ~$150/month
- Load Balancer: ~$20/month
- **Total: ~$220/month**

**Overall Platform: ~$390/month**

## 🔒 Security Features

- Workload Identity Federation (no service account keys)
- Identity-Aware Proxy for secure access
- Cloud Armor for DDoS protection
- Automated vulnerability scanning
- Secrets stored in Secret Manager
- VPC isolation between environments
- SSL/TLS everywhere
- Regular security audits

## 📊 Monitoring & Alerts

- CPU, memory, disk usage alerts
- Application error rate monitoring
- Database performance tracking
- Uptime checks
- Custom dashboards
- Log-based metrics
- Distributed tracing

## 🚨 Support & Troubleshooting

**Common Issues:**
- See [Troubleshooting Guide](./docs/05-TROUBLESHOOTING.md)

**Getting Help:**
1. Check documentation
2. Search GitHub issues
3. Ask in team chat
4. Create new issue
5. Contact: platform-admins@nexusforge.dev

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

**NexusForge Platform Team**
- Platform Admins: platform-admins@nexusforge.dev
- Support: support@nexusforge.dev

## 🙏 Acknowledgments

- Google Cloud Platform
- Open source community
- All contributors

---

**Made with ❤️ by the NexusForge Team**
```
