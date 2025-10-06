I need you to help me create a complete GitHub repository for the NexusForge Platform based on the following structure and requirements. Please generate ALL files with complete, production-ready code.

## Project Overview
NexusForge is a fully automated, secure, and scalable development platform on Google Cloud Platform (GCP) that supports Python 3.9, Node.js 16, and Go 1.18 development environments with integrated CI/CD, monitoring, and security features.

## Repository Structure
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

## Requirements

### Phase 1: Core Infrastructure Files
Generate the following files with complete implementation:

1. `.github/actions/setup-gcp/action.yml` - Composite action for GCP authentication
2. `.github/actions/security-scan/action.yml` - Comprehensive security scanning action
3. `.github/actions/build-and-push-image/action.yml` - Docker build and push to Artifact Registry
4. `.github/actions/deploy-cloud-run/action.yml` - Cloud Run deployment action
5. `.github/actions/run-tests/action.yml` - Multi-language testing action

Requirements for each action:
- Use composite action format
- Include proper input validation
- Add comprehensive error handling
- Include detailed comments
- Output useful information for debugging

### Phase 2: Reusable Workflows
Generate these reusable workflows:

1. `.github/workflows/reusable-security-scan.yml`
2. `.github/workflows/reusable-test.yml`
3. `.github/workflows/reusable-build-push.yml`
4. `.github/workflows/reusable-deploy.yml`

Each workflow should:
- Accept proper inputs and secrets
- Include comprehensive steps
- Generate summary outputs
- Handle errors gracefully
- Be truly reusable across environments

### Phase 3: Main Workflows
Create main workflows that use the reusable components:

1. `.github/workflows/01-infrastructure-setup.yml` - VM provisioning
2. `.github/workflows/02-deploy-dev.yml` - Development deployment
3. `.github/workflows/03-deploy-staging.yml` - Staging deployment with approval
4. `.github/workflows/04-deploy-prod.yml` - Production with canary deployment
5. `.github/workflows/05-security-scan.yml` - Scheduled security scanning
6. `.github/workflows/06-backup.yml` - Automated backups
7. `.github/workflows/07-disaster-recovery.yml` - DR procedures

### Phase 4: Configuration Files
Generate centralized configuration:

1. `.github/config/environments.yml` - Environment-specific settings
2. `.github/config/services.yml` - Service configurations
3. `config/docker/docker-compose-all-in-one.yml` - Complete Docker Compose setup
4. `config/nginx/nginx-all-in-one.conf` - Nginx reverse proxy configuration
5. `config/monitoring/prometheus.yml` - Prometheus configuration
6. `config/security/rbac-policies.yaml` - RBAC definitions

### Phase 5: Infrastructure Scripts
Create comprehensive bash scripts:

1. `infrastructure/scripts/00-setup-manager.sh` - Interactive setup wizard
2. `infrastructure/scripts/01-gcp-initial-setup.sh` - GCP project initialization
3. `infrastructure/scripts/02-workload-identity-setup.sh` - Workload Identity Federation
4. `infrastructure/scripts/02-dev-vm-setup.sh` - Standard VM setup
5. `infrastructure/scripts/03-dev-vm-all-in-one-setup.sh` - All-in-One VM setup

Each script should:
- Have proper error handling (set -euo pipefail)
- Include colored output for better UX
- Validate prerequisites
- Be idempotent where possible
- Include comprehensive comments

### Phase 6: Application Code
Generate sample applications for each language:

**Python (FastAPI):**
- `workspace/python/app/main.py` - FastAPI application with health checks
- `workspace/python/app/models/user.py` - Sample model
- `workspace/python/app/routes/api.py` - API routes
- `workspace/python/tests/test_health.py` - Sample tests
- `workspace/python/requirements.txt` - Dependencies

**Node.js (Express/TypeScript):**
- `workspace/nodejs/src/index.ts` - Express application
- `workspace/nodejs/src/controllers/user.controller.ts` - Sample controller
- `workspace/nodejs/src/routes/index.ts` - Routes
- `workspace/nodejs/tests/unit/user.service.spec.ts` - Sample tests
- `workspace/nodejs/package.json` - Dependencies

