# Go NexusForge Service

A production-ready Go microservice using Gin framework, GORM, Redis caching, and PostgreSQL for the NexusForge Platform.

## Features

- ✅ **Gin Framework** - High-performance HTTP router
- ✅ **GORM** - Type-safe ORM with auto-migration
- ✅ **Redis Caching** - Fast response times with intelligent caching
- ✅ **JWT Authentication** - Secure token-based auth
- ✅ **Structured Logging** - JSON logging with logrus
- ✅ **Prometheus Metrics** - Built-in metrics endpoint
- ✅ **Testing** - Comprehensive unit and integration tests
- ✅ **Security** - CORS, rate limiting, bcrypt password hashing
- ✅ **Health Checks** - Kubernetes-ready health endpoints

## Prerequisites

- Go 1.18+ 
- PostgreSQL 14+
- Redis 6+

## Quick Start

### 1. Install Dependencies

```bash
go mod download
```

### 2. Configure Environment

Copy the example environment file:

```bash
cp .env.example .env
```

Update `.env` with your configuration:

```env
ENV=development
PORT=8080
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your-password
DB_NAME=nexusforge_go
JWT_SECRET=your-secret-key-change-in-production
```

### 3. Run Database Migrations

The application automatically runs migrations on startup using GORM AutoMigrate.

### 4. Start Development Server

```bash
make run
# or
go run cmd/api/main.go
```

The API will be available at `http://localhost:8080`.

## Available Make Commands

### Development

```bash
make build          # Build the application
make run            # Run the application
make dev            # Run with hot reload (requires air)
make test           # Run tests
make test-coverage  # Run tests with coverage report
```

### Code Quality

```bash
make lint           # Run golangci-lint
make fmt            # Format code
make vet            # Run go vet
make tidy           # Tidy go modules
```

### Docker

```bash
make docker-build   # Build Docker image
make docker-run     # Run Docker container
```

### Database

```bash
make migrate-up     # Run migrations up
make migrate-down   # Run migrations down
make migrate-create NAME=migration_name  # Create new migration
```

## Project Structure

```
cmd/
└── api/
    └── main.go           # Application entry point

internal/
├── config/               # Configuration management
│   └── config.go
├── handlers/             # HTTP handlers
│   ├── health.go
│   └── user.go
├── middleware/           # Gin middleware
│   ├── auth.go
│   ├── cors.go
│   ├── logger.go
│   ├── metrics.go
│   ├── rate_limit.go
│   └── recovery.go
├── models/               # Data models
│   └── user.go
├── repository/           # Data access layer
│   └── user_repository.go
└── services/             # Business logic
    └── user_service.go

pkg/
├── cache/                # Redis cache
│   └── redis.go
├── database/             # Database connection
│   └── postgres.go
├── logger/               # Logging
│   └── logger.go
└── security/             # Security utilities
    └── security.go

tests/
├── health_test.go        # Health endpoint tests
└── unit/
    └── user_service_test.go  # Service unit tests
```

## API Documentation

### Health Endpoints

- `GET /health` - Basic health check
- `GET /health/ready` - Readiness check (DB + Redis)
- `GET /health/live` - Liveness check

### User Endpoints

- `POST /api/users` - Create new user (public)
- `GET /api/users` - List users (authenticated, paginated)
- `GET /api/users/me` - Get current user (authenticated)
- `GET /api/users/:id` - Get user by ID (authenticated)
- `PUT /api/users/:id` - Update user (authenticated, own profile)
- `DELETE /api/users/:id` - Delete user (superuser only)

### Authentication

Protected endpoints require a JWT token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Example Requests

**Create User:**

```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "johndoe",
    "password": "SecurePass123!"
  }'
```

**Get Current User:**

```bash
curl -X GET http://localhost:8080/api/users/me \
  -H "Authorization: Bearer <your-token>"
```

**List Users with Pagination:**

```bash
curl -X GET "http://localhost:8080/api/users?page=1&limit=10" \
  -H "Authorization: Bearer <your-token>"
```

## Environment Variables

### Required

