# NexusForge Platform

<div align="center">

![NexusForge](https://img.shields.io/badge/NexusForge-Platform-blue?style=for-the-badge)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![GCP](https://img.shields.io/badge/Google%20Cloud-Platform-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)

**A fully automated, secure, and scalable multi-language development platform on Google Cloud Platform**

[Features](#-features) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## 📋 Overview

NexusForge is a production-ready, cloud-native development platform that provides:

- **Multi-Language Support**: Python 3.9, Node.js 16, and Go 1.18 microservices
- **Automated CI/CD**: GitHub Actions with Workload Identity Federation
- **Cloud Infrastructure**: GCP Cloud Run, Cloud SQL, and managed services
- **Monitoring & Observability**: Prometheus, Grafana, and structured logging
- **Security First**: IAP, Cloud Armor, Secret Manager, and RBAC
- **Developer Experience**: Hot reload, Docker Compose, VS Code integration

## ✨ Features

### 🚀 Multi-Language Microservices

| Language | Framework | ORM | Cache | Size |
|----------|-----------|-----|-------|------|
| **Python 3.9** | FastAPI | SQLAlchemy | Redis | ~150MB |
| **Node.js 16** | Express + TypeScript | Prisma | Redis | ~120MB |
| **Go 1.18** | Gin | GORM | Redis | ~15MB |

### 🔐 Security

- ✅ **Workload Identity Federation** - No service account keys
- ✅ **Cloud Armor** - DDoS protection and WAF
- ✅ **Identity-Aware Proxy** - Zero-trust access
- ✅ **Secret Manager** - Secure credential storage
- ✅ **VPC** - Network isolation
- ✅ **RBAC** - Role-based access control

### 🛠️ Infrastructure

- ✅ **Cloud Run** - Serverless container deployment
- ✅ **Cloud SQL** - Managed PostgreSQL 14
- ✅ **Memorystore** - Managed Redis 6
- ✅ **Artifact Registry** - Container image storage
- ✅ **Cloud Logging** - Centralized logs
- ✅ **Cloud Monitoring** - Metrics and alerts

### 📊 Monitoring

- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Visualization dashboards
- ✅ **Health Checks** - Kubernetes-ready endpoints
- ✅ **Structured Logging** - JSON logs with context
- ✅ **Alert Policies** - Automated notifications

### 🔄 CI/CD

- ✅ **GitHub Actions** - Automated workflows
- ✅ **Multi-Environment** - Dev, Staging, Production
- ✅ **Security Scanning** - Trivy, Snyk integration
- ✅ **Automated Testing** - Unit, integration, E2E
- ✅ **Canary Deployment** - Progressive rollouts
- ✅ **Automated Backups** - Daily database snapshots

## 🚀 Quick Start

### Prerequisites

- **GCP Account** with billing enabled
- **GitHub Repository** with Actions enabled
- **Local Tools**:
  - Docker & Docker Compose
  - gcloud CLI
  - Git
  - VS Code (recommended)

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/nexusforge-platform.git
cd nexusforge-platform
```

### 2. GCP Setup (Interactive)

```bash
# Run interactive setup wizard
./infrastructure/scripts/00-setup-manager.sh

# Or manual setup
./infrastructure/scripts/01-gcp-initial-setup.sh
./infrastructure/scripts/02-workload-identity-setup.sh
```

### 3. Local Development

```bash
# Start all services with Docker Compose
docker-compose -f config/docker/docker-compose-all-in-one.yml up -d

# Check service health
curl http://localhost:8000/health  # Python
curl http://localhost:3000/health  # Node.js
curl http://localhost:8080/health  # Go
```

### 4. Deploy to GCP

```bash
# Commit and push to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main

# Or deploy manually
gcloud run deploy nexusforge-python \
  --image gcr.io/PROJECT_ID/nexusforge-python:latest \
  --platform managed \
  --region us-central1
```

## 📚 Documentation

### Getting Started
- [📖 Setup Guide](docs/01-SETUP.md) - Detailed installation instructions
- [💻 Development Guide](docs/02-DEVELOPMENT-GUIDE.md) - Local development workflow
- [🚢 Deployment Guide](docs/03-DEPLOYMENT-GUIDE.md) - Production deployment

### Operations
- [🔒 Security Guide](docs/04-SECURITY.md) - Security best practices
- [🔧 Troubleshooting](docs/05-TROUBLESHOOTING.md) - Common issues and solutions
- [🐳 Docker Guide](config/docker/README.md) - Container deployment
- [📊 Monitoring Guide](docs/09-MONITORING.md) - Observability setup

### Advanced
- [🏗️ Architecture](docs/08-ARCHITECTURE.md) - System design and patterns
- [📡 API Documentation](docs/07-API-DOCUMENTATION.md) - API reference
- [🔄 Disaster Recovery](docs/10-DISASTER-RECOVERY.md) - Backup and recovery

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet / Users                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                  ┌───────▼────────┐
                  │  Cloud Armor   │  ← DDoS Protection
                  │   (WAF/CDN)    │
                  └───────┬────────┘
                          │
                  ┌───────▼────────┐
                  │      IAP       │  ← Authentication
                  └───────┬────────┘
                          │
                  ┌───────▼────────┐
                  │  Load Balancer │
                  └───────┬────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼─────┐    ┌─────▼──────┐   ┌─────▼──────┐
   │  Python  │    │  Node.js   │   │     Go     │
   │ FastAPI  │    │  Express   │   │    Gin     │
   │ Cloud Run│    │ Cloud Run  │   │ Cloud Run  │
   └────┬─────┘    └─────┬──────┘   └─────┬──────┘
        │                │                 │
        └────────────────┼─────────────────┘
                         │
        ┌────────────────┼─────────────────┐
        │                │                 │
   ┌────▼──────┐    ┌───▼────────┐   ┌────▼──────┐
   │ Cloud SQL │    │ Memorystore│   │  Secret   │
   │PostgreSQL │    │   Redis    │   │  Manager  │
   └───────────┘    └────────────┘   └───────────┘
```

### Technology Stack

**Backend Services:**
- Python 3.9 + FastAPI + SQLAlchemy + Alembic
- Node.js 16 + Express + TypeScript + Prisma
- Go 1.18 + Gin + GORM

**Infrastructure:**
- GCP Cloud Run (serverless containers)
- Cloud SQL PostgreSQL 14 (managed database)
- Memorystore Redis 6 (managed cache)
- Artifact Registry (container images)

**CI/CD:**
- GitHub Actions (automation)
- Workload Identity Federation (secure auth)
- Multi-environment deployments

**Monitoring:**
- Prometheus (metrics)
- Grafana (dashboards)
- Cloud Logging (logs)
- Cloud Monitoring (alerts)

## 🔧 Project Structure

```
nexusforge-platform/
├── .github/
│   ├── actions/           # Reusable composite actions
│   ├── workflows/         # CI/CD pipelines
│   └── config/            # Environment configurations
├── config/
│   ├── docker/            # Dockerfiles and compose
│   ├── nginx/             # Reverse proxy config
│   ├── monitoring/        # Prometheus, Grafana
│   └── security/          # Security policies
├── infrastructure/
│   ├── scripts/           # Setup and automation scripts
│   └── terraform/         # IaC (optional)
├── workspace/
│   ├── python/            # FastAPI service (38 files)
│   ├── nodejs/            # Express service (33 files)
│   └── go/                # Gin service (26 files)
├── docs/                  # Documentation
├── scripts/               # Utility scripts
└── tests/                 # End-to-end tests
```

## 🛠️ Development

### Local Setup

```bash
# Install dependencies
cd workspace/python && pip install -r requirements.txt
cd workspace/nodejs && npm install
cd workspace/go && go mod download

# Start development servers
cd workspace/python && make run
cd workspace/nodejs && npm run dev
cd workspace/go && make run
```

### Testing

```bash
# Python
cd workspace/python && pytest

# Node.js
cd workspace/nodejs && npm test

# Go
cd workspace/go && make test
```

### Docker Development

```bash
# Start all services
docker-compose -f config/docker/docker-compose-all-in-one.yml up -d

# View logs
docker-compose logs -f python-api

# Stop services
docker-compose down
```

## 📊 Monitoring

Access monitoring dashboards:

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001 (admin/admin)
- **Adminer**: http://localhost:8081 (database UI)
- **Redis Commander**: http://localhost:8082

## 🔐 Security

### Implemented Security Features

- **Authentication**: JWT tokens with refresh
- **Authorization**: Role-based access control (RBAC)
- **Network Security**: VPC, Cloud Armor, IAP
- **Data Security**: Secret Manager, encrypted connections
- **Container Security**: Non-root users, minimal images
- **API Security**: Rate limiting, input validation

### Security Scanning

```bash
# Scan Docker images
docker scan nexusforge-python:latest

# Security audit (Python)
cd workspace/python && pip-audit

# Security audit (Node.js)
cd workspace/nodejs && npm audit

# Security audit (Go)
cd workspace/go && gosec ./...
```

## 🤝 Contributing

We welcome contributions! Please see:

- [Contributing Guidelines](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Development Guide](docs/02-DEVELOPMENT-GUIDE.md)

### Development Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Run linters and tests
5. Commit with conventional commits (`git commit -m 'feat: add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📈 Roadmap

- [x] Multi-language microservices (Python, Node.js, Go)
- [x] Automated CI/CD with GitHub Actions
- [x] GCP Cloud Run deployment
- [x] Monitoring and observability
- [x] Comprehensive documentation
- [ ] GraphQL API gateway
- [ ] gRPC inter-service communication
- [ ] Service mesh (Istio)
- [ ] Multi-region deployment
- [ ] Advanced caching strategies
- [ ] Machine learning pipeline

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [FastAPI](https://fastapi.tiangolo.com/), [Express](https://expressjs.com/), and [Gin](https://gin-gonic.com/)
- Deployed on [Google Cloud Platform](https://cloud.google.com/)
- Monitored with [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/)
- Inspired by cloud-native best practices

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/yourusername/nexusforge-platform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/nexusforge-platform/discussions)

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/nexusforge-platform&type=Date)](https://star-history.com/#yourusername/nexusforge-platform&Date)

---

<div align="center">

**[⬆ Back to Top](#nexusforge-platform)**

Made with ❤️ by the NexusForge Team

</div>
