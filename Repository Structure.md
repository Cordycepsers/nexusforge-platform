# Complete NexusForge Platform Repository Structure

```
nexusforge-platform/
├── .github/
│   ├── actions/                              # Reusable composite actions
│   │   ├── setup-gcp/
│   │   │   └── action.yml                    # GCP authentication setup
│   │   ├── security-scan/
│   │   │   └── action.yml                    # Security scanning action
│   │   ├── build-and-push-image/
│   │   │   └── action.yml                    # Docker build & push action
│   │   ├── deploy-cloud-run/
│   │   │   └── action.yml                    # Cloud Run deployment action
│   │   └── run-tests/
│   │       └── action.yml                    # Testing action
│   │
│   ├── config/                               # Centralized configuration
│   │   ├── environments.yml                  # Environment-specific settings
│   │   └── services.yml                      # Service-specific configuration
│   │
│   ├── workflows/                            # GitHub Actions workflows
│   │   ├── 01-infrastructure-setup.yml       # Infrastructure provisioning
│   │   ├── 02-deploy-dev.yml                # Development deployment
│   │   ├── 03-deploy-staging.yml            # Staging deployment
│   │   ├── 04-deploy-prod.yml               # Production deployment
│   │   ├── 05-security-scan.yml             # Scheduled security scanning
│   │   ├── 06-backup.yml                    # Backup automation
│   │   ├── 07-disaster-recovery.yml         # DR procedures
│   │   ├── reusable-security-scan.yml       # Reusable security workflow
│   │   ├── reusable-test.yml                # Reusable test workflow
│   │   ├── reusable-build-push.yml          # Reusable build workflow
│   │   └── reusable-deploy.yml              # Reusable deploy workflow
│   │
│   └── CODEOWNERS                            # Code ownership definition
│
├── config/                                    # Configuration files
│   ├── docker/                               # Docker configurations
│   │   ├── Dockerfile.python                 # Python service Dockerfile
│   │   ├── Dockerfile.node                   # Node.js service Dockerfile
│   │   ├── Dockerfile.go                     # Go service Dockerfile
│   │   ├── docker-compose.yml               # Standard Docker Compose
│   │   ├── docker-compose-all-in-one.yml    # All-in-One Docker Compose
│   │   ├── .dockerignore                     # Docker ignore patterns
│   │   └── postgres/
│   │       └── init-multiple-databases.sh    # PostgreSQL init script
│   │
│   ├── nginx/                                # Nginx configurations
│   │   ├── nginx.conf                        # Standard Nginx config
│   │   ├── nginx-all-in-one.conf            # All-in-One Nginx config
│   │   └── ssl/                              # SSL certificates
│   │       ├── .gitkeep
│   │       └── README.md                     # SSL setup instructions
│   │
│   ├── monitoring/                           # Monitoring configurations
│   │   ├── alerts.yaml                       # Alert policies
│   │   ├── dashboards/                       # Grafana dashboards
│   │   │   ├── overview-dashboard.json
│   │   │   ├── application-dashboard.json
│   │   │   └── infrastructure-dashboard.json
│   │   └── prometheus/
│   │       └── prometheus.yml                # Prometheus config
│   │
│   ├── security/                             # Security configurations
│   │   ├── cloud-armor-rules.yaml           # Cloud Armor rules
│   │   ├── iap-config.yaml                  # IAP configuration
│   │   └── rbac-policies.yaml               # RBAC policies
│   │
│   ├── vscode/                               # VS Code configurations
│   │   ├── settings.json                     # Workspace settings
│   │   ├── extensions.json                   # Recommended extensions
│   │   ├── launch.json                       # Debug configurations
│   │   └── tasks.json                        # Task definitions
│   │
│   └── gitlab-ci/                            # GitLab CI/CD (alternative)
│       └── .gitlab-ci.yml                    # GitLab pipeline config
│
├── infrastructure/                            # Infrastructure as Code
│   ├── scripts/                              # Setup and maintenance scripts
│   │   ├── 00-setup-manager.sh              # Interactive setup wizard
│   │   ├── 01-gcp-initial-setup.sh          # Initial GCP configuration
│   │   ├── 02-workload-identity-setup.sh    # Workload Identity Federation
│   │   ├── 02-dev-vm-setup.sh               # Standard VM setup
│   │   ├── 03-dev-vm-all-in-one-setup.sh    # All-in-One VM setup
│   │   ├── 04-monitoring-setup.sh           # Monitoring configuration
│   │   ├── 05-backup-setup.sh               # Backup configuration
│   │   └── README.md                         # Scripts documentation
│   │
│   ├── terraform/                            # Terraform configurations (optional)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── prod/
│   │   └── modules/
│   │       ├── vpc/
│   │       ├── compute/
│   │       ├── cloud-sql/
│   │       └── cloud-run/
│   │
│   └── cloudbuild/                           # Cloud Build configurations
│       ├── cloudbuild-dev.yaml
│       ├── cloudbuild-staging.yaml
│       └── cloudbuild-prod.yaml
│
├── workspace/                                 # Development workspace
│   ├── python/                               # Python projects
│   │   ├── app/
│   │   │   ├── __init__.py
│   │   │   ├── main.py                       # Application entry point
│   │   │   ├── config.py                     # Configuration
│   │   │   ├── models/                       # Data models
│   │   │   │   ├── __init__.py
│   │   │   │   └── user.py
│   │   │   ├── routes/                       # API routes
│   │   │   │   ├── __init__.py
│   │   │   │   ├── health.py
│   │   │   │   └── api.py
│   │   │   ├── services/                     # Business logic
│   │   │   │   ├── __init__.py
│   │   │   │   └── user_service.py
│   │   │   └── utils/                        # Utilities
│   │   │       ├── __init__.py
│   │   │       ├── logger.py
│   │   │       └── database.py
│   │   ├── tests/                            # Tests
│   │   │   ├── __init__.py
│   │   │   ├── test_health.py
│   │   │   ├── unit/
│   │   │   │   └── test_user_service.py
│   │   │   └── integration/
│   │   │       └── test_api.py
│   │   ├── alembic/                          # Database migrations
│   │   │   ├── versions/
│   │   │   ├── env.py
│   │   │   └── script.py.mako
│   │   ├── requirements.txt                  # Python dependencies
│   │   ├── requirements-dev.txt             # Development dependencies
│   │   ├── alembic.ini                       # Alembic configuration
│   │   ├── pytest.ini                        # Pytest configuration
│   │   ├── .pylintrc                         # Pylint configuration
│   │   ├── pyproject.toml                    # Python project config
│   │   └── README.md                         # Python service docs
│   │
│   ├── nodejs/                               # Node.js projects
│   │   ├── src/
│   │   │   ├── index.ts                      # Application entry point
│   │   │   ├── config/
│   │   │   │   └── index.ts
│   │   │   ├── controllers/                  # Controllers
│   │   │   │   ├── health.controller.ts
│   │   │   │   └── user.controller.ts
│   │   │   ├── models/                       # Data models
│   │   │   │   └── user.model.ts
│   │   │   ├── routes/                       # Routes
│   │   │   │   ├── index.ts
│   │   │   │   ├── health.routes.ts
│   │   │   │   └── user.routes.ts
│   │   │   ├── services/                     # Services
│   │   │   │   └── user.service.ts
│   │   │   ├── middleware/                   # Middleware
│   │   │   │   ├── auth.middleware.ts
│   │   │   │   └── error.middleware.ts
│   │   │   └── utils/                        # Utilities
│   │   │       ├── logger.ts
│   │   │       └── database.ts
│   │   ├── tests/                            # Tests
│   │   │   ├── unit/
│   │   │   │   └── user.service.spec.ts
│   │   │   ├── integration/
│   │   │   │   └── api.spec.ts
│   │   │   └── e2e/
│   │   │       └── health.e2e.spec.ts
│   │   ├── prisma/                           # Prisma ORM
│   │   │   ├── schema.prisma
│   │   │   └── migrations/
│   │   ├── package.json                      # NPM dependencies
│   │   ├── package-lock.json
│   │   ├── tsconfig.json                     # TypeScript config
│   │   ├── .eslintrc.js                      # ESLint config
│   │   ├── .prettierrc                       # Prettier config
│   │   ├── jest.config.js                    # Jest config
│   │   └── README.md                         # Node.js service docs
│   │
│   ├── go/                                   # Go projects
│   │   ├── cmd/
│   │   │   └── api/
│   │   │       └── main.go                   # Application entry point
│   │   ├── internal/
│   │   │   ├── config/
│   │   │   │   └── config.go
│   │   │   ├── handlers/                     # HTTP handlers
│   │   │   │   ├── health.go
│   │   │   │   └── user.go
│   │   │   ├── models/                       # Data models
│   │   │   │   └── user.go
│   │   │   ├── services/                     # Business logic
│   │   │   │   └── user_service.go
│   │   │   ├── repository/                   # Data access
│   │   │   │   └── user_repository.go
│   │   │   └── middleware/                   # Middleware
│   │   │       ├── auth.go
│   │   │       └── logger.go
│   │   ├── pkg/                              # Public packages
│   │   │   ├── logger/
│   │   │   │   └── logger.go
│   │   │   └── database/
│   │   │       └── postgres.go
│   │   ├── tests/                            # Tests
│   │   │   ├── unit/
│   │   │   │   └── user_service_test.go
│   │   │   └── integration/
│   │   │       └── api_test.go
│   │   ├── migrations/                       # Database migrations
│   │   │   ├── 000001_create_users.up.sql
│   │   │   └── 000001_create_users.down.sql
│   │   ├── go.mod                            # Go modules
│   │   ├── go.sum                            # Go dependencies
│   │   ├── .golangci.yml                     # GolangCI-Lint config
│   │   ├── Makefile                          # Build automation
│   │   └── README.md                         # Go service docs
│   │
│   └── shared/                               # Shared resources
│       ├── proto/                            # Protocol buffers (if using gRPC)
│       │   └── api.proto
│       ├── schemas/                          # Shared schemas
│       │   └── api-schema.json
│       └── docs/                             # Shared documentation
│           └── api-standards.md
│
├── docs/                                      # Documentation
│   ├── 01-SETUP.md                           # Setup guide
│   ├── 02-DEVELOPMENT-GUIDE.md              # Development guide
│   ├── 03-DEPLOYMENT-GUIDE.md               # Deployment guide
│   ├── 04-SECURITY.md                        # Security practices
│   ├── 05-TROUBLESHOOTING.md                # Troubleshooting guide
│   ├── 06-ALL-IN-ONE-SETUP.md               # All-in-One specific docs
│   ├── 07-API-DOCUMENTATION.md              # API documentation
│   ├── 08-ARCHITECTURE.md                    # Architecture overview
│   ├── 09-MONITORING.md                      # Monitoring guide
│   ├── 10-DISASTER-RECOVERY.md              # DR procedures
│   ├── images/                               # Documentation images
│   │   ├── architecture-diagram.png
│   │   ├── deployment-flow.png
│   │   └── monitoring-dashboard.png
│   └── diagrams/                             # Architecture diagrams
│       ├── architecture.drawio
│       └── network-topology.drawio
│
├── scripts/                                   # Utility scripts
│   ├── utilities/
│   │   ├── monitor-all-in-one.sh            # Monitoring script
│   │   ├── backup-database.sh               # Database backup
│   │   ├── restore-database.sh              # Database restore
│   │   ├── health-check.sh                  # Health check script
│   │   ├── log-viewer.sh                    # Log viewing utility
│   │   └── security-audit.sh                # Security audit script
│   │
│   ├── migrations/
│   │   ├── run-python-migrations.sh
│   │   ├── run-node-migrations.sh
│   │   └── run-go-migrations.sh
│   │
│   └── deployment/
│       ├── deploy-service.sh                # Deploy single service
│       ├── rollback-service.sh              # Rollback service
│       └── canary-promote.sh                # Promote canary
│
├── tests/                                     # End-to-end tests
│   ├── e2e/
│   │   ├── cypress/                          # Cypress tests
│   │   │   ├── integration/
│   │   │   │   ├── api.spec.js
│   │   │   │   └── health.spec.js
│   │   │   ├── fixtures/
│   │   │   └── support/
│   │   └── cypress.json
│   │
│   ├── load/                                 # Load testing
│   │   ├── locustfile.py                    # Locust load tests
│   │   └── k6-script.js                     # k6 load tests
│   │
│   └── security/                             # Security tests
│       ├── zap-config.yaml                  # OWASP ZAP config
│       └── security-test-plan.md
│
├── examples/                                  # Example code
│   ├── python/
│   │   ├── fastapi-example.py
│   │   ├── flask-example.py
│   │   └── django-example.py
│   ├── nodejs/
│   │   ├── express-example.ts
│   │   └── nestjs-example.ts
│   └── go/
│       ├── http-example.go
│       └── gin-example.go
│
├── tools/                                     # Development tools
│   ├── local-setup/
│   │   ├── setup-python-env.sh
│   │   ├── setup-node-env.sh
│   │   └── setup-go-env.sh
│   │
│   └── generators/
│       ├── generate-service.sh              # Service scaffold generator
│       └── templates/
│           ├── service-template-python/
│           ├── service-template-node/
│           └── service-template-go/
│
├── .vscode/                                   # VS Code workspace settings
│   ├── settings.json                         # Workspace settings
│   ├── extensions.json                       # Recommended extensions
│   ├── launch.json                           # Debug configurations
│   └── tasks.json                            # Task definitions
│
├── .gitignore                                 # Git ignore patterns
├── .dockerignore                             # Docker ignore patterns
├── .editorconfig                             # Editor configuration
├── .prettierrc                               # Prettier configuration
├── .eslintrc.js                              # ESLint configuration
├── LICENSE                                    # License file
├── README.md                                  # Main README
├── CONTRIBUTING.md                           # Contribution guidelines
├── CHANGELOG.md                              # Changelog
├── CODE_OF_CONDUCT.md                        # Code of conduct
├── SECURITY.md                               # Security policy
├── Makefile                                  # Make commands
└── package.json                              # Root package.json (for tools)
```