- `DB_PASSWORD` - PostgreSQL password
- `JWT_SECRET` - Secret key for JWT signing

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV` | `development` | Environment (development/production) |
| `PORT` | `8080` | Server port |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_USER` | `postgres` | Database user |
| `DB_NAME` | `nexusforge_go` | Database name |
| `DB_SSL_MODE` | `disable` | SSL mode |
| `REDIS_HOST` | `localhost` | Redis host |
| `REDIS_PORT` | `6379` | Redis port |
| `JWT_EXPIRES_IN` | `24h` | JWT expiration time |
| `BCRYPT_COST` | `10` | Bcrypt hashing cost |
| `LOG_LEVEL` | `info` | Logging level |
| `LOG_FORMAT` | `json` | Log format (json/text) |
| `RATE_LIMIT_REQUESTS` | `100` | Max requests per window |
| `RATE_LIMIT_WINDOW` | `15m` | Rate limit window |
| `ENABLE_CACHE` | `true` | Enable Redis caching |
| `ENABLE_METRICS` | `true` | Enable Prometheus metrics |

## Caching Strategy

The service implements intelligent caching:

- **User by ID**: 5 minute TTL
- **Cache Invalidation**: Automatic on updates/deletes
- **Cache Keys**: `user:{id}` pattern

## Security Features

- **CORS**: Configurable cross-origin resource sharing
- **Rate Limiting**: Per-IP request limiting
- **JWT Authentication**: Secure token-based auth
- **Password Hashing**: bcrypt with configurable cost
- **Input Validation**: Gin binding validation
- **SQL Injection Protection**: GORM parameterized queries

## Monitoring

### Metrics Endpoint

Prometheus metrics available at `/metrics`:

```bash
curl http://localhost:8080/metrics
```

### Available Metrics

- `nexusforge_go_http_request_duration_seconds` - Request duration histogram
- `nexusforge_go_http_requests_total` - Total HTTP requests counter
- `nexusforge_go_active_connections` - Active connections gauge
- Default Go runtime metrics

### Logging

Structured JSON logs with logrus:

```json
{
  "level": "info",
  "msg": "HTTP request",
  "method": "GET",
  "path": "/api/users",
  "status": 200,
  "latency": "45ms",
  "time": "2024-01-15T10:30:45Z"
}
```

## Testing

### Run All Tests

```bash
make test
```

### Run with Coverage

```bash
make test-coverage
```

Coverage reports are generated as `coverage.html`.

### Test Structure

- **Unit Tests**: Test individual functions/services with mocks
- **Integration Tests**: Test HTTP endpoints end-to-end
- **Health Tests**: Verify health check endpoints

## Deployment

### Build for Production

```bash
make build
```

The binary will be created in `bin/nexusforge-go-api`.

### Run Production Binary

```bash
./bin/nexusforge-go-api
```

### Docker

Build Docker image:

```bash
docker build -f ../../config/docker/Dockerfile.go -t nexusforge-go:latest .
```

Run container:

```bash
docker run -p 8080:8080 \
  -e DB_HOST=postgres \
  -e DB_PASSWORD=password \
  -e REDIS_HOST=redis \
  -e JWT_SECRET=your-secret \
  nexusforge-go:latest
```

### GCP Cloud Run

Deploy to Cloud Run:

```bash
gcloud run deploy nexusforge-go \
  --image gcr.io/PROJECT_ID/nexusforge-go:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DB_HOST=...,DB_NAME=... \
  --set-secrets JWT_SECRET=jwt-secret:latest
```

## Performance

- **Gin**: One of the fastest Go web frameworks
- **GORM**: Efficient ORM with connection pooling
- **Redis Caching**: Reduces database load significantly
- **Compiled Binary**: Fast startup and low memory footprint

## Troubleshooting

### Database Connection Issues

```bash
# Test PostgreSQL connection
psql -h localhost -U postgres -d nexusforge_go

# Check connection string
echo $DATABASE_URL
```

### Redis Connection Issues

```bash
# Test Redis connection
redis-cli -h localhost -p 6379 ping
```

### Build Issues

```bash
# Clean and rebuild
make clean
make build

# Update dependencies
go mod tidy
go mod download
```

## Contributing

1. Follow Go best practices and idioms
2. Write tests for new features
3. Run `make lint` before committing
4. Update documentation

## License

MIT

## Support

For issues and questions:
- GitHub Issues: [nexusforge-platform/issues](https://github.com/yourusername/nexusforge-platform/issues)
- Documentation: [docs/](../../docs/)
