# Development Guide

Complete guide for developing services on the NexusForge Platform.

## Table of Contents

1. [Development Environment](#development-environment)
2. [Local Development Workflow](#local-development-workflow)
3. [Python Service Development](#python-service-development)
4. [Node.js Service Development](#nodejs-service-development)
5. [Go Service Development](#go-service-development)
6. [API Development](#api-development)
7. [Database Management](#database-management)
8. [Testing](#testing)
9. [Debugging](#debugging)
10. [Best Practices](#best-practices)

## Development Environment

### VS Code Setup

The project includes VS Code configurations for optimal development experience.

#### Recommended Extensions

```bash
# Install recommended extensions
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension golang.go
code --install-extension ms-azuretools.vscode-docker
code --install-extension mtxr.sqltools
code --install-extension mtxr.sqltools-driver-pg
```

#### Workspace Settings

Open the workspace in VS Code:

```bash
code nexusforge-platform.code-workspace
```

The workspace includes:
- Python path configuration
- Node.js debugging
- Go debugging
- Integrated terminal settings
- Code formatting on save

### Environment Variables

Each service requires environment variables. Use `.env` files:

```bash
# Copy example files
cp workspace/python/.env.example workspace/python/.env
cp workspace/nodejs/.env.example workspace/nodejs/.env
cp workspace/go/.env.example workspace/go/.env

# Edit with your values
vim workspace/python/.env
```

### Docker Compose Development

Start all services with hot reload:

```bash
# Start all services
docker-compose -f config/docker/docker-compose-all-in-one.yml up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

Services available:
- Python API: http://localhost:8000
- Node.js API: http://localhost:3000
- Go API: http://localhost:8080
- PostgreSQL: localhost:5432
- Redis: localhost:6379
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001

## Local Development Workflow

### 1. Feature Development

```bash
# Create feature branch
git checkout -b feature/user-authentication

# Make changes
# Run tests frequently
# Commit with conventional commits

git add .
git commit -m "feat(auth): add JWT authentication"
git push origin feature/user-authentication
```

### 2. Testing Locally

```bash
# Run service-specific tests
cd workspace/python && pytest
cd workspace/nodejs && npm test
cd workspace/go && go test ./...

# Run integration tests
cd tests/e2e && npm run test:integration
```

### 3. Code Quality

```bash
# Python
cd workspace/python
pylint app/
black app/
isort app/

# Node.js
cd workspace/nodejs
npm run lint
npm run format

# Go
cd workspace/go
golangci-lint run
go fmt ./...
```

## Python Service Development

### Project Structure

```
workspace/python/
├── app/
│   ├── main.py              # Application entry
│   ├── config.py            # Configuration
│   ├── models/              # SQLAlchemy models
│   ├── routes/              # API routes
│   ├── services/            # Business logic
│   └── utils/               # Utilities
├── tests/                   # Tests
├── alembic/                 # Database migrations
├── requirements.txt         # Dependencies
└── pytest.ini              # Test configuration
```

### Setting Up Development Environment

```bash
cd workspace/python

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Set up pre-commit hooks
pre-commit install
```

### Running the Service

```bash
# Development with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# With custom config
export ENV=development
uvicorn app.main:app --reload

# Run with Gunicorn (production-like)
gunicorn app.main:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000
```

### Adding a New Endpoint

#### 1. Create Model (if needed)

```python
# app/models/product.py
from sqlalchemy import Column, String, Integer, Float
from app.utils.database import Base

class Product(Base):
    __tablename__ = "products"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String)
    price = Column(Float, nullable=False)
    
    def __repr__(self):
        return f"<Product {self.name}>"
```

#### 2. Create Pydantic Schemas

```python
# app/models/product.py (continued)
from pydantic import BaseModel, Field

class ProductBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: str | None = None
    price: float = Field(..., gt=0)

class ProductCreate(ProductBase):
    pass

class ProductResponse(ProductBase):
    id: int
    
    class Config:
        from_attributes = True
```

#### 3. Create Service

```python
# app/services/product_service.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.product import Product, ProductCreate

class ProductService:
    @staticmethod
    async def create_product(
        db: AsyncSession,
        product_data: ProductCreate
    ) -> Product:
        product = Product(**product_data.dict())
        db.add(product)
        await db.commit()
        await db.refresh(product)
        return product
    
    @staticmethod
    async def get_products(
        db: AsyncSession,
        skip: int = 0,
        limit: int = 100
    ) -> list[Product]:
        result = await db.execute(
            select(Product).offset(skip).limit(limit)
        )
        return result.scalars().all()
```

#### 4. Create Route

```python
# app/routes/products.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.product import ProductCreate, ProductResponse
from app.services.product_service import ProductService
from app.utils.database import get_db

router = APIRouter(prefix="/api/products", tags=["products"])

@router.post("/", response_model=ProductResponse, status_code=201)
async def create_product(
    product: ProductCreate,
    db: AsyncSession = Depends(get_db)
):
    """Create a new product."""
    return await ProductService.create_product(db, product)

@router.get("/", response_model=list[ProductResponse])
async def list_products(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """List all products."""
    return await ProductService.get_products(db, skip, limit)
```

#### 5. Register Route

```python
# app/main.py
from app.routes import products

app.include_router(products.router)
```

### Database Migrations

```bash
# Create migration
alembic revision --autogenerate -m "Add products table"

# Apply migration
alembic upgrade head

# Rollback migration
alembic downgrade -1

# View migration history
alembic history
```

### Testing

```python
# tests/unit/test_product_service.py
import pytest
from app.services.product_service import ProductService
from app.models.product import ProductCreate

@pytest.mark.asyncio
async def test_create_product(db_session):
    product_data = ProductCreate(
        name="Test Product",
        description="A test product",
        price=99.99
    )
    
    product = await ProductService.create_product(
        db_session,
        product_data
    )
    
    assert product.id is not None
    assert product.name == "Test Product"
    assert product.price == 99.99
```

## Node.js Service Development

### Project Structure

```
workspace/nodejs/
├── src/
│   ├── index.ts             # Application entry
│   ├── config/              # Configuration
│   ├── controllers/         # Controllers
│   ├── models/              # Prisma models
│   ├── routes/              # Routes
│   ├── services/            # Business logic
│   ├── middleware/          # Middleware
│   └── utils/               # Utilities
├── tests/                   # Tests
├── prisma/                  # Prisma schema
└── package.json            # Dependencies
```

### Setting Up Development Environment

```bash
cd workspace/nodejs

# Install dependencies
npm install

# Generate Prisma Client
npx prisma generate

# Set up database
npx prisma migrate dev
```

### Running the Service

```bash
# Development with auto-reload
npm run dev

# Production build
npm run build
npm start

# Watch mode with nodemon
npm run dev:watch
```

### Adding a New Endpoint

#### 1. Update Prisma Schema

```prisma
// prisma/schema.prisma
model Product {
  id          Int      @id @default(autoincrement())
  name        String
  description String?
  price       Float
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  @@map("products")
}
```

```bash
# Generate migration
npx prisma migrate dev --name add_products

# Generate Prisma Client
npx prisma generate
```

#### 2. Create Validation Schema

```typescript
// src/validators/product.validator.ts
import { z } from 'zod';

export const createProductSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(100),
    description: z.string().optional(),
    price: z.number().positive(),
  }),
});

export type CreateProductInput = z.infer<typeof createProductSchema>['body'];
```

#### 3. Create Service

```typescript
// src/services/product.service.ts
import { PrismaClient } from '@prisma/client';
import { CreateProductInput } from '../validators/product.validator';

const prisma = new PrismaClient();

export class ProductService {
  static async createProduct(data: CreateProductInput) {
    return prisma.product.create({
      data,
    });
  }
  
  static async getProducts(skip = 0, take = 100) {
    return prisma.product.findMany({
      skip,
      take,
      orderBy: { createdAt: 'desc' },
    });
  }
  
  static async getProduct(id: number) {
    return prisma.product.findUnique({
      where: { id },
    });
  }
}
```

#### 4. Create Controller

```typescript
// src/controllers/product.controller.ts
import { Request, Response, NextFunction } from 'express';
import { ProductService } from '../services/product.service';
import { CreateProductInput } from '../validators/product.validator';

export class ProductController {
  static async create(
    req: Request<{}, {}, CreateProductInput>,
    res: Response,
    next: NextFunction
  ) {
    try {
      const product = await ProductService.createProduct(req.body);
      res.status(201).json(product);
    } catch (error) {
      next(error);
    }
  }
  
  static async list(req: Request, res: Response, next: NextFunction) {
    try {
      const skip = parseInt(req.query.skip as string) || 0;
      const take = parseInt(req.query.take as string) || 100;
      
      const products = await ProductService.getProducts(skip, take);
      res.json(products);
    } catch (error) {
      next(error);
    }
  }
}
```

#### 5. Create Routes

```typescript
// src/routes/product.routes.ts
import { Router } from 'express';
import { ProductController } from '../controllers/product.controller';
import { validate } from '../middleware/validate.middleware';
import { createProductSchema } from '../validators/product.validator';

const router = Router();

router.post(
  '/',
  validate(createProductSchema),
  ProductController.create
);

router.get('/', ProductController.list);

export default router;
```

#### 6. Register Routes

```typescript
// src/routes/index.ts
import productRoutes from './product.routes';

router.use('/api/products', productRoutes);
```

### Testing

```typescript
// tests/unit/product.service.spec.ts
import { ProductService } from '../../src/services/product.service';

describe('ProductService', () => {
  describe('createProduct', () => {
    it('should create a product', async () => {
      const productData = {
        name: 'Test Product',
        description: 'A test product',
        price: 99.99,
      };
      
      const product = await ProductService.createProduct(productData);
      
      expect(product).toBeDefined();
      expect(product.name).toBe('Test Product');
      expect(product.price).toBe(99.99);
    });
  });
});
```

## Go Service Development

### Project Structure

```
workspace/go/
├── cmd/
│   └── api/
│       └── main.go          # Application entry
├── internal/
│   ├── config/              # Configuration
│   ├── handlers/            # HTTP handlers
│   ├── models/              # Data models
│   ├── services/            # Business logic
│   ├── repository/          # Data access
│   └── middleware/          # Middleware
├── pkg/                     # Public packages
├── tests/                   # Tests
└── go.mod                   # Dependencies
```

### Setting Up Development Environment

```bash
cd workspace/go

# Download dependencies
go mod download

# Install development tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

### Running the Service

```bash
# Run directly
go run cmd/api/main.go

# Build and run
go build -o bin/api cmd/api/main.go
./bin/api

# With live reload (using air)
go install github.com/cosmtrek/air@latest
air
```

### Adding a New Endpoint

#### 1. Create Model

```go
// internal/models/product.go
package models

import "time"

type Product struct {
    ID          uint      `gorm:"primaryKey" json:"id"`
    Name        string    `gorm:"not null" json:"name" binding:"required,min=1,max=100"`
    Description string    `json:"description"`
    Price       float64   `gorm:"not null" json:"price" binding:"required,gt=0"`
    CreatedAt   time.Time `json:"created_at"`
    UpdatedAt   time.Time `json:"updated_at"`
}

type CreateProductInput struct {
    Name        string  `json:"name" binding:"required,min=1,max=100"`
    Description string  `json:"description"`
    Price       float64 `json:"price" binding:"required,gt=0"`
}
```

#### 2. Create Repository

```go
// internal/repository/product_repository.go
package repository

import (
    "gorm.io/gorm"
    "nexusforge-go/internal/models"
)

type ProductRepository struct {
    db *gorm.DB
}

func NewProductRepository(db *gorm.DB) *ProductRepository {
    return &ProductRepository{db: db}
}

func (r *ProductRepository) Create(product *models.Product) error {
    return r.db.Create(product).Error
}

func (r *ProductRepository) FindAll(offset, limit int) ([]models.Product, error) {
    var products []models.Product
    err := r.db.Offset(offset).Limit(limit).Find(&products).Error
    return products, err
}

func (r *ProductRepository) FindByID(id uint) (*models.Product, error) {
    var product models.Product
    err := r.db.First(&product, id).Error
    return &product, err
}
```

#### 3. Create Service

```go
// internal/services/product_service.go
package services

import (
    "nexusforge-go/internal/models"
    "nexusforge-go/internal/repository"
)

type ProductService struct {
    repo *repository.ProductRepository
}

func NewProductService(repo *repository.ProductRepository) *ProductService {
    return &ProductService{repo: repo}
}

func (s *ProductService) CreateProduct(input *models.CreateProductInput) (*models.Product, error) {
    product := &models.Product{
        Name:        input.Name,
        Description: input.Description,
        Price:       input.Price,
    }
    
    err := s.repo.Create(product)
    return product, err
}

func (s *ProductService) GetProducts(offset, limit int) ([]models.Product, error) {
    return s.repo.FindAll(offset, limit)
}
```

#### 4. Create Handler

```go
// internal/handlers/product.go
package handlers

import (
    "net/http"
    "strconv"
    
    "github.com/gin-gonic/gin"
    "nexusforge-go/internal/models"
    "nexusforge-go/internal/services"
)

type ProductHandler struct {
    service *services.ProductService
}

func NewProductHandler(service *services.ProductService) *ProductHandler {
    return &ProductHandler{service: service}
}

func (h *ProductHandler) Create(c *gin.Context) {
    var input models.CreateProductInput
    
    if err := c.ShouldBindJSON(&input); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    
    product, err := h.service.CreateProduct(&input)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    
    c.JSON(http.StatusCreated, product)
}

func (h *ProductHandler) List(c *gin.Context) {
    offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
    limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
    
    products, err := h.service.GetProducts(offset, limit)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    
    c.JSON(http.StatusOK, products)
}
```

#### 5. Register Routes

```go
// cmd/api/main.go (in setupRoutes function)
func setupRoutes(r *gin.Engine, productHandler *handlers.ProductHandler) {
    api := r.Group("/api")
    {
        products := api.Group("/products")
        {
            products.POST("/", productHandler.Create)
            products.GET("/", productHandler.List)
        }
    }
}
```

### Database Migrations

```bash
# Create migration
migrate create -ext sql -dir migrations -seq create_products_table

# Apply migrations
migrate -path migrations -database "postgresql://user:pass@localhost/db" up

# Rollback migrations
migrate -path migrations -database "postgresql://user:pass@localhost/db" down 1
```

### Testing

```go
// tests/unit/product_service_test.go
package tests

import (
    "testing"
    
    "github.com/stretchr/testify/assert"
    "nexusforge-go/internal/models"
    "nexusforge-go/internal/services"
)

func TestCreateProduct(t *testing.T) {
    // Setup
    repo := setupTestRepository(t)
    service := services.NewProductService(repo)
    
    input := &models.CreateProductInput{
        Name:        "Test Product",
        Description: "A test product",
        Price:       99.99,
    }
    
    // Execute
    product, err := service.CreateProduct(input)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, product)
    assert.Equal(t, "Test Product", product.Name)
    assert.Equal(t, 99.99, product.Price)
}
```

## API Development

### RESTful API Design

Follow REST conventions:

```
GET    /api/resources       - List resources
POST   /api/resources       - Create resource
GET    /api/resources/:id   - Get resource
PUT    /api/resources/:id   - Update resource
DELETE /api/resources/:id   - Delete resource
```

### Response Format

Standard response format:

```json
{
  "data": {},
  "message": "Success",
  "timestamp": "2025-10-06T12:00:00Z"
}
```

Error response format:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  },
  "timestamp": "2025-10-06T12:00:00Z"
}
```

### API Versioning

Use URL versioning:

```
/api/v1/users
/api/v2/users
```

### Authentication

All services use JWT authentication:

```bash
# Get token
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password"
  }'

# Use token
curl http://localhost:8000/api/users \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Database Management

### Connecting to PostgreSQL

```bash
# Local connection
psql -h localhost -U postgres -d nexusforge

# Docker connection
docker exec -it postgres psql -U postgres -d nexusforge

# Cloud SQL connection
gcloud sql connect nexusforge-db --user=postgres
```

### Common Database Operations

```sql
-- Create database
CREATE DATABASE nexusforge_dev;

-- List tables
\dt

-- Describe table
\d users

-- View indexes
\di

-- Show table sizes
SELECT 
  relname as table_name,
  pg_size_pretty(pg_total_relation_size(relid)) as size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

### Database Backups

```bash
# Backup
pg_dump -h localhost -U postgres nexusforge > backup.sql

# Restore
psql -h localhost -U postgres nexusforge < backup.sql

# Backup with Docker
docker exec postgres pg_dump -U postgres nexusforge > backup.sql
```

## Testing

### Unit Tests

Test individual functions/methods in isolation.

### Integration Tests

Test API endpoints with database.

### E2E Tests

Test complete user workflows.

### Running Tests

```bash
# Python - all tests
cd workspace/python && pytest

# Python - with coverage
pytest --cov=app --cov-report=html

# Python - specific test
pytest tests/unit/test_user_service.py

# Node.js - all tests
cd workspace/nodejs && npm test

# Node.js - with coverage
npm run test:coverage

# Node.js - watch mode
npm run test:watch

# Go - all tests
cd workspace/go && go test ./...

# Go - with coverage
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Go - specific package
go test ./internal/services/...
```

## Debugging

### VS Code Debugging

Press F5 or use Debug panel with provided configurations.

### Python Debugging

```python
# Add breakpoint
import pdb; pdb.set_trace()

# Run with debugger
python -m pdb app/main.py
```

### Node.js Debugging

```bash
# Run with inspector
node --inspect src/index.ts

# Or use VS Code debugger (F5)
```

### Go Debugging

```bash
# Install delve
go install github.com/go-delve/delve/cmd/dlv@latest

# Run with debugger
dlv debug cmd/api/main.go

# Or use VS Code debugger (F5)
```

### Logging

All services use structured logging:

```python
# Python
logger.info("User created", extra={"user_id": user.id})

# Node.js
logger.info('User created', { userId: user.id });

# Go
log.WithFields(log.Fields{"user_id": user.ID}).Info("User created")
```

## Best Practices

### Code Style

- Follow language-specific style guides
- Use consistent naming conventions
- Write descriptive comments
- Keep functions small and focused

### Git Workflow

```bash
# Feature branch
git checkout -b feature/user-authentication

# Commit with conventional commits
git commit -m "feat(auth): add JWT authentication"
git commit -m "fix(user): resolve email validation bug"
git commit -m "docs(api): update endpoint documentation"

# Push and create PR
git push origin feature/user-authentication
```

### Environment Variables

- Never commit `.env` files
- Use `.env.example` for documentation
- Use Secret Manager in production

### Error Handling

- Always handle errors explicitly
- Return meaningful error messages
- Log errors with context
- Use appropriate HTTP status codes

### Performance

- Use database indexes
- Implement caching with Redis
- Use connection pooling
- Monitor query performance

---

[← Back to Setup](01-SETUP.md) | [Next: Deployment Guide →](03-DEPLOYMENT-GUIDE.md)
