# NexusForge Platform Makefile
# 
# This Makefile provides convenient commands for common development,
# testing, building, and deployment tasks across all services.

.PHONY: help
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Configuration
PROJECT_ID ?= nexusforge-prod
REGION ?= us-central1
DOCKER_COMPOSE := docker-compose -f config/docker/docker-compose-all-in-one.yml

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(BLUE)Usage:$(NC)\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

install: install-python install-node install-go ## Install all dependencies

install-python: ## Install Python dependencies
	@echo "$(BLUE)Installing Python dependencies...$(NC)"
	cd workspace/python && pip install -r requirements.txt -r requirements-dev.txt

install-node: ## Install Node.js dependencies
	@echo "$(BLUE)Installing Node.js dependencies...$(NC)"
	cd workspace/nodejs && npm install

install-go: ## Install Go dependencies
	@echo "$(BLUE)Installing Go dependencies...$(NC)"
	cd workspace/go && go mod download

dev: ## Start all services in development mode
	@echo "$(BLUE)Starting all services...$(NC)"
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo "Python API:    http://localhost:8000"
	@echo "Node.js API:   http://localhost:3000"
	@echo "Go API:        http://localhost:8080"
	@echo "Prometheus:    http://localhost:9090"
	@echo "Grafana:       http://localhost:3001"

dev-python: ## Start Python service only
	@echo "$(BLUE)Starting Python service...$(NC)"
	cd workspace/python && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

dev-node: ## Start Node.js service only
	@echo "$(BLUE)Starting Node.js service...$(NC)"
	cd workspace/nodejs && npm run dev

dev-go: ## Start Go service only
	@echo "$(BLUE)Starting Go service...$(NC)"
	cd workspace/go && go run cmd/api/main.go

stop: ## Stop all services
	@echo "$(BLUE)Stopping all services...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)Services stopped$(NC)"

restart: stop dev ## Restart all services

logs: ## View logs from all services
	$(DOCKER_COMPOSE) logs -f

logs-python: ## View Python service logs
	$(DOCKER_COMPOSE) logs -f python-api

logs-node: ## View Node.js service logs
	$(DOCKER_COMPOSE) logs -f nodejs-api

logs-go: ## View Go service logs
	$(DOCKER_COMPOSE) logs -f go-api

##@ Testing

test: test-python test-node test-go ## Run all tests

test-python: ## Run Python tests
	@echo "$(BLUE)Running Python tests...$(NC)"
	cd workspace/python && pytest

test-python-cov: ## Run Python tests with coverage
	@echo "$(BLUE)Running Python tests with coverage...$(NC)"
	cd workspace/python && pytest --cov=app --cov-report=html --cov-report=term

test-node: ## Run Node.js tests
	@echo "$(BLUE)Running Node.js tests...$(NC)"
	cd workspace/nodejs && npm test

test-node-cov: ## Run Node.js tests with coverage
	@echo "$(BLUE)Running Node.js tests with coverage...$(NC)"
	cd workspace/nodejs && npm run test:coverage

test-go: ## Run Go tests
	@echo "$(BLUE)Running Go tests...$(NC)"
	cd workspace/go && go test ./...

test-go-cov: ## Run Go tests with coverage
	@echo "$(BLUE)Running Go tests with coverage...$(NC)"
	cd workspace/go && go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	cd workspace/python && pytest tests/integration/
	cd workspace/nodejs && npm run test:integration
	cd workspace/go && go test -tags=integration ./...

##@ Code Quality

lint: lint-python lint-node lint-go ## Run all linters

lint-python: ## Lint Python code
	@echo "$(BLUE)Linting Python code...$(NC)"
	cd workspace/python && pylint app/

lint-node: ## Lint Node.js code
	@echo "$(BLUE)Linting Node.js code...$(NC)"
	cd workspace/nodejs && npm run lint

lint-go: ## Lint Go code
	@echo "$(BLUE)Linting Go code...$(NC)"
	cd workspace/go && golangci-lint run

format: format-python format-node format-go ## Format all code

format-python: ## Format Python code
	@echo "$(BLUE)Formatting Python code...$(NC)"
	cd workspace/python && black app/ tests/
	cd workspace/python && isort app/ tests/

format-node: ## Format Node.js code
	@echo "$(BLUE)Formatting Node.js code...$(NC)"
	cd workspace/nodejs && npm run format

format-go: ## Format Go code
	@echo "$(BLUE)Formatting Go code...$(NC)"
	cd workspace/go && go fmt ./...

check: lint test ## Run linters and tests

##@ Database

db-migrate-python: ## Run Python database migrations
	@echo "$(BLUE)Running Python migrations...$(NC)"
	cd workspace/python && alembic upgrade head

db-migrate-node: ## Run Node.js database migrations
	@echo "$(BLUE)Running Node.js migrations...$(NC)"
	cd workspace/nodejs && npx prisma migrate deploy

db-migrate-go: ## Run Go database migrations
	@echo "$(BLUE)Running Go migrations...$(NC)"
	cd workspace/go && migrate -path migrations -database "$${DATABASE_URL}" up

db-rollback-python: ## Rollback Python migrations
	cd workspace/python && alembic downgrade -1

db-rollback-node: ## Rollback Node.js migrations
	cd workspace/nodejs && npx prisma migrate resolve --rolled-back

db-rollback-go: ## Rollback Go migrations
	cd workspace/go && migrate -path migrations -database "$${DATABASE_URL}" down 1

db-seed: ## Seed databases with test data
	@echo "$(BLUE)Seeding databases...$(NC)"
	# Add seed commands here

db-backup: ## Backup databases
	@echo "$(BLUE)Backing up databases...$(NC)"
	./scripts/utilities/backup-database.sh -c -u

