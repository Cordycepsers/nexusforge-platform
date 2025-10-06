# Setup Guide

Complete installation and setup instructions for the NexusForge Platform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [GCP Account Setup](#gcp-account-setup)
3. [Local Development Setup](#local-development-setup)
4. [GitHub Configuration](#github-configuration)
5. [Infrastructure Deployment](#infrastructure-deployment)
6. [Service Deployment](#service-deployment)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

Install the following on your local machine:

#### 1. Git
```bash
# macOS
brew install git

# Linux
sudo apt-get install git

# Verify
git --version
```

#### 2. Docker Desktop
- Download from [docker.com](https://www.docker.com/products/docker-desktop)
- Verify installation:
```bash
docker --version
docker-compose --version
```

#### 3. Google Cloud SDK
```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash

# Initialize
gcloud init

# Verify
gcloud --version
```

#### 4. Node.js 16+ (for Node.js service)
```bash
# Using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 16
nvm use 16

# Verify
node --version
npm --version
```

#### 5. Python 3.9+ (for Python service)
```bash
# macOS
brew install python@3.9

# Linux
sudo apt-get install python3.9 python3.9-venv

# Verify
python3 --version
pip3 --version
```

#### 6. Go 1.18+ (for Go service)
```bash
# macOS
brew install go@1.18

# Linux
wget https://go.dev/dl/go1.18.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.18.linux-amd64.tar.gz

# Add to PATH in ~/.bashrc or ~/.zshrc
export PATH=$PATH:/usr/local/go/bin

# Verify
go version
```

### Optional Tools

```bash
# VS Code (recommended IDE)
brew install --cask visual-studio-code

# Make (build automation)
brew install make

# jq (JSON processing)
brew install jq

# kubectl (Kubernetes CLI, if using GKE)
gcloud components install kubectl
```

## GCP Account Setup

### 1. Create GCP Project

```bash
# Set variables
export PROJECT_ID="nexusforge-prod"
export PROJECT_NAME="NexusForge Platform"
export BILLING_ACCOUNT_ID="YOUR_BILLING_ACCOUNT_ID"

# Create project
gcloud projects create $PROJECT_ID --name="$PROJECT_NAME"

# Set as active project
gcloud config set project $PROJECT_ID

# Link billing account
gcloud billing projects link $PROJECT_ID \
  --billing-account=$BILLING_ACCOUNT_ID
```

### 2. Enable Required APIs

```bash
# Run the API enablement script
./infrastructure/scripts/01-gcp-initial-setup.sh

# Or enable manually
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  vpcaccess.googleapis.com \
  compute.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  iap.googleapis.com \
  cloudarmor.googleapis.com
```

### 3. Set Up Workload Identity Federation

```bash
# Run the Workload Identity setup script
./infrastructure/scripts/02-workload-identity-setup.sh

# This creates:
# - Workload Identity Pool
# - Workload Identity Provider
# - Service Account with necessary permissions
# - GitHub Actions integration
```

## Local Development Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/nexusforge-platform.git
cd nexusforge-platform
```

### 2. Set Up Python Service

```bash
cd workspace/python

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Run database migrations
alembic upgrade head

# Run tests
pytest

# Start server
uvicorn app.main:app --reload
```

### 3. Set Up Node.js Service

```bash
cd workspace/nodejs

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Generate Prisma Client
npx prisma generate

# Run database migrations
npx prisma migrate dev

# Run tests
npm test

# Start server
npm run dev
```

### 4. Set Up Go Service

```bash
cd workspace/go

# Download dependencies
go mod download

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Run tests
go test ./...

# Build
go build -o bin/api cmd/api/main.go

# Run server
./bin/api
# Or: go run cmd/api/main.go
```

### 5. Set Up Local Infrastructure

```bash
# Start PostgreSQL and Redis with Docker Compose
docker-compose -f config/docker/docker-compose-all-in-one.yml up -d postgres redis

# Verify services are running
docker-compose ps

# Check PostgreSQL
psql -h localhost -U postgres -d nexusforge -c "SELECT version();"

# Check Redis
redis-cli ping
```

## GitHub Configuration

### 1. Create GitHub Repository

```bash
# Create new repository on GitHub
# Then push local repository

git remote add origin https://github.com/yourusername/nexusforge-platform.git
git branch -M main
git push -u origin main
```

### 2. Configure GitHub Secrets

Go to your repository → Settings → Secrets and variables → Actions

Add the following secrets:

#### Required Secrets

| Secret Name | Description | Example |
|------------|-------------|---------|
| `GCP_PROJECT_ID` | Your GCP project ID | `nexusforge-prod` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity Provider | `projects/123.../providers/github` |
| `GCP_SERVICE_ACCOUNT` | Service account email | `github-actions@project.iam.gserviceaccount.com` |
| `DATABASE_URL_PYTHON` | Python database URL | `postgresql://user:pass@host/db` |
| `DATABASE_URL_NODE` | Node.js database URL | `postgresql://user:pass@host/db` |
| `DB_PASSWORD_GO` | Go database password | `your-secure-password` |
| `REDIS_PASSWORD` | Redis password | `your-redis-password` |
| `JWT_SECRET` | JWT signing secret | `your-jwt-secret-key` |

#### Optional Secrets

| Secret Name | Description |
|------------|-------------|
| `SLACK_WEBHOOK_URL` | Slack notifications |
| `SNYK_TOKEN` | Snyk security scanning |
| `SENTRY_DSN` | Sentry error tracking |

### 3. Configure GitHub Environments

Create environments: `development`, `staging`, `production`

For each environment, add environment-specific secrets and protection rules.

## Infrastructure Deployment

### Method 1: Interactive Setup (Recommended)

```bash
# Run the setup manager
./infrastructure/scripts/00-setup-manager.sh

# Follow the interactive prompts:
# 1. GCP initial setup
# 2. Workload Identity Federation
# 3. Development VM setup (optional)
# 4. All-in-one VM setup (optional)
```

### Method 2: Manual Step-by-Step

```bash
# Step 1: Initial GCP setup
./infrastructure/scripts/01-gcp-initial-setup.sh

# Step 2: Workload Identity Federation
./infrastructure/scripts/02-workload-identity-setup.sh

# Step 3: Create Cloud SQL instance
gcloud sql instances create nexusforge-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1

# Step 4: Create databases
gcloud sql databases create nexusforge_python --instance=nexusforge-db
gcloud sql databases create nexusforge_node --instance=nexusforge-db
gcloud sql databases create nexusforge_go --instance=nexusforge-db

# Step 5: Create Redis instance
gcloud redis instances create nexusforge-cache \
  --size=1 \
  --region=us-central1 \
  --redis-version=redis_6_x

# Step 6: Create VPC Connector
gcloud compute networks vpc-access connectors create nexusforge-connector \
  --region=us-central1 \
  --subnet-project=$PROJECT_ID \
  --subnet=default
```

## Service Deployment

### Automatic Deployment (via GitHub Actions)

```bash
# Push to trigger deployment
git add .
git commit -m "feat: initial deployment"
git push origin main

# GitHub Actions will:
# 1. Run tests
# 2. Build Docker images
# 3. Push to Artifact Registry
# 4. Deploy to Cloud Run
# 5. Run smoke tests
```

### Manual Deployment

#### Python Service

```bash
# Build image
docker build -f config/docker/Dockerfile.python \
  -t gcr.io/$PROJECT_ID/nexusforge-python:latest .

# Push to registry
docker push gcr.io/$PROJECT_ID/nexusforge-python:latest

# Deploy to Cloud Run
gcloud run deploy nexusforge-python \
  --image gcr.io/$PROJECT_ID/nexusforge-python:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DATABASE_URL=$DATABASE_URL \
  --set-secrets JWT_SECRET=jwt-secret:latest
```

#### Node.js Service

```bash
# Build and deploy
docker build -f config/docker/Dockerfile.node \
  -t gcr.io/$PROJECT_ID/nexusforge-nodejs:latest .
  
docker push gcr.io/$PROJECT_ID/nexusforge-nodejs:latest

gcloud run deploy nexusforge-nodejs \
  --image gcr.io/$PROJECT_ID/nexusforge-nodejs:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

#### Go Service

```bash
# Build and deploy
docker build -f config/docker/Dockerfile.go \
  -t gcr.io/$PROJECT_ID/nexusforge-go:latest .
  
docker push gcr.io/$PROJECT_ID/nexusforge-go:latest

gcloud run deploy nexusforge-go \
  --image gcr.io/$PROJECT_ID/nexusforge-go:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## Verification

### 1. Check Service Health

```bash
# Get service URLs
PYTHON_URL=$(gcloud run services describe nexusforge-python --region=us-central1 --format='value(status.url)')
NODE_URL=$(gcloud run services describe nexusforge-nodejs --region=us-central1 --format='value(status.url)')
GO_URL=$(gcloud run services describe nexusforge-go --region=us-central1 --format='value(status.url)')

# Test health endpoints
curl $PYTHON_URL/health
curl $NODE_URL/health
curl $GO_URL/health
```

### 2. Test API Endpoints

```bash
# Create a user (Python)
curl -X POST $PYTHON_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "SecurePass123!"
  }'

# List users (requires auth token)
TOKEN="your-jwt-token"
curl $PYTHON_URL/api/users -H "Authorization: Bearer $TOKEN"
```

### 3. Check Monitoring

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# View metrics in Cloud Console
# https://console.cloud.google.com/monitoring
```

### 4. Verify Security

```bash
# Check IAP status
gcloud iap web get-iam-policy

# Check Cloud Armor policies
gcloud compute security-policies list

# Verify secrets
gcloud secrets list
```

## Troubleshooting

### Common Issues

#### 1. "Permission denied" errors

```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login

# Check permissions
gcloud projects get-iam-policy $PROJECT_ID
```

#### 2. Database connection issues

```bash
# Test Cloud SQL connection
gcloud sql connect nexusforge-db --user=postgres

# Check VPC connector
gcloud compute networks vpc-access connectors describe nexusforge-connector \
  --region=us-central1
```

#### 3. Docker build failures

```bash
# Clear Docker cache
docker system prune -a

# Rebuild with no cache
docker build --no-cache -f config/docker/Dockerfile.python .
```

#### 4. Service won't start

```bash
# Check logs
gcloud run services logs read nexusforge-python --region=us-central1

# Describe service for errors
gcloud run services describe nexusforge-python --region=us-central1
```

### Getting Help

- Check [Troubleshooting Guide](05-TROUBLESHOOTING.md)
- Review [GitHub Issues](https://github.com/yourusername/nexusforge-platform/issues)
- Consult [GCP Documentation](https://cloud.google.com/docs)

## Next Steps

- [Development Guide](02-DEVELOPMENT-GUIDE.md) - Start developing
- [Deployment Guide](03-DEPLOYMENT-GUIDE.md) - Advanced deployment
- [Security Guide](04-SECURITY.md) - Security best practices
- [Monitoring Guide](09-MONITORING.md) - Set up monitoring

---

[← Back to README](../README.md) | [Next: Development Guide →](02-DEVELOPMENT-GUIDE.md)
