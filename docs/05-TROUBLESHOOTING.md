# Troubleshooting Guide

Common issues and solutions for the NexusForge Platform.

## Table of Contents

1. [General Troubleshooting](#general-troubleshooting)
2. [Deployment Issues](#deployment-issues)
3. [Service Issues](#service-issues)
4. [Database Issues](#database-issues)
5. [Network Issues](#network-issues)
6. [Authentication Issues](#authentication-issues)
7. [Performance Issues](#performance-issues)
8. [Docker Issues](#docker-issues)
9. [CI/CD Issues](#ci-cd-issues)
10. [Monitoring & Logging](#monitoring--logging)

## General Troubleshooting

### Troubleshooting Methodology

1. **Identify the problem** - What exactly is failing?
2. **Gather information** - Check logs, metrics, and status
3. **Form hypothesis** - What could be causing this?
4. **Test hypothesis** - Try solutions systematically
5. **Document solution** - Update documentation

### Essential Commands

```bash
# Check Cloud Run service status
gcloud run services describe nexusforge-python \
  --region us-central1 \
  --format yaml

# View recent logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=nexusforge-python" \
  --limit 50 \
  --format json

# Check service health
curl -f https://your-service-url/health || echo "Health check failed"

# View metrics
gcloud monitoring time-series list \
  --filter 'metric.type="run.googleapis.com/request_count"'

# List recent deployments
gcloud run revisions list \
  --service nexusforge-python \
  --region us-central1
```

## Deployment Issues

### Issue: Deployment Fails with "Permission Denied"

**Symptoms:**
```
ERROR: (gcloud.run.deploy) PERMISSION_DENIED: Permission denied on resource
```

**Solutions:**

1. **Check IAM permissions:**
```bash
# Verify service account has necessary roles
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:YOUR_SA@$PROJECT_ID.iam.gserviceaccount.com"

# Add missing roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:YOUR_SA@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/run.admin
```

2. **Check Workload Identity:**
```bash
# Verify workload identity binding
gcloud iam service-accounts get-iam-policy \
  YOUR_SA@$PROJECT_ID.iam.gserviceaccount.com
```

3. **Re-authenticate:**
```bash
gcloud auth login
gcloud auth application-default login
```

### Issue: Container Fails to Start

**Symptoms:**
```
Cloud Run error: Container failed to start. Failed to start and then listen on the port defined by the PORT environment variable.
```

**Solutions:**

1. **Check if service binds to correct port:**
```python
# Python - Must use PORT environment variable
import os
port = int(os.environ.get("PORT", 8080))
uvicorn.run(app, host="0.0.0.0", port=port)
```

2. **Check startup time:**
```bash
# Increase timeout if service needs longer to start
gcloud run services update nexusforge-python \
  --timeout=300
```

3. **Test container locally:**
```bash
# Run container with same PORT environment variable
docker run -p 8080:8080 -e PORT=8080 \
  gcr.io/$PROJECT_ID/nexusforge-python:latest

# Check if responds
curl http://localhost:8080/health
```

4. **Check logs for startup errors:**
```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND textPayload=~'error|Error|ERROR'" \
  --limit 50
```

### Issue: Deployment Succeeds but Returns 500 Errors

**Symptoms:**
- Deployment completes successfully
- Service returns HTTP 500 errors
- Health checks may pass but API calls fail

**Solutions:**

1. **Check application logs:**
```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 50 \
  --format json | jq '.[] | {timestamp, message: .textPayload}'
```

2. **Check environment variables:**
```bash
# List current environment variables
gcloud run services describe nexusforge-python \
  --region us-central1 \
  --format='value(spec.template.spec.containers[0].env)'

# Update missing variables
gcloud run services update nexusforge-python \
  --set-env-vars DATABASE_URL=$DATABASE_URL
```

3. **Check secrets access:**
```bash
# Verify service account can access secrets
gcloud secrets get-iam-policy jwt-secret

# Grant access if needed
gcloud secrets add-iam-policy-binding jwt-secret \
  --member=serviceAccount:YOUR_SA@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
```

4. **Test with debug logging:**
```bash
gcloud run services update nexusforge-python \
  --set-env-vars LOG_LEVEL=DEBUG
```

### Issue: Deployment Timeout

**Symptoms:**
```
ERROR: Operation timed out
```

**Solutions:**

1. **Check Cloud Build logs:**
```bash
gcloud builds list --limit 5

# Get specific build logs
gcloud builds log BUILD_ID
```

2. **Optimize Docker build:**
```dockerfile
# Use multi-stage builds
# Enable BuildKit
# Use .dockerignore
# Leverage layer caching
```

3. **Increase timeout:**
```bash
# In cloudbuild.yaml
timeout: 1800s  # 30 minutes
```

## Service Issues

### Issue: Service Crashes or Restarts Frequently

**Symptoms:**
- Service unavailable intermittently
- Error logs show container exits
- High restart count in metrics

**Solutions:**

1. **Check memory usage:**
```bash
# View memory metrics
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/memory/utilizations"' \
  --interval-start-time=$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --interval-end-time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Increase memory allocation
gcloud run services update nexusforge-python \
  --memory 2Gi
```

2. **Check for memory leaks:**
```python
# Python - Monitor memory usage
import tracemalloc
tracemalloc.start()

# ... your code ...

current, peak = tracemalloc.get_traced_memory()
logger.info(f"Memory usage: {current / 10**6}MB, Peak: {peak / 10**6}MB")
```

3. **Check for unhandled exceptions:**
```python
# Add global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error"}
    )
```

4. **Review resource limits:**
```bash
# Increase CPU and concurrency
gcloud run services update nexusforge-python \
  --cpu 2 \
  --concurrency 80
```

### Issue: Slow Response Times

**Symptoms:**
- API requests taking > 1 second
- Timeout errors
- High latency in metrics

**Solutions:**

1. **Add database connection pooling:**
```python
# Python (SQLAlchemy)
from sqlalchemy.ext.asyncio import create_async_engine

engine = create_async_engine(
    DATABASE_URL,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=3600
)
```

2. **Implement caching:**
```python
# Python with Redis
from redis import asyncio as aioredis
import json

class Cache:
    def __init__(self):
        self.redis = aioredis.from_url(REDIS_URL)
    
    async def get(self, key: str):
        value = await self.redis.get(key)
        return json.loads(value) if value else None
    
    async def set(self, key: str, value, expire: int = 300):
        await self.redis.setex(key, expire, json.dumps(value))

# Usage
@router.get("/api/users")
async def get_users(cache: Cache = Depends()):
    cached = await cache.get("users:all")
    if cached:
        return cached
    
    users = await db.execute(select(User).limit(100))
    result = users.scalars().all()
    await cache.set("users:all", result, expire=60)
    return result
```

3. **Add database indexes:**
```sql
-- Identify slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Add indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at DESC);
```

4. **Optimize queries:**
```python
# Bad: N+1 queries
users = await db.execute(select(User))
for user in users.scalars():
    posts = await db.execute(select(Post).where(Post.user_id == user.id))

# Good: Join or eager loading
from sqlalchemy.orm import selectinload

users = await db.execute(
    select(User).options(selectinload(User.posts))
)
```

5. **Increase Cloud Run instances:**
```bash
gcloud run services update nexusforge-python \
  --min-instances 2 \
  --max-instances 50
```

## Database Issues

### Issue: "Too Many Connections"

**Symptoms:**
```
FATAL: sorry, too many clients already
remaining connection slots are reserved for non-replication superuser connections
```

**Solutions:**

1. **Check current connections:**
```sql
-- Connect to database
psql $DATABASE_URL

-- View active connections
SELECT count(*) FROM pg_stat_activity;

-- View connections by application
SELECT application_name, count(*)
FROM pg_stat_activity
GROUP BY application_name;

-- View connection limits
SHOW max_connections;
```

2. **Reduce connection pool size:**
```python
# Python
engine = create_async_engine(
    DATABASE_URL,
    pool_size=5,  # Reduce from 20
    max_overflow=0
)
```

3. **Use PgBouncer:**
```bash
# Install PgBouncer
docker run -d \
  --name pgbouncer \
  -p 6432:6432 \
  -e DATABASE_URL=$DATABASE_URL \
  edoburu/pgbouncer

# Update application to use PgBouncer
DATABASE_URL=postgresql://user:pass@pgbouncer:6432/db
```

4. **Increase Cloud SQL connections:**
```bash
# Upgrade to larger instance
gcloud sql instances patch nexusforge-db \
  --tier=db-custom-4-15360
```

### Issue: Slow Database Queries

**Symptoms:**
- Queries taking > 1 second
- Database CPU at 100%
- Application timeouts

**Solutions:**

1. **Enable slow query logging:**
```sql
-- Set slow query threshold
ALTER DATABASE nexusforge SET log_min_duration_statement = 1000;

-- View slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

2. **Analyze query execution:**
```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'test@example.com';
```

3. **Add indexes:**
```sql
-- Create index
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- Verify index usage
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';
-- Should show "Index Scan using idx_users_email"
```

4. **Update statistics:**
```sql
ANALYZE users;
VACUUM ANALYZE;
```

### Issue: Database Connection Failures

**Symptoms:**
```
could not connect to server: Connection refused
Is the server running on host "..." and accepting TCP/IP connections?
```

**Solutions:**

1. **Check Cloud SQL instance status:**
```bash
gcloud sql instances describe nexusforge-db
```

2. **Verify VPC connector:**
```bash
gcloud compute networks vpc-access connectors describe nexusforge-connector \
  --region us-central1
```

3. **Check firewall rules:**
```bash
gcloud compute firewall-rules list \
  --filter="name~nexusforge"
```

4. **Test connection from Cloud Shell:**
```bash
gcloud sql connect nexusforge-db --user=postgres
```

5. **Check authorized networks (if using public IP):**
```bash
gcloud sql instances patch nexusforge-db \
  --authorized-networks=YOUR_IP/32
```

## Network Issues

### Issue: Service Unreachable

**Symptoms:**
- Cannot access service URL
- Connection timeout
- DNS resolution fails

**Solutions:**

1. **Check service URL:**
```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe nexusforge-python \
  --region us-central1 \
  --format 'value(status.url)')

echo $SERVICE_URL

# Test connectivity
curl -I $SERVICE_URL
```

2. **Check IAP configuration:**
```bash
# If using IAP, ensure you're authenticated
gcloud auth print-identity-token

# Test with token
TOKEN=$(gcloud auth print-identity-token)
curl -H "Authorization: Bearer $TOKEN" $SERVICE_URL
```

3. **Check ingress settings:**
```bash
# Allow all traffic
gcloud run services update nexusforge-python \
  --ingress all

# Or internal only
gcloud run services update nexusforge-python \
  --ingress internal-and-cloud-load-balancing
```

4. **Verify DNS:**
```bash
nslookup nexusforge.example.com
dig nexusforge.example.com
```

### Issue: High Latency Between Services

**Symptoms:**
- Service-to-service calls slow
- Timeout errors in logs
- High network latency

**Solutions:**

1. **Use VPC for internal communication:**
```bash
# Deploy services in same VPC
gcloud run services update nexusforge-python \
  --vpc-connector nexusforge-connector

gcloud run services update nexusforge-nodejs \
  --vpc-connector nexusforge-connector
```

2. **Use internal URLs:**
```python
# Instead of public URLs
# NODEJS_URL = "https://nexusforge-nodejs-abc123.run.app"

# Use internal URL
NODEJS_URL = "http://nexusforge-nodejs"
```

3. **Check region locality:**
```bash
# Deploy services in same region
gcloud run services list --format='table(name,region)'
```

## Authentication Issues

### Issue: JWT Token Invalid

**Symptoms:**
```
401 Unauthorized
Invalid authentication credentials
Token expired
```

**Solutions:**

1. **Check token expiration:**
```python
# Decode JWT to inspect
import jwt
token = "your-jwt-token"
decoded = jwt.decode(token, options={"verify_signature": False})
print(decoded)  # Check 'exp' field
```

2. **Verify JWT secret:**
```bash
# Check secret in Secret Manager
gcloud secrets versions access latest --secret=jwt-secret

# Verify service is using correct secret
gcloud run services describe nexusforge-python \
  --format='value(spec.template.spec.containers[0].env)'
```

3. **Check token format:**
```bash
# Token should be: Bearer <token>
curl -H "Authorization: Bearer $TOKEN" $SERVICE_URL
```

4. **Generate new token:**
```bash
# Login to get new token
curl -X POST $SERVICE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password"
  }'
```

### Issue: "Forbidden" Error Despite Valid Token

**Symptoms:**
```
403 Forbidden
Insufficient permissions
```

**Solutions:**

1. **Check user roles:**
```python
# Decode token and inspect roles
decoded = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
print(decoded.get("roles", []))
```

2. **Verify RBAC configuration:**
```yaml
# Check config/security/rbac-policies.yaml
roles:
  - name: user
    permissions:
      - users:read_own
```

3. **Check endpoint permissions:**
```python
@router.delete("/api/users/{user_id}")
@require_permission("users:delete")  # Check this matches user's roles
async def delete_user(user_id: int):
    pass
```

## Performance Issues

### Issue: Cold Start Latency

**Symptoms:**
- First request after idle period is slow (> 2 seconds)
- Subsequent requests are fast

**Solutions:**

1. **Set minimum instances:**
```bash
gcloud run services update nexusforge-python \
  --min-instances 1
```

2. **Optimize container size:**
```dockerfile
# Use slim images
FROM python:3.9-slim  # Instead of python:3.9

# Minimize layers
RUN apt-get update && apt-get install -y \
    pkg1 pkg2 pkg3 \
 && rm -rf /var/lib/apt/lists/*
```

3. **Reduce dependencies:**
```bash
# Python - Only install needed packages
pip install fastapi uvicorn sqlalchemy
# Not: pip install "fastapi[all]"
```

4. **Enable HTTP/2:**
```bash
# HTTP/2 enabled by default on Cloud Run
# Ensure clients use HTTP/2
curl --http2 $SERVICE_URL
```

## Docker Issues

### Issue: Docker Build Fails

**Symptoms:**
```
ERROR: failed to solve: failed to read dockerfile
```

**Solutions:**

1. **Check Dockerfile syntax:**
```bash
# Validate Dockerfile
docker build --check -f config/docker/Dockerfile.python .
```

2. **Check build context:**
```bash
# Ensure you're in project root
pwd
ls -la

# Build with explicit context
docker build -f config/docker/Dockerfile.python \
  -t nexusforge-python:latest \
  .
```

3. **Check .dockerignore:**
```bash
# Ensure necessary files aren't ignored
cat .dockerignore
```

### Issue: Image Too Large

**Symptoms:**
- Image > 500MB
- Slow push/pull times
- High storage costs

**Solutions:**

1. **Use multi-stage builds:**
```dockerfile
# Build stage
FROM python:3.9 AS builder
# ... build steps ...

# Runtime stage
FROM python:3.9-slim
COPY --from=builder /app /app
```

2. **Use slim/alpine images:**
```dockerfile
FROM python:3.9-slim  # 150MB
# Instead of
# FROM python:3.9  # 900MB
```

3. **Clean up in same layer:**
```dockerfile
RUN apt-get update && \
    apt-get install -y pkg && \
    rm -rf /var/lib/apt/lists/*  # Clean in same RUN
```

## CI/CD Issues

### Issue: GitHub Actions Workflow Fails

**Symptoms:**
- Workflow runs but fails at specific step
- Error in Actions logs

**Solutions:**

1. **Check workflow logs:**
```bash
# View in GitHub UI: Actions → Select workflow → View logs

# Or use GitHub CLI
gh run list
gh run view RUN_ID --log
```

2. **Verify secrets:**
```bash
# Check if secrets are set
# Settings → Secrets and variables → Actions
```

3. **Test locally:**
```bash
# Use act to test GitHub Actions locally
brew install act
act -l  # List jobs
act -j deploy  # Run specific job
```

4. **Check Workload Identity:**
```bash
# Verify configuration
gcloud iam workload-identity-pools describe github-pool \
  --location=global
```

### Issue: Tests Pass Locally But Fail in CI

**Symptoms:**
- All tests pass on local machine
- Same tests fail in GitHub Actions

**Solutions:**

1. **Check environment differences:**
```yaml
# In workflow file
env:
  ENV: test
  DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
```

2. **Use same Python/Node/Go version:**
```yaml
- uses: actions/setup-python@v4
  with:
    python-version: '3.9'  # Match local version
```

3. **Check test dependencies:**
```bash
# Ensure test dependencies installed
pip install -r requirements-dev.txt
npm install --include=dev
```

## Monitoring & Logging

### Viewing Logs

```bash
# Real-time logs
gcloud logging tail \
  "resource.type=cloud_run_revision" \
  --format=json

# Filtered logs
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 100

# Logs for specific service
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=nexusforge-python" \
  --limit 50

# JSON parsing with jq
gcloud logging read \
  "resource.type=cloud_run_revision" \
  --format json \
  --limit 10 | jq '.[] | {time: .timestamp, message: .textPayload}'
```

### Setting Up Alerts

```bash
# Create alert for error rate
gcloud alpha monitoring policies create \
  --notification-channels=$CHANNEL_ID \
  --display-name="High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=300s
```

## Getting Help

If issues persist:

1. **Check official docs:**
   - [Cloud Run Documentation](https://cloud.google.com/run/docs)
   - [FastAPI Documentation](https://fastapi.tiangolo.com/)
   - [Express Documentation](https://expressjs.com/)
   - [Gin Documentation](https://gin-gonic.com/)

2. **Community support:**
   - [Stack Overflow](https://stackoverflow.com/questions/tagged/google-cloud-run)
   - [GitHub Discussions](https://github.com/yourusername/nexusforge-platform/discussions)
   - [GCP Community](https://www.googlecloudcommunity.com/)

3. **Open an issue:**
   - [GitHub Issues](https://github.com/yourusername/nexusforge-platform/issues)

---

[← Back to Security Guide](04-SECURITY.md) | [Next: API Documentation →](07-API-DOCUMENTATION.md)
