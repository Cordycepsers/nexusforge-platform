# Go Service Build Automation

.PHONY: help build run test lint clean docker-build docker-run migrate

# Variables
APP_NAME=nexusforge-go-api
DOCKER_IMAGE=nexusforge-go
VERSION=1.0.0

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the application
	@echo "Building $(APP_NAME)..."
	go build -o bin/$(APP_NAME) cmd/api/main.go

run: ## Run the application
	@echo "Running $(APP_NAME)..."
	go run cmd/api/main.go

dev: ## Run with hot reload (requires air)
	@echo "Running in development mode..."
	air

test: ## Run tests
	@echo "Running tests..."
	go test -v ./...

test-coverage: ## Run tests with coverage
	@echo "Running tests with coverage..."
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint: ## Run linter
	@echo "Running linter..."
	golangci-lint run

fmt: ## Format code
	@echo "Formatting code..."
	go fmt ./...
	gofmt -s -w .

vet: ## Run go vet
	@echo "Running go vet..."
	go vet ./...

tidy: ## Tidy go modules
	@echo "Tidying modules..."
	go mod tidy

download: ## Download dependencies
	@echo "Downloading dependencies..."
	go mod download

clean: ## Clean build artifacts
	@echo "Cleaning..."
	rm -rf bin/
	rm -f coverage.out coverage.html

docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -f ../../config/docker/Dockerfile.go -t $(DOCKER_IMAGE):$(VERSION) .
	docker tag $(DOCKER_IMAGE):$(VERSION) $(DOCKER_IMAGE):latest

docker-run: ## Run Docker container
	@echo "Running Docker container..."
	docker run -p 8080:8080 \
		-e DB_HOST=host.docker.internal \
		-e REDIS_HOST=host.docker.internal \
		$(DOCKER_IMAGE):latest

migrate-up: ## Run database migrations up
	@echo "Running migrations up..."
	migrate -path migrations -database "${DATABASE_URL}" up

migrate-down: ## Run database migrations down
	@echo "Running migrations down..."
	migrate -path migrations -database "${DATABASE_URL}" down

migrate-create: ## Create a new migration (use NAME=migration_name)
	@echo "Creating migration: $(NAME)"
	migrate create -ext sql -dir migrations -seq $(NAME)

swagger: ## Generate Swagger documentation
	@echo "Generating Swagger docs..."
	swag init -g cmd/api/main.go

security-scan: ## Run security scan
	@echo "Running security scan..."
	gosec ./...

deps-update: ## Update dependencies
	@echo "Updating dependencies..."
	go get -u ./...
	go mod tidy

all: clean fmt vet lint test build ## Run all checks and build
