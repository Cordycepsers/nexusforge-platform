# Node.js NexusForge Service

A production-ready Node.js/Express/TypeScript microservice for the NexusForge Platform.

## Features

- ✅ **Express + TypeScript** - Type-safe REST API
- ✅ **Prisma ORM** - Type-safe database access
- ✅ **Redis Caching** - Fast response times with intelligent caching
- ✅ **JWT Authentication** - Secure token-based auth
- ✅ **Zod Validation** - Runtime schema validation
- ✅ **Winston Logging** - Structured JSON logging
- ✅ **Prometheus Metrics** - Built-in metrics endpoint
- ✅ **Jest Testing** - Comprehensive unit and integration tests
- ✅ **Security Best Practices** - Helmet, rate limiting, CORS
- ✅ **Health Checks** - Kubernetes-ready health endpoints

## Prerequisites

- Node.js 16+ and npm
- PostgreSQL 14+
- Redis 6+

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Copy the example environment file:

```bash
cp .env.example .env
```

Update `.env` with your configuration:

```env
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://user:password@localhost:5432/nexusforge
REDIS_HOST=localhost
REDIS_PORT=6379
JWT_SECRET=your-secret-key-change-in-production
```

### 3. Setup Database

Generate Prisma Client:

```bash
npm run prisma:generate
```

Run migrations:

```bash
npm run migrate:dev
```

Seed database (optional):

```bash
npm run db:seed
```

### 4. Start Development Server

```bash
npm run dev
```

The API will be available at `http://localhost:3000`.

## Available Scripts

### Development

- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm start` - Start production server

### Database

- `npm run prisma:generate` - Generate Prisma Client
- `npm run migrate:dev` - Run database migrations (development)
- `npm run migrate:deploy` - Run database migrations (production)
- `npm run db:push` - Push schema changes without migrations
- `npm run db:seed` - Seed database with initial data
- `npm run db:studio` - Open Prisma Studio

### Testing

- `npm test` - Run all tests
- `npm run test:watch` - Run tests in watch mode
- `npm run test:coverage` - Run tests with coverage report
- `npm run test:unit` - Run unit tests only
- `npm run test:integration` - Run integration tests only

### Code Quality

- `npm run lint` - Run ESLint
- `npm run lint:fix` - Fix ESLint issues
- `npm run format` - Format code with Prettier
- `npm run type-check` - Run TypeScript type checking

## Project Structure

```
src/
├── config/           # Configuration management
├── controllers/      # Request handlers
├── dto/              # Data transfer objects (Zod schemas)
├── middleware/       # Express middleware
├── models/           # Type definitions
├── routes/           # API route definitions
├── services/         # Business logic layer
└── utils/            # Utility functions
    ├── auth.ts       # JWT utilities
    ├── cache.ts      # Redis cache manager
    ├── database.ts   # Prisma client
    ├── errors.ts     # Custom error classes
    ├── logger.ts     # Winston logger
    ├── metrics.ts    # Prometheus metrics
    └── security.ts   # Password hashing

tests/
├── unit/             # Unit tests
├── integration/      # Integration tests
└── setup.ts          # Test configuration

prisma/
├── schema.prisma     # Database schema
└── migrations/       # Migration files
```

## API Documentation

### Health Endpoints

- `GET /health` - Basic health check
- `GET /health/ready` - Readiness check (DB + Redis)
- `GET /health/live` - Liveness check

### User Endpoints

- `POST /api/users` - Create new user (public)
- `GET /api/users` - List users (authenticated)
- `GET /api/users/me` - Get current user (authenticated)
- `GET /api/users/:id` - Get user by ID (authenticated)
- `PUT /api/users/:id` - Update user (authenticated, own profile)
- `DELETE /api/users/:id` - Delete user (superuser only)

### Authentication

All protected endpoints require a JWT token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Example Requests

**Create User:**

```bash
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "johndoe",
    "password": "SecurePass123!"
  }'
```

**Get Current User:**

```bash
curl -X GET http://localhost:3000/api/users/me \
  -H "Authorization: Bearer <your-token>"
```

**Update User:**

```bash
curl -X PUT http://localhost:3000/api/users/123 \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newusername"
  }'
