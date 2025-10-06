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
