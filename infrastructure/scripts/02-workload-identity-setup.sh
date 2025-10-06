#!/usr/bin/env bash

# ============================================
# NexusForge Platform - Workload Identity Federation Setup
# ============================================
# Configure Workload Identity Federation for GitHub Actions
# Enables keyless authentication from GitHub Actions to GCP
#
# Usage:
#   ./02-workload-identity-setup.sh --project-id PROJECT_ID --github-org ORG --github-repo REPO
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
GITHUB_ORG=""
GITHUB_REPO=""
POOL_ID="github-actions-pool"
PROVIDER_ID="github-actions-provider"
SERVICE_ACCOUNT=""

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
            --github-org)
                GITHUB_ORG="$2"
                shift 2
                ;;
            --github-repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            --pool-id)
                POOL_ID="$2"
                shift 2
                ;;
            --provider-id)
                PROVIDER_ID="$2"
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
    if [[ -z "$PROJECT_ID" ]] || [[ -z "$GITHUB_ORG" ]] || [[ -z "$GITHUB_REPO" ]]; then
        print_error "Missing required arguments"
        show_help
        exit 1
    fi
    
    SERVICE_ACCOUNT="nexusforge-github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
}

show_help() {
    cat << EOF
Usage: $0 --project-id PROJECT_ID --github-org ORG --github-repo REPO [OPTIONS]

Configure Workload Identity Federation for GitHub Actions

Required Arguments:
  --project-id ID       GCP Project ID
  --github-org ORG      GitHub Organization or Username
  --github-repo REPO    GitHub Repository name

Optional Arguments:
  --pool-id ID         Workload Identity Pool ID (default: github-actions-pool)
  --provider-id ID     Provider ID (default: github-actions-provider)
  -h, --help           Show this help message

Example:
  $0 --project-id my-project --github-org myorg --github-repo nexusforge-platform
EOF
}

# Get project number
get_project_number() {
    print_step "Getting project number..."
    
    PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" \
        --format="value(projectNumber)")
    
    print_success "Project number: ${PROJECT_NUMBER}"
}

# Create Workload Identity Pool
create_workload_identity_pool() {
    print_step "Creating Workload Identity Pool..."
    
    if gcloud iam workload-identity-pools describe "${POOL_ID}" \
        --location=global --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "Workload Identity Pool '${POOL_ID}' already exists"
    else
        gcloud iam workload-identity-pools create "${POOL_ID}" \
            --project="${PROJECT_ID}" \
            --location=global \
            --display-name="GitHub Actions Pool" \
            --description="Workload Identity Pool for GitHub Actions"
        
        print_success "Workload Identity Pool created: ${POOL_ID}"
    fi
}

# Create Workload Identity Provider
create_workload_identity_provider() {
    print_step "Creating Workload Identity Provider..."
    
    if gcloud iam workload-identity-pools providers describe "${PROVIDER_ID}" \
        --workload-identity-pool="${POOL_ID}" \
        --location=global --project="${PROJECT_ID}" &>/dev/null; then
        print_warning "Workload Identity Provider '${PROVIDER_ID}' already exists"
    else
        gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_ID}" \
            --project="${PROJECT_ID}" \
            --location=global \
            --workload-identity-pool="${POOL_ID}" \
            --display-name="GitHub Actions Provider" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-condition="assertion.repository_owner == '${GITHUB_ORG}'"
        
        print_success "Workload Identity Provider created: ${PROVIDER_ID}"
    fi
}

# Grant service account access to Workload Identity Pool
grant_service_account_access() {
    print_step "Granting service account access..."
    
    # Create IAM policy binding
    gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT}" \
        --project="${PROJECT_ID}" \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"
    
    print_success "Service account access granted"
}

# Test Workload Identity configuration
test_workload_identity() {
    print_step "Testing Workload Identity configuration..."
    
    # Get the full provider resource name
    local provider_name="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
    
    print_info "Provider resource name: ${provider_name}"
    
    # Verify provider exists
    if gcloud iam workload-identity-pools providers describe "${PROVIDER_ID}" \
        --workload-identity-pool="${POOL_ID}" \
        --location=global \
        --project="${PROJECT_ID}" &>/dev/null; then
        print_success "Provider configuration verified"
    else
        print_error "Provider verification failed"
        return 1
    fi
}

