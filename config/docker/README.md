# Docker Build and Deployment Guide

This directory contains Docker configurations for all NexusForge Platform services.

## 📦 Available Dockerfiles

### 1. Dockerfile.python
- **Base Image**: python:3.9-slim
- **Framework**: FastAPI
- **Final Size**: ~150MB
- **Features**:
  - Multi-stage build
  - Virtual environment
  - Non-root user
  - Health checks
  - Minimal dependencies

### 2. Dockerfile.node
- **Base Image**: node:16-alpine
- **Framework**: Express + TypeScript
- **Final Size**: ~120MB
- **Features**:
  - Multi-stage build
  - Production dependencies only
  - Prisma Client included
  - dumb-init for signal handling
  - Non-root user

### 3. Dockerfile.go
- **Base Image**: alpine:3.18
- **Framework**: Gin
- **Final Size**: ~15MB
- **Features**:
  - Multi-stage build
  - Static binary (no dependencies)
  - Minimal attack surface
  - Non-root user
  - Ultra-lightweight

## 🚀 Quick Start

### Build Individual Services

```bash
# Python service
docker build -f Dockerfile.python -t nexusforge-python:latest ../..

# Node.js service
docker build -f Dockerfile.node -t nexusforge-nodejs:latest ../..

# Go service
docker build -f Dockerfile.go -t nexusforge-go:latest ../..
```

### Run Individual Services

```bash
# Python
docker run -p 8000:8000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/db \
  -e REDIS_HOST=redis \
  -e JWT_SECRET=secret \
  nexusforge-python:latest

# Node.js
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/db \
  -e REDIS_HOST=redis \
  -e JWT_SECRET=secret \
  nexusforge-nodejs:latest

# Go
docker run -p 8080:8080 \
  -e DB_HOST=host \
  -e DB_PASSWORD=pass \
  -e REDIS_HOST=redis \
  -e JWT_SECRET=secret \
  nexusforge-go:latest
```

## 🐳 Docker Compose

### Development Environment

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### All-in-One Production Environment

```bash
# Start with all monitoring tools
docker-compose -f docker-compose-all-in-one.yml up -d

# View specific service logs
docker-compose -f docker-compose-all-in-one.yml logs -f python-api

# Scale specific service
docker-compose -f docker-compose-all-in-one.yml up -d --scale python-api=3

# Stop all services
docker-compose -f docker-compose-all-in-one.yml down
```

## 📊 Service Ports

| Service | Port | URL |
|---------|------|-----|
| Python API | 8000 | http://localhost:8000 |
| Node.js API | 3000 | http://localhost:3000 |
| Go API | 8080 | http://localhost:8080 |
| Nginx | 80/443 | http://localhost |
| PostgreSQL | 5432 | localhost:5432 |
| Redis | 6379 | localhost:6379 |
| Prometheus | 9090 | http://localhost:9090 |
| Grafana | 3001 | http://localhost:3001 |
| Adminer | 8081 | http://localhost:8081 |
| Redis Commander | 8082 | http://localhost:8082 |

## 🔧 Environment Variables

Create a `.env` file in the project root:

```env
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-secure-password
POSTGRES_DB=nexusforge

# Redis
REDIS_PASSWORD=your-redis-password

# Application
ENV=production
JWT_SECRET=your-jwt-secret-key-change-this
JWT_EXPIRES_IN=24h

# Ports (optional overrides)
HTTP_PORT=80
HTTPS_PORT=443
POSTGRES_PORT=5432
REDIS_PORT=6379
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001

# Monitoring
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin-password
LOG_LEVEL=info
ENABLE_CACHE=true
ENABLE_METRICS=true
```

## 🏗️ Build Optimization

### BuildKit Cache

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build with cache
docker build --build-arg BUILDKIT_INLINE_CACHE=1 \
  -f Dockerfile.python -t nexusforge-python:latest ../..
```

### Multi-platform Builds

```bash
# Create builder
docker buildx create --name multiplatform --use

# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.go -t nexusforge-go:latest ../.. --push
```

## 📈 Image Size Comparison

| Service | Image Size | Notes |
|---------|-----------|-------|
| Go | ~15MB | Static binary, smallest |
| Node.js | ~120MB | Alpine-based, optimized |
| Python | ~150MB | Slim base, virtual env |

## 🔐 Security Best Practices

### Applied in Dockerfiles

✅ Multi-stage builds to reduce attack surface
✅ Non-root user (appuser with UID 1001)
✅ Minimal base images (alpine/slim)
✅ No unnecessary packages
✅ Health checks for monitoring
✅ Proper signal handling (dumb-init for Node.js)
✅ Static binary compilation (Go)

### Additional Recommendations

```bash
# Scan for vulnerabilities
docker scan nexusforge-python:latest
docker scan nexusforge-nodejs:latest
docker scan nexusforge-go:latest

# Use Docker secrets for sensitive data
docker secret create jwt_secret jwt_secret.txt
docker service create --secret jwt_secret nexusforge-python:latest
```

## 🚢 Production Deployment

### Push to Registry

```bash
# Tag images
docker tag nexusforge-python:latest gcr.io/PROJECT_ID/nexusforge-python:latest
docker tag nexusforge-nodejs:latest gcr.io/PROJECT_ID/nexusforge-nodejs:latest
docker tag nexusforge-go:latest gcr.io/PROJECT_ID/nexusforge-go:latest

# Push to GCP Artifact Registry
docker push gcr.io/PROJECT_ID/nexusforge-python:latest
docker push gcr.io/PROJECT_ID/nexusforge-nodejs:latest
docker push gcr.io/PROJECT_ID/nexusforge-go:latest
```

### Cloud Run Deployment

```bash
# Deploy Python service
gcloud run deploy nexusforge-python \
  --image gcr.io/PROJECT_ID/nexusforge-python:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated

# Deploy Node.js service
gcloud run deploy nexusforge-nodejs \
  --image gcr.io/PROJECT_ID/nexusforge-nodejs:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated

# Deploy Go service
gcloud run deploy nexusforge-go \
  --image gcr.io/PROJECT_ID/nexusforge-go:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## 🔍 Troubleshooting

### Check Container Health

```bash
# View health status
docker inspect nexusforge-python-api | jq '.[0].State.Health'

# Check logs
docker logs nexusforge-python-api

# Execute commands inside container
docker exec -it nexusforge-python-api /bin/sh
```

### Debug Build Issues

```bash
# Build with verbose output
docker build --progress=plain -f Dockerfile.python ../..

# Check image layers
docker history nexusforge-python:latest
```

### Database Connection Issues

```bash
# Test database connection from container
docker exec -it nexusforge-python-api \
  python -c "import psycopg2; psycopg2.connect('postgresql://postgres:postgres@postgres:5432/nexusforge_python')"

# Check network connectivity
docker exec -it nexusforge-python-api ping postgres
```

## 📝 Maintenance

### Cleanup

```bash
# Remove stopped containers
docker-compose down

# Remove volumes (WARNING: deletes data)
docker-compose down -v

# Remove unused images
docker image prune -a

# Complete cleanup
docker system prune -a --volumes
```

### Update Images

```bash
# Pull latest base images
docker pull python:3.9-slim
docker pull node:16-alpine
docker pull golang:1.18-alpine

# Rebuild services
docker-compose build --no-cache
```

## 📚 Additional Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Security Scanning](https://docs.docker.com/engine/scan/)
- [BuildKit](https://docs.docker.com/build/buildkit/)
