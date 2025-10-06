# Deployment Guide

Complete guide for deploying services to Google Cloud Platform.

## Table of Contents

1. [Deployment Overview](#deployment-overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Environment Configuration](#environment-configuration)
4. [Automated Deployment (GitHub Actions)](#automated-deployment-github-actions)
5. [Manual Deployment](#manual-deployment)
6. [Canary Deployment](#canary-deployment)
7. [Rolling Back](#rolling-back)
8. [Multi-Region Deployment](#multi-region-deployment)
9. [Monitoring Deployment](#monitoring-deployment)
10. [Post-Deployment Tasks](#post-deployment-tasks)

## Deployment Overview

### Deployment Environments

| Environment | Purpose | Auto-Deploy | Approval |
|------------|---------|-------------|----------|
| **Development** | Testing features | ✅ On push to `develop` | No |
| **Staging** | Pre-production validation | ✅ On push to `staging` | No |
| **Production** | Live environment | ✅ On push to `main` | Yes (required) |

### Deployment Architecture

```
┌────────────────┐
│  Git Push      │
└───────┬────────┘
        │
┌───────▼─────────────────┐
│  GitHub Actions         │
│  ┌─────────────────┐   │
│  │ 1. Run Tests    │   │
│  │ 2. Build Image  │   │
│  │ 3. Scan Security│   │
│  │ 4. Push to GAR  │   │
│  │ 5. Deploy       │   │
│  └─────────────────┘   │
└───────┬─────────────────┘
        │
┌───────▼─────────────────┐
│  GCP Cloud Run          │
│  ┌──────────────────┐  │
│  │  Service A (10%) │  │  ← Canary
│  │  Service B (90%) │  │  ← Current
│  └──────────────────┘  │
└─────────────────────────┘
```

## Pre-Deployment Checklist

### Before Every Deployment

- [ ] All tests passing locally
- [ ] Code reviewed and approved
- [ ] Database migrations tested
- [ ] Environment variables configured
- [ ] Secrets stored in Secret Manager
- [ ] Rollback plan documented
- [ ] Monitoring alerts configured
- [ ] Stakeholders notified

### First-Time Deployment

- [ ] GCP project created and configured
- [ ] Workload Identity Federation set up
- [ ] GitHub secrets configured
- [ ] Cloud SQL instance created
- [ ] Redis instance created
- [ ] VPC connector created
- [ ] Domain/DNS configured (if needed)
- [ ] SSL certificates provisioned
- [ ] Cloud Armor policies created
- [ ] IAP configured

## Environment Configuration

### Development Environment

```yaml
# .github/config/environments.yml
development:
  region: us-central1
  min_instances: 0
  max_instances: 2
  cpu: 1
  memory: 512Mi
  timeout: 300
  concurrency: 80
  allow_unauthenticated: true
```

### Staging Environment

```yaml
staging:
  region: us-central1
  min_instances: 1
  max_instances: 5
  cpu: 2
  memory: 1Gi
  timeout: 300
  concurrency: 100
  allow_unauthenticated: false  # Requires IAP
```

### Production Environment

```yaml
production:
  region: us-central1
  min_instances: 2
  max_instances: 50
  cpu: 2
  memory: 2Gi
  timeout: 300
  concurrency: 100
  allow_unauthenticated: false  # Requires IAP
  traffic_split:
    - tag: canary
      percent: 10
    - tag: stable
      percent: 90
```

## Automated Deployment (GitHub Actions)

### Deploy to Development

Triggered automatically on push to `develop` branch:

```bash
git checkout develop
git add .
git commit -m "feat: add new feature"
git push origin develop

# GitHub Actions will:
# 1. Run unit tests
# 2. Run integration tests
# 3. Build Docker images
# 4. Scan for vulnerabilities
# 5. Push to Artifact Registry
# 6. Deploy to Cloud Run (dev)
# 7. Run smoke tests
```

### Deploy to Staging

Triggered automatically on push to `staging` branch:

```bash
# Merge develop to staging
git checkout staging
git merge develop
git push origin staging

# Or create release branch
git checkout -b release/v1.2.0 develop
git push origin release/v1.2.0
```

### Deploy to Production

Requires manual approval:

```bash
# Merge to main
git checkout main
git merge staging
git push origin main

# GitHub Actions workflow will pause for approval
# Navigate to: Actions → Deploy Production → Review Deployments
# Approve the deployment
```

### Workflow Files

#### Development Deployment

`.github/workflows/02-deploy-dev.yml`:

```yaml
name: Deploy to Development
on:
  push:
    branches: [develop]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: ./.github/actions/setup-gcp
      - uses: ./.github/actions/run-tests
      - uses: ./.github/actions/security-scan
      - uses: ./.github/actions/build-and-push-image
      - uses: ./.github/actions/deploy-cloud-run
        with:
          environment: development
```

#### Production Deployment

`.github/workflows/04-deploy-prod.yml`:

```yaml
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Requires approval
    steps:
      - uses: ./.github/actions/setup-gcp
      - name: Deploy Canary (10%)
        uses: ./.github/actions/deploy-cloud-run
        with:
          environment: production
          traffic_percent: 10
          tag: canary
      
      - name: Run Smoke Tests
        run: ./scripts/utilities/health-check.sh
      
      - name: Promote to 100%
        if: success()
        uses: ./.github/actions/deploy-cloud-run
        with:
          environment: production
          traffic_percent: 100
          tag: stable
```

## Manual Deployment

### Deploy Python Service

```bash
# Set variables
export PROJECT_ID="nexusforge-prod"
export SERVICE_NAME="nexusforge-python"
export REGION="us-central1"
export IMAGE_TAG="latest"

# Build image
docker build -f config/docker/Dockerfile.python \
  -t gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .

# Push to Artifact Registry
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG

# Deploy to Cloud Run
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --min-instances 1 \
  --max-instances 10 \
  --cpu 2 \
  --memory 1Gi \
  --timeout 300 \
  --concurrency 100 \
  --set-env-vars "ENV=production" \
  --set-secrets "DATABASE_URL=database-url:latest,JWT_SECRET=jwt-secret:latest" \
  --vpc-connector nexusforge-connector \
  --ingress internal-and-cloud-load-balancing

# Get service URL
gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(status.url)'
```

### Deploy Node.js Service

```bash
export SERVICE_NAME="nexusforge-nodejs"

# Build and push
docker build -f config/docker/Dockerfile.node \
  -t gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG .
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG

# Deploy
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --min-instances 1 \
  --max-instances 10 \
  --cpu 2 \
  --memory 1Gi \
  --set-secrets "DATABASE_URL=node-database-url:latest"
```

### Deploy Go Service

```bash
export SERVICE_NAME="nexusforge-go"

# Build and push
docker build -f config/docker/Dockerfile.go \
  -t gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG .
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG

# Deploy
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --min-instances 1 \
  --max-instances 10 \
  --cpu 1 \
  --memory 512Mi
```

## Canary Deployment

### What is Canary Deployment?

Canary deployment gradually rolls out changes to a small subset of users before full deployment.

### Step-by-Step Canary Deployment

#### 1. Deploy Canary Version (10% traffic)

```bash
# Deploy new version with canary tag
gcloud run deploy nexusforge-python \
  --image gcr.io/$PROJECT_ID/nexusforge-python:v2.0.0 \
  --platform managed \
  --region $REGION \
  --tag canary \
  --no-traffic

# Route 10% traffic to canary
gcloud run services update-traffic nexusforge-python \
  --region $REGION \
  --to-revisions canary=10,stable=90
```

#### 2. Monitor Canary Metrics

```bash
# Watch error rates
gcloud monitoring time-series list \
  --filter 'metric.type="run.googleapis.com/request_count"' \
  --interval-start-time "$(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')" \
  --interval-end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Check logs for errors
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 50 \
  --format json
```

#### 3. Promote Canary to Production

```bash
# If canary is healthy, promote to 100%
gcloud run services update-traffic nexusforge-python \
  --region $REGION \
  --to-latest

# Or gradually increase traffic
gcloud run services update-traffic nexusforge-python \
  --region $REGION \
  --to-revisions canary=50,stable=50

# Eventually
gcloud run services update-traffic nexusforge-python \
  --region $REGION \
  --to-revisions canary=100
```

#### 4. Rollback if Issues Detected

```bash
# Revert all traffic to stable version
gcloud run services update-traffic nexusforge-python \
  --region $REGION \
  --to-revisions stable=100
```

### Automated Canary with GitHub Actions

The production workflow includes automated canary:

```yaml
# In .github/workflows/04-deploy-prod.yml
- name: Deploy Canary
  run: |
    gcloud run deploy $SERVICE_NAME \
      --image $IMAGE \
      --tag canary \
      --no-traffic
    
    gcloud run services update-traffic $SERVICE_NAME \
      --to-revisions canary=10,stable=90

- name: Monitor Canary (10 minutes)
  run: |
    sleep 600
    ./scripts/utilities/health-check.sh canary

- name: Promote Canary
  if: success()
  run: |
    gcloud run services update-traffic $SERVICE_NAME \
      --to-latest
```

## Rolling Back

### Quick Rollback to Previous Revision

```bash
# List revisions
gcloud run revisions list \
  --service nexusforge-python \
  --region $REGION

# Rollback to specific revision
gcloud run services update-traffic nexusforge-python \
  --region $REGION \
  --to-revisions nexusforge-python-v123=100

# Or rollback to previous revision
PREVIOUS_REVISION=$(gcloud run revisions list \
  --service nexusforge-python \
  --region $REGION \
  --format 'value(name)' \
  --limit 2 | tail -n 1)

gcloud run services update-traffic nexusforge-python \
  --region $REGION \
  --to-revisions $PREVIOUS_REVISION=100
```

### Rollback Script

```bash
#!/bin/bash
# scripts/deployment/rollback-service.sh

set -euo pipefail

SERVICE_NAME=${1:-nexusforge-python}
REGION=${2:-us-central1}

echo "Rolling back $SERVICE_NAME..."

# Get previous revision
PREVIOUS=$(gcloud run revisions list \
  --service $SERVICE_NAME \
  --region $REGION \
  --format 'value(name)' \
  --limit 2 | tail -n 1)

# Rollback
gcloud run services update-traffic $SERVICE_NAME \
  --region $REGION \
  --to-revisions $PREVIOUS=100

echo "Rolled back to: $PREVIOUS"

# Verify
gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(status.url)'
```

### Database Rollback

If deployment includes database migrations:

```bash
# Python (Alembic)
cd workspace/python
alembic downgrade -1

# Node.js (Prisma)
cd workspace/nodejs
npx prisma migrate resolve --rolled-back 20231006_migration

# Go (golang-migrate)
cd workspace/go
migrate -path migrations -database "$DATABASE_URL" down 1
```

## Multi-Region Deployment

### Deploy to Multiple Regions

```bash
# Define regions
REGIONS=("us-central1" "europe-west1" "asia-east1")

# Deploy to each region
for REGION in "${REGIONS[@]}"; do
  echo "Deploying to $REGION..."
  
  gcloud run deploy nexusforge-python \
    --image gcr.io/$PROJECT_ID/nexusforge-python:latest \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated
done
```

### Global Load Balancer

```bash
# Create backend service
gcloud compute backend-services create nexusforge-backend \
  --global \
  --load-balancing-scheme=EXTERNAL

# Add backends for each region
for REGION in "${REGIONS[@]}"; do
  NEG_NAME="nexusforge-neg-$REGION"
  
  gcloud compute network-endpoint-groups create $NEG_NAME \
    --region $REGION \
    --network-endpoint-type=SERVERLESS \
    --cloud-run-service=nexusforge-python
  
  gcloud compute backend-services add-backend nexusforge-backend \
    --global \
    --network-endpoint-group=$NEG_NAME \
    --network-endpoint-group-region=$REGION
done

# Create URL map
gcloud compute url-maps create nexusforge-urlmap \
  --default-service nexusforge-backend

# Create SSL certificate
gcloud compute ssl-certificates create nexusforge-cert \
  --domains nexusforge.example.com

# Create HTTPS proxy
gcloud compute target-https-proxies create nexusforge-proxy \
  --url-map nexusforge-urlmap \
  --ssl-certificates nexusforge-cert

# Create forwarding rule
gcloud compute forwarding-rules create nexusforge-forwarding-rule \
  --global \
  --target-https-proxy nexusforge-proxy \
  --ports 443
```

## Monitoring Deployment

### Real-time Deployment Monitoring

```bash
# Watch deployment progress
gcloud run services describe nexusforge-python \
  --region $REGION \
  --format yaml

# Stream logs
gcloud logging tail \
  "resource.type=cloud_run_revision AND resource.labels.service_name=nexusforge-python" \
  --format=json

# Monitor metrics
gcloud monitoring metrics-descriptors list \
  --filter="metric.type:run.googleapis.com"
```

### Health Check After Deployment

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe nexusforge-python \
  --region $REGION \
  --format 'value(status.url)')

# Check health endpoint
curl -f $SERVICE_URL/health || echo "Health check failed"

# Check readiness
curl -f $SERVICE_URL/ready || echo "Readiness check failed"

# Test API endpoint
curl -f $SERVICE_URL/api/users \
  -H "Authorization: Bearer $TOKEN" || echo "API test failed"
```

### Deployment Validation Script

```bash
#!/bin/bash
# scripts/utilities/health-check.sh

SERVICE_URL=$1
MAX_RETRIES=30
RETRY_DELAY=10

echo "Validating deployment: $SERVICE_URL"

for i in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $i/$MAX_RETRIES..."
  
  # Check health
  if curl -sf "$SERVICE_URL/health" > /dev/null; then
    echo "✓ Health check passed"
    
    # Check readiness
    if curl -sf "$SERVICE_URL/ready" > /dev/null; then
      echo "✓ Readiness check passed"
      echo "✓ Deployment successful!"
      exit 0
    fi
  fi
  
  echo "Waiting ${RETRY_DELAY}s..."
  sleep $RETRY_DELAY
done

echo "✗ Deployment validation failed after $MAX_RETRIES attempts"
exit 1
```

## Post-Deployment Tasks

### 1. Update Documentation

```bash
# Update CHANGELOG.md
echo "## [1.2.0] - $(date +%Y-%m-%d)" >> CHANGELOG.md
echo "### Added" >> CHANGELOG.md
echo "- New feature X" >> CHANGELOG.md

# Tag release
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

### 2. Notify Stakeholders

```bash
# Send Slack notification
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "🚀 Deployed nexusforge-python v1.2.0 to production",
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*Deployment Successful*\n\nService: nexusforge-python\nVersion: v1.2.0\nEnvironment: Production"
        }
      }
    ]
  }'
```

### 3. Monitor for Issues

```bash
# Set up alert for increased error rates
gcloud alpha monitoring policies create \
  --notification-channels=$CHANNEL_ID \
  --display-name="High Error Rate - nexusforge-python" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=300s
```

### 4. Clean Up Old Revisions

```bash
# Keep only last 5 revisions
gcloud run revisions list \
  --service nexusforge-python \
  --region $REGION \
  --format 'value(name)' \
  --sort-by ~metadata.creationTimestamp \
  | tail -n +6 \
  | xargs -I {} gcloud run revisions delete {} \
    --region $REGION \
    --quiet
```

### 5. Update Load Tests

```bash
# Run load test to verify performance
cd tests/load
locust -f locustfile.py \
  --host $SERVICE_URL \
  --users 100 \
  --spawn-rate 10 \
  --run-time 5m \
  --headless
```

## Best Practices

### 1. Blue-Green Deployment

Maintain two identical environments:

```bash
# Deploy to green environment
gcloud run deploy nexusforge-python-green \
  --image gcr.io/$PROJECT_ID/nexusforge-python:v2.0.0

# Test green environment
curl https://green.nexusforge.example.com/health

# Switch traffic to green
gcloud compute url-maps set-default-service nexusforge-urlmap \
  --default-service=nexusforge-backend-green
```

### 2. Database Migrations

Always use backward-compatible migrations:

```bash
# Good: Add nullable column
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

# Bad: Drop column immediately
# ALTER TABLE users DROP COLUMN email;

# Better: Multi-step migration
# Step 1: Add new column
# Step 2: Backfill data
# Step 3: Drop old column after all services updated
```

### 3. Feature Flags

Use feature flags for gradual rollouts:

```python
# Python
from app.config import feature_flags

if feature_flags.is_enabled("new_feature"):
    # New code
else:
    # Old code
```

### 4. Deployment Schedule

- **Avoid Friday deployments** (limited support over weekend)
- **Deploy during low-traffic periods**
- **Have rollback plan ready**
- **Monitor for at least 30 minutes post-deployment**

### 5. Zero-Downtime Deployments

```yaml
# Cloud Run automatically does zero-downtime deployments
# Ensure health checks are properly configured:
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
```

## Troubleshooting Deployments

See [Troubleshooting Guide](05-TROUBLESHOOTING.md) for common deployment issues.

---

[← Back to Development Guide](02-DEVELOPMENT-GUIDE.md) | [Next: Security Guide →](04-SECURITY.md)