---

## 📁 Key Directory Explanations

### `.github/`
Contains all GitHub-specific configurations including Actions workflows, reusable actions, and centralized configuration files.

### `config/`
All configuration files for Docker, Nginx, monitoring, security, and development tools. This is the single source of truth for application configuration.

### `infrastructure/`
Infrastructure as Code (IaC) including setup scripts, Terraform configurations (optional), and Cloud Build definitions.

### `workspace/`
The actual application code organized by language. Each language has its own self-contained project structure with tests, configs, and documentation.

### `docs/`
Comprehensive documentation covering setup, development, deployment, security, troubleshooting, and architecture.

### `scripts/`
Utility scripts for operations, monitoring, backups, and deployments. These are helper scripts that don't fit into infrastructure setup.

### `tests/`
End-to-end, load, and security tests that span multiple services or test the platform as a whole.

### `examples/`
Example code and templates for getting started with each supported language and framework.

---

## 🚀 Quick Start Commands

```bash
# Clone the repository
git clone https://github.com/your-org/nexusforge-platform.git
cd nexusforge-platform

# Make scripts executable
chmod +x infrastructure/scripts/*.sh
chmod +x scripts/utilities/*.sh

# Run interactive setup
./infrastructure/scripts/00-setup-manager.sh

# Or run specific setup
cd infrastructure/scripts
./01-gcp-initial-setup.sh
./03-dev-vm-all-in-one-setup.sh

# Start local development (All-in-One)
cd config/docker
docker-compose -f docker-compose-all-in-one.yml up -d

# Run tests
make test

# Monitor services
./scripts/utilities/monitor-all-in-one.sh --watch
```