db-restore: ## Restore databases from backup
	@echo "$(BLUE)Restoring databases...$(NC)"
	@echo "Usage: make db-restore FILE=path/to/backup.sql"
	./scripts/utilities/restore-database.sh -f $(FILE)

##@ Docker

build: build-python build-node build-go ## Build all Docker images

build-python: ## Build Python Docker image
	@echo "$(BLUE)Building Python image...$(NC)"
	docker build -f config/docker/Dockerfile.python -t nexusforge-python:latest .

build-node: ## Build Node.js Docker image
	@echo "$(BLUE)Building Node.js image...$(NC)"
	docker build -f config/docker/Dockerfile.node -t nexusforge-nodejs:latest .

build-go: ## Build Go Docker image
	@echo "$(BLUE)Building Go image...$(NC)"
	docker build -f config/docker/Dockerfile.go -t nexusforge-go:latest .

push: ## Push Docker images to registry
	@echo "$(BLUE)Pushing images to registry...$(NC)"
	docker tag nexusforge-python:latest gcr.io/$(PROJECT_ID)/nexusforge-python:latest
	docker tag nexusforge-nodejs:latest gcr.io/$(PROJECT_ID)/nexusforge-nodejs:latest
	docker tag nexusforge-go:latest gcr.io/$(PROJECT_ID)/nexusforge-go:latest
	docker push gcr.io/$(PROJECT_ID)/nexusforge-python:latest
	docker push gcr.io/$(PROJECT_ID)/nexusforge-nodejs:latest
	docker push gcr.io/$(PROJECT_ID)/nexusforge-go:latest

clean-docker: ## Remove all containers and images
	@echo "$(BLUE)Cleaning Docker resources...$(NC)"
	$(DOCKER_COMPOSE) down -v
	docker system prune -f

##@ Deployment

deploy: deploy-python deploy-node deploy-go ## Deploy all services to Cloud Run

deploy-python: ## Deploy Python service to Cloud Run
	@echo "$(BLUE)Deploying Python service...$(NC)"
	gcloud run deploy nexusforge-python \
		--image gcr.io/$(PROJECT_ID)/nexusforge-python:latest \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated

deploy-node: ## Deploy Node.js service to Cloud Run
	@echo "$(BLUE)Deploying Node.js service...$(NC)"
	gcloud run deploy nexusforge-nodejs \
		--image gcr.io/$(PROJECT_ID)/nexusforge-nodejs:latest \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated

deploy-go: ## Deploy Go service to Cloud Run
	@echo "$(BLUE)Deploying Go service...$(NC)"
	gcloud run deploy nexusforge-go \
		--image gcr.io/$(PROJECT_ID)/nexusforge-go:latest \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated

##@ Monitoring

monitor: ## Monitor all services
	./scripts/utilities/monitor-all-in-one.sh -c

monitor-once: ## Run single monitoring check
	./scripts/utilities/monitor-all-in-one.sh

health-check: ## Check health of all services
	./scripts/utilities/health-check.sh

health-check-cloud: ## Check health of cloud services
	./scripts/utilities/health-check.sh -e prod

##@ Utilities

clean: clean-python clean-node clean-go ## Clean all build artifacts

clean-python: ## Clean Python build artifacts
	@echo "$(BLUE)Cleaning Python artifacts...$(NC)"
	find workspace/python -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find workspace/python -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf workspace/python/.pytest_cache 2>/dev/null || true
	rm -rf workspace/python/htmlcov 2>/dev/null || true
	rm -f workspace/python/.coverage 2>/dev/null || true

clean-node: ## Clean Node.js build artifacts
	@echo "$(BLUE)Cleaning Node.js artifacts...$(NC)"
	rm -rf workspace/nodejs/node_modules 2>/dev/null || true
	rm -rf workspace/nodejs/dist 2>/dev/null || true
	rm -rf workspace/nodejs/coverage 2>/dev/null || true

clean-go: ## Clean Go build artifacts
	@echo "$(BLUE)Cleaning Go artifacts...$(NC)"
	rm -rf workspace/go/bin 2>/dev/null || true
	rm -f workspace/go/coverage.out 2>/dev/null || true
	cd workspace/go && go clean

setup: ## Initial setup of the project
	@echo "$(BLUE)Setting up project...$(NC)"
	@echo "1. Installing dependencies..."
	@make install
	@echo "2. Setting up environment files..."
	@cp workspace/python/.env.example workspace/python/.env 2>/dev/null || true
	@cp workspace/nodejs/.env.example workspace/nodejs/.env 2>/dev/null || true
	@cp workspace/go/.env.example workspace/go/.env 2>/dev/null || true
	@echo "$(GREEN)Setup complete! Edit .env files and run 'make dev'$(NC)"

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@echo "Documentation already in docs/ directory"

version: ## Show version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "Python:  $$(python3 --version 2>&1)"
	@echo "Node.js: $$(node --version 2>&1)"
	@echo "Go:      $$(go version 2>&1)"
	@echo "Docker:  $$(docker --version 2>&1)"
	@echo "gcloud:  $$(gcloud --version 2>&1 | head -n 1)"

info: ## Show project information
	@echo "$(BLUE)NexusForge Platform$(NC)"
	@echo "Project ID:   $(PROJECT_ID)"
	@echo "Region:       $(REGION)"
	@echo ""
	@echo "Services:"
	@echo "  Python API:    http://localhost:8000"
	@echo "  Node.js API:   http://localhost:3000"
	@echo "  Go API:        http://localhost:8080"
	@echo ""
	@echo "Monitoring:"
	@echo "  Prometheus:    http://localhost:9090"
	@echo "  Grafana:       http://localhost:3001"
	@echo ""
	@echo "For more information, run: make help"