```

## Environment Variables

### Required

- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Secret key for JWT signing

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `development` | Environment (development/production/test) |
| `PORT` | `3000` | Server port |
| `REDIS_HOST` | `localhost` | Redis host |
| `REDIS_PORT` | `6379` | Redis port |
| `REDIS_PASSWORD` | - | Redis password |
| `REDIS_DB` | `0` | Redis database number |
| `JWT_EXPIRES_IN` | `24h` | JWT expiration time |
| `JWT_REFRESH_EXPIRES_IN` | `7d` | Refresh token expiration |
| `BCRYPT_ROUNDS` | `10` | Bcrypt hashing rounds |
| `LOG_LEVEL` | `info` | Logging level |
| `LOG_FORMAT` | `json` | Log format (json/text) |
| `RATE_LIMIT_WINDOW_MS` | `900000` | Rate limit window (15 min) |
| `RATE_LIMIT_MAX_REQUESTS` | `100` | Max requests per window |
| `ENABLE_CACHE` | `true` | Enable Redis caching |
| `ENABLE_METRICS` | `true` | Enable Prometheus metrics |

## Caching Strategy

The service implements intelligent caching:

- **User by ID**: 5 minute TTL
- **Cache Invalidation**: Automatic on updates/deletes
- **Cache Keys**: `user:{id}` pattern

## Security Features

- **Helmet**: Security headers
- **CORS**: Cross-origin resource sharing
- **Rate Limiting**: Prevent abuse
- **JWT Authentication**: Secure token-based auth
- **Password Hashing**: bcrypt with configurable rounds
- **Input Validation**: Zod schema validation
- **SQL Injection Protection**: Prisma ORM parameterized queries

## Monitoring

### Metrics Endpoint

Prometheus metrics available at `/metrics`:

```bash
curl http://localhost:3000/metrics
```

### Available Metrics

- `nexusforge_nodejs_http_request_duration_seconds` - Request duration histogram
- `nexusforge_nodejs_http_requests_total` - Total HTTP requests counter
- `nexusforge_nodejs_active_connections` - Active connections gauge
- Default Node.js metrics (memory, CPU, event loop, etc.)

### Logging

Structured JSON logs with Winston:

```json
{
  "timestamp": "2024-01-15 10:30:45",
  "level": "info",
  "message": "Request completed",
  "method": "GET",
  "path": "/api/users",
  "statusCode": 200,
  "duration": 45
}
```

## Testing

### Run All Tests

```bash
npm test
```

### Run with Coverage

```bash
npm run test:coverage
```

Coverage reports are generated in the `coverage/` directory.

### Test Structure

- **Unit Tests**: Test individual functions/classes in isolation
- **Integration Tests**: Test API endpoints end-to-end
- **Health Tests**: Verify health check endpoints

## Deployment

### Build for Production

```bash
npm run build
```

### Run Production Server

```bash
npm start
```

### Docker

Build Docker image:

```bash
docker build -f ../../config/docker/Dockerfile.node -t nexusforge-nodejs:latest .
```

Run container:

```bash
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/db \
  -e REDIS_HOST=redis \
  -e JWT_SECRET=your-secret \
  nexusforge-nodejs:latest
```

### GCP Cloud Run

Deploy to Cloud Run:

```bash
gcloud run deploy nexusforge-nodejs \
  --image gcr.io/PROJECT_ID/nexusforge-nodejs:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DATABASE_URL=... \
  --set-secrets JWT_SECRET=jwt-secret:latest
```

## Troubleshooting

### Database Connection Issues

```bash
# Test database connection
npm run db:studio

# Reset database
npm run migrate:reset
```

### Redis Connection Issues

```bash
# Test Redis connection
redis-cli -h localhost -p 6379 ping
```

### TypeScript Errors

```bash
# Regenerate Prisma Client
npm run prisma:generate

# Type check
npm run type-check
```

## Contributing

1. Follow TypeScript and ESLint rules
2. Write tests for new features
3. Update documentation
4. Use conventional commits

## License

MIT

## Support

For issues and questions:
- GitHub Issues: [nexusforge-platform/issues](https://github.com/yourusername/nexusforge-platform/issues)
- Documentation: [docs/](../../docs/)