**Go:**
- `workspace/go/cmd/api/main.go` - HTTP server
- `workspace/go/internal/handlers/health.go` - Health check handler
- `workspace/go/internal/handlers/user.go` - User handler
- `workspace/go/tests/unit/user_service_test.go` - Sample tests
- `workspace/go/go.mod` - Dependencies

### Phase 7: Dockerfiles
Create optimized multi-stage Dockerfiles:

1. `config/docker/Dockerfile.python` - Python container with best practices
2. `config/docker/Dockerfile.node` - Node.js container with best practices
3. `config/docker/Dockerfile.go` - Go container with best practices

Each Dockerfile should:
- Use multi-stage builds
- Implement security best practices
- Minimize image size
- Include health checks
- Use non-root user

### Phase 8: Documentation
Generate comprehensive documentation:

1. `README.md` - Main project README with badges, quick start, features
2. `docs/01-SETUP.md` - Detailed setup instructions
3. `docs/02-DEVELOPMENT-GUIDE.md` - Development guide with examples
4. `docs/03-DEPLOYMENT-GUIDE.md` - Deployment procedures
5. `docs/04-SECURITY.md` - Security best practices
6. `docs/05-TROUBLESHOOTING.md` - Common issues and solutions
7. `docs/06-ALL-IN-ONE-SETUP.md` - All-in-One specific guide
8. `CONTRIBUTING.md` - Contribution guidelines
9. `CODE_OF_CONDUCT.md` - Code of conduct

### Phase 9: Utility Scripts
Create operational scripts:

1. `scripts/utilities/monitor-all-in-one.sh` - Resource monitoring
2. `scripts/utilities/backup-database.sh` - Database backup
3. `scripts/utilities/restore-database.sh` - Database restore
4. `scripts/utilities/health-check.sh` - System health check

### Phase 10: Configuration Files
Generate essential config files:

1. `.gitignore` - Comprehensive ignore patterns
2. `.dockerignore` - Docker ignore patterns
3. `.editorconfig` - Editor configuration
4. `Makefile` - Build automation
5. `.vscode/settings.json` - VS Code workspace settings
6. `.vscode/extensions.json` - Recommended extensions
7. `.vscode/launch.json` - Debug configurations

## Code Quality Requirements

For ALL generated code:
- ✅ Include comprehensive comments explaining complex logic
- ✅ Follow language-specific best practices and style guides
- ✅ Include error handling for all operations
- ✅ Use environment variables for configuration
- ✅ Implement proper logging
- ✅ Include validation for all inputs
- ✅ Make scripts idempotent where possible
- ✅ Add health checks and monitoring hooks
- ✅ Include examples and usage documentation
- ✅ Use secure defaults
- ✅ Implement proper cleanup on failure

## Security Requirements

- 🔒 Never hardcode credentials or secrets
- 🔒 Use GCP Secret Manager for sensitive data
- 🔒 Implement Workload Identity Federation (no service account keys)
- 🔒 Use least privilege principle for IAM roles
- 🔒 Enable all security features (VPC, IAP, Cloud Armor)
- 🔒 Implement input validation and sanitization
- 🔒 Use parameterized queries for databases
- 🔒 Enable TLS/SSL for all communications

## Testing Requirements

- 🧪 Include unit tests for business logic
- 🧪 Include integration tests for APIs
- 🧪 Add health check endpoints
- 🧪 Implement smoke tests for deployments
- 🧪 Add example test files showing proper patterns

## Documentation Requirements

- 📚 Every script should have a header comment explaining its purpose
- 📚 Include usage examples in documentation
- 📚 Document all environment variables
- 📚 Provide troubleshooting guides
- 📚 Include architecture diagrams in ASCII art
- 📚 Add inline comments for complex logic

## Special Instructions

1. **Start with Phase 1** and wait for my confirmation before proceeding to the next phase
2. **For each file**: Provide the complete file path and full file contents
3. **Be production-ready**: Code should be deployable without modifications
4. **Include real examples**: Use realistic data and scenarios
5. **Make it copy-paste ready**: I should be able to copy each file directly into my repository