# Generate GitHub secrets configuration
generate_github_secrets() {
    print_step "Generating GitHub Secrets configuration..."
    
    local provider_name="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
    
    cat << EOF

${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════════════╗
║                    GitHub Repository Secrets                          ║
╚═══════════════════════════════════════════════════════════════════════╝${NC}

Add the following secrets to your GitHub repository:
${CYAN}https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/secrets/actions${NC}

${BOLD}Required Secrets:${NC}

1. ${YELLOW}GCP_PROJECT_ID${NC}
   ${PROJECT_ID}

2. ${YELLOW}GCP_WORKLOAD_IDENTITY_PROVIDER${NC}
   ${provider_name}

3. ${YELLOW}GCP_SERVICE_ACCOUNT${NC}
   ${SERVICE_ACCOUNT}

${BOLD}Optional Secrets (set these manually):${NC}

4. ${YELLOW}POSTGRES_PASSWORD${NC}
   <your-secure-postgres-password>

5. ${YELLOW}REDIS_PASSWORD${NC}
   <your-secure-redis-password>

6. ${YELLOW}PROD_DATABASE_URL${NC}
   postgresql://user:pass@host:5432/dbname

7. ${YELLOW}PROD_REDIS_URL${NC}
   redis://password@host:6379/0

8. ${YELLOW}PROD_SECRET_KEY${NC}
   <your-secret-key-for-prod>

${BOLD}Environment-specific Database URLs:${NC}

9. ${YELLOW}DEV_DATABASE_URL${NC}
   postgresql://user:pass@host:5432/dev_db

10. ${YELLOW}STAGING_DATABASE_URL${NC}
    postgresql://user:pass@host:5432/staging_db

${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}

EOF
}

# Generate workflow configuration snippet
generate_workflow_snippet() {
    print_step "Generating workflow configuration snippet..."
    
    cat << EOF > /tmp/workload-identity-config.yaml
# Workload Identity Federation Configuration
# Add this to your GitHub Actions workflows

permissions:
  contents: read
  id-token: write  # Required for OIDC

steps:
  - name: Authenticate to Google Cloud
    uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: \${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: \${{ secrets.GCP_PROJECT_ID }}
EOF
    
    print_success "Workflow snippet saved to /tmp/workload-identity-config.yaml"
    cat /tmp/workload-identity-config.yaml
}

# Verify service account
verify_service_account() {
    print_step "Verifying service account..."
    
    if gcloud iam service-accounts describe "${SERVICE_ACCOUNT}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        print_success "Service account exists: ${SERVICE_ACCOUNT}"
    else
        print_error "Service account not found: ${SERVICE_ACCOUNT}"
        print_info "Run 01-gcp-initial-setup.sh first to create service accounts"
        exit 1
    fi
}

# Display summary
show_summary() {
    print_step "Setup Summary"
    
    echo ""
    echo -e "${GREEN}${BOLD}Workload Identity Federation Setup Completed!${NC}"
    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo "  Project ID: ${PROJECT_ID}"
    echo "  Project Number: ${PROJECT_NUMBER}"
    echo "  Pool ID: ${POOL_ID}"
    echo "  Provider ID: ${PROVIDER_ID}"
    echo "  Service Account: ${SERVICE_ACCOUNT}"
    echo "  GitHub Org: ${GITHUB_ORG}"
    echo "  GitHub Repo: ${GITHUB_REPO}"
    echo ""
    echo -e "${BOLD}Resources Created:${NC}"
    echo "  ✓ Workload Identity Pool: ${POOL_ID}"
    echo "  ✓ Workload Identity Provider: ${PROVIDER_ID}"
    echo "  ✓ IAM Policy Binding configured"
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. Add the GitHub secrets shown above to your repository"
    echo "  2. Test the workflow by pushing a commit"
    echo "  3. Verify authentication in GitHub Actions logs"
    echo ""
    echo -e "${YELLOW}Important:${NC} Keep the provider resource name secure!"
    echo ""
}

# ============================================
# Main Script Execution
# ============================================

main() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║   NexusForge Platform - Workload Identity Setup              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    parse_args "$@"
    verify_service_account
    get_project_number
    create_workload_identity_pool
    create_workload_identity_provider
    grant_service_account_access
    test_workload_identity
    generate_github_secrets
    generate_workflow_snippet
    show_summary
    
    print_success "Workload Identity Federation setup completed!"
}

main "$@"
