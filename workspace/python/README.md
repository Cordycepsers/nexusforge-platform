# NexusForge Python Service

Production-ready FastAPI microservice for the NexusForge Platform with complete authentication, database management, caching, and monitoring capabilities.

## Features

✨ **FastAPI Framework** - Modern, fast, and async Python web framework
🔐 **JWT Authentication** - Secure token-based authentication
🗄️ **PostgreSQL Database** - SQLAlchemy ORM with async support
⚡ **Redis Caching** - High-performance caching layer
📊 **Prometheus Metrics** - Built-in monitoring and metrics
📝 **Structured Logging** - JSON-formatted logs with structlog
🧪 **Comprehensive Tests** - Unit and integration tests with pytest
🔄 **Database Migrations** - Alembic for schema management
📖 **OpenAPI Documentation** - Auto-generated API docs
🛡️ **Security Best Practices** - Rate limiting, CORS, input validation

## Quick Start

### Prerequisites

- Python 3.9+
- PostgreSQL 14+
- Redis 6+
- Docker (optional)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/your-org/nexusforge-platform.git
cd nexusforge-platform/workspace/python
```

2. **Create virtual environment**
```bash
python3.9 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies**
```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt  # For development
```

4. **Set up environment variables**
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. **Run database migrations**
```bash
alembic upgrade head
```

6. **Start the application**
```bash
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`

## Project Structure

```
workspace/python/
├── app/
│   ├── __init__.py           # Application package
│   ├── main.py               # FastAPI application & startup
│   ├── config.py             # Configuration management
│   ├── models/               # SQLAlchemy models
│   │   ├── base.py          # Base model & mixins
│   │   └── user.py          # User model
│   ├── routes/               # API routes
│   │   ├── health.py        # Health check endpoints
│   │   └── api.py           # User API endpoints
│   ├── schemas/              # Pydantic schemas
│   │   └── user.py          # User schemas
│   ├── services/             # Business logic
│   │   └── user_service.py  # User service
│   ├── middleware/           # Custom middleware
│   │   └── rate_limit.py    # Rate limiting
│   └── utils/                # Utility modules
│       ├── database.py      # Database connection
│       ├── cache.py         # Redis cache manager
│       ├── auth.py          # JWT authentication
│       ├── security.py      # Password hashing
│       └── logger.py        # Structured logging
├── tests/                    # Test suite
│   ├── conftest.py          # Test fixtures
│   ├── test_health.py       # Health check tests
│   ├── unit/                # Unit tests
│   └── integration/         # Integration tests
├── alembic/                  # Database migrations
│   ├── versions/            # Migration scripts
│   └── env.py               # Alembic environment
├── requirements.txt          # Production dependencies
├── requirements-dev.txt      # Development dependencies
├── pytest.ini               # Pytest configuration
├── alembic.ini              # Alembic configuration
├── pyproject.toml           # Python project config
└── .pylintrc                # Pylint configuration
```

## API Endpoints

### Health Checks

- `GET /health` - Basic health check
- `GET /health/ready` - Readiness probe (checks dependencies)
- `GET /health/live` - Liveness probe

### User Management

- `POST /api/v1/users` - Create new user
- `GET /api/v1/users` - List users (requires auth)
- `GET /api/v1/users/{id}` - Get user by ID (requires auth)
- `PUT /api/v1/users/{id}` - Update user (requires auth)
- `DELETE /api/v1/users/{id}` - Delete user (requires auth)
- `GET /api/v1/users/me` - Get current user (requires auth)

### Documentation

- `GET /docs` - Swagger UI (disabled in production)
- `GET /redoc` - ReDoc documentation (disabled in production)
- `GET /metrics` - Prometheus metrics

## Development

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_health.py

# Run specific test
pytest tests/unit/test_user_service.py::test_create_user
```

### Code Quality

```bash
# Format code
black app/ tests/
isort app/ tests/

# Lint code
pylint app/
flake8 app/

# Type checking
mypy app/

# Security scanning
bandit -r app/
safety check
```

### Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "Description"

# Apply migrations
alembic upgrade head

# Rollback migration
alembic downgrade -1

# Show migration history
alembic history

# Show current revision
alembic current
```

## Configuration

All configuration is managed through environment variables. See `.env.example` for available options.

### Key Configuration Options

- **APP_NAME** - Application name
- **ENVIRONMENT** - Environment (development, staging, production)
- **DATABASE_URL** - PostgreSQL connection string
- **REDIS_URL** - Redis connection string
- **JWT_SECRET_KEY** - Secret key for JWT tokens
- **CORS_ORIGINS** - Allowed CORS origins
- **LOG_LEVEL** - Logging level (DEBUG, INFO, WARNING, ERROR)

## Deployment

### Using Docker

```bash
# Build image
docker build -f config/docker/Dockerfile.python -t nexusforge-python:latest .

# Run container
docker run -p 8000:8000 --env-file .env nexusforge-python:latest
```

### Using Docker Compose

```bash
cd ../..
docker-compose -f config/docker/docker-compose-all-in-one.yml up -d python-service
```

### Production Considerations

1. **Use environment variables** for all configuration
2. **Enable HTTPS** with proper certificates
3. **Set up monitoring** with Prometheus/Grafana
4. **Configure log aggregation** (e.g., ELK stack)
5. **Set up automated backups** for database
6. **Use connection pooling** for database
7. **Enable rate limiting** to prevent abuse
8. **Run multiple workers** for high availability

## Monitoring

### Metrics

Prometheus metrics are exposed at `/metrics`:

- HTTP request count and duration
- Database connection pool stats
- Redis connection stats
- Custom business metrics

### Logging

All logs are structured JSON format:

```json
{
  "timestamp": "2024-01-01T00:00:00.000Z",
  "level": "INFO",
  "logger": "app.main",
  "message": "Application startup",
  "environment": "production"
}
```

## Security

- **JWT authentication** for API endpoints
- **Password hashing** with bcrypt
- **Rate limiting** to prevent abuse
- **CORS protection** with configurable origins
- **Input validation** with Pydantic
- **SQL injection protection** with SQLAlchemy ORM
- **Secrets management** via environment variables

## Performance

- **Async/await** throughout for non-blocking I/O
- **Redis caching** for frequently accessed data
- **Database connection pooling** for efficient resource usage
- **Response compression** with gzip
- **Optimized queries** with proper indexing

## Troubleshooting

### Common Issues

1. **Database connection fails**
   - Check `DATABASE_URL` in `.env`
   - Ensure PostgreSQL is running
   - Verify network connectivity

2. **Redis connection fails**
   - Check `REDIS_URL` in `.env`
   - Ensure Redis is running
   - Verify authentication credentials

3. **Import errors**
   - Ensure virtual environment is activated
   - Run `pip install -r requirements.txt`

4. **Migration errors**
   - Check database permissions
   - Verify Alembic configuration
   - Review migration history with `alembic history`

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
- GitHub Issues: https://github.com/your-org/nexusforge-platform/issues
- Documentation: https://docs.nexusforge.dev
- Email: team@nexusforge.dev