---

## 📝 File Naming Conventions

- **Scripts**: `kebab-case.sh`
- **Python files**: `snake_case.py`
- **JavaScript/TypeScript**: `camelCase.ts` or `kebab-case.ts`
- **Go files**: `snake_case.go`
- **Config files**: `kebab-case.yml` or `kebab-case.json`
- **Documentation**: `UPPERCASE.md` for main docs, `kebab-case.md` for guides

---

## 🔒 Sensitive Files (NOT in repo)

These files should be `.gitignore`d and created locally:

```
# Secrets and credentials
.env
*.key
*.pem
*.p12
*-key.json
service-account-key.json

# Local development
.vscode/settings.local.json
config/nginx/ssl/*.crt
config/nginx/ssl/*.key

# Build artifacts
*.log
node_modules/
__pycache__/
*.pyc
bin/
dist/
build/
target/

# IDE specific
.idea/
*.swp
*.swo
.DS_Store
```

---

## 📦 Initial Repository Setup

```bash
# Initialize repository
git init
git add .
git commit -m "Initial commit: NexusForge Platform"

# Create branches
git branch develop
git branch staging

# Add remote
git remote add origin https://github.com/your-org/nexusforge-platform.git

# Push all branches
git push -u origin main develop staging

# Create initial release
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0
```

---

This structure provides:
- ✅ Clear separation of concerns
- ✅ Language-specific organization
- ✅ Comprehensive documentation
- ✅ Reusable components
- ✅ Easy navigation
- ✅ Scalable architecture
- ✅ Standard conventions
