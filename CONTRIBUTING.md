# Contributing Guidelines

Thank you for considering contributing to the NexusForge Platform! This document provides guidelines and instructions for contributing.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Commit Guidelines](#commit-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Testing Requirements](#testing-requirements)
8. [Documentation](#documentation)
9. [Community](#community)

## Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [conduct@nexusforge.example.com](mailto:conduct@nexusforge.example.com).

## Getting Started

### Prerequisites

- Git
- Docker & Docker Compose
- Python 3.9+ / Node.js 16+ / Go 1.18+ (depending on what you're working on)
- GCP account (for deployment testing)
- GitHub account

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR_USERNAME/nexusforge-platform.git
cd nexusforge-platform
```

3. Add upstream remote:

```bash
git remote add upstream https://github.com/ORIGINAL_OWNER/nexusforge-platform.git
```

4. Set up development environment:

```bash
# Python
cd workspace/python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Node.js
cd workspace/nodejs
npm install

# Go
cd workspace/go
go mod download
```

### Running Locally

```bash
# Start all services with Docker Compose
docker-compose -f config/docker/docker-compose-all-in-one.yml up -d

# Or run individual services
cd workspace/python && uvicorn app.main:app --reload
cd workspace/nodejs && npm run dev
cd workspace/go && go run cmd/api/main.go
```

## Development Workflow

### 1. Create an Issue

Before starting work:

1. Check if an issue already exists
2. Create a new issue describing the bug/feature
3. Wait for discussion and approval (for major changes)

### 2. Create a Branch

```bash
# Update your fork
git checkout main
git fetch upstream
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/issue-description
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation only
- `refactor/` - Code refactoring
- `test/` - Test improvements
- `chore/` - Maintenance tasks

### 3. Make Changes

- Write code following our [coding standards](#coding-standards)
- Add tests for new functionality
- Update documentation as needed
- Keep commits atomic and well-described

### 4. Test Your Changes

```bash
# Python
cd workspace/python
pytest
pytest --cov=app --cov-report=html
pylint app/
black app/
isort app/

# Node.js
cd workspace/nodejs
npm test
npm run lint
npm run format

# Go
cd workspace/go
go test ./...
go test -cover ./...
golangci-lint run
go fmt ./...
```

### 5. Commit Changes

Follow [conventional commits](#commit-guidelines):

```bash
git add .
git commit -m "feat(api): add user profile endpoint"
```

### 6. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

## Coding Standards

### General Principles

- **DRY** (Don't Repeat Yourself)
- **KISS** (Keep It Simple, Stupid)
- **YAGNI** (You Aren't Gonna Need It)
- **SOLID** principles
- Write self-documenting code
- Add comments for complex logic

### Python Style Guide

Follow [PEP 8](https://peps.python.org/pep-0008/) and use these tools:

```bash
# Format code
black app/

# Sort imports
isort app/

# Lint code
pylint app/

# Type checking
mypy app/
```

**Example:**

```python
"""
User service module.

This module provides functionality for managing user accounts.
"""

from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User, UserCreate


class UserService:
    """Service for managing user operations."""
    
    @staticmethod
    async def create_user(
        db: AsyncSession,
        user_data: UserCreate
    ) -> User:
        """
        Create a new user.
        
        Args:
            db: Database session
            user_data: User creation data
            
        Returns:
            Created user instance
            
        Raises:
            ValueError: If email already exists
        """
        # Check if user exists
        existing_user = await UserService.get_by_email(db, user_data.email)
        if existing_user:
            raise ValueError("Email already registered")
        
        # Create user
        user = User(**user_data.dict())
        db.add(user)
        await db.commit()
        await db.refresh(user)
        
        return user
```

### Node.js/TypeScript Style Guide

Follow [Airbnb Style Guide](https://github.com/airbnb/javascript) and use these tools:

```bash
# Lint
npm run lint

# Format
npm run format

# Type check
npm run type-check
```

**Example:**

```typescript
/**
 * User service for managing user operations.
 */

import { PrismaClient, User } from '@prisma/client';
import { CreateUserInput } from '../validators/user.validator';

const prisma = new PrismaClient();

export class UserService {
  /**
   * Create a new user.
   * 
   * @param data - User creation data
   * @returns Created user
   * @throws Error if email already exists
   */
  static async createUser(data: CreateUserInput): Promise<User> {
    // Check if user exists
    const existingUser = await prisma.user.findUnique({
      where: { email: data.email },
    });
    
    if (existingUser) {
      throw new Error('Email already registered');
    }
    
    // Create user
    return prisma.user.create({
      data,
    });
  }
}
```

### Go Style Guide

Follow [Effective Go](https://go.dev/doc/effective_go) and [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments):

```bash
# Format
go fmt ./...

# Lint
golangci-lint run

# Vet
go vet ./...
```

**Example:**

```go
// Package services provides business logic for the application.
package services

import (
    "errors"
    "gorm.io/gorm"
    "nexusforge-go/internal/models"
)

// UserService handles user-related operations.
type UserService struct {
    db *gorm.DB
}

// NewUserService creates a new UserService instance.
func NewUserService(db *gorm.DB) *UserService {
    return &UserService{db: db}
}

// CreateUser creates a new user in the database.
// Returns an error if the email already exists.
func (s *UserService) CreateUser(data *models.CreateUserInput) (*models.User, error) {
    // Check if user exists
    var existingUser models.User
    if err := s.db.Where("email = ?", data.Email).First(&existingUser).Error; err == nil {
        return nil, errors.New("email already registered")
    }
    
    // Create user
    user := &models.User{
        Email:    data.Email,
        Username: data.Username,
    }
    
    if err := s.db.Create(user).Error; err != nil {
        return nil, err
    }
    
    return user, nil
}
```

### Database Migrations

**Python (Alembic):**

```bash
# Create migration
alembic revision --autogenerate -m "Add user profile fields"

# Review generated migration
vim alembic/versions/xxx_add_user_profile_fields.py

# Test migration
alembic upgrade head
alembic downgrade -1
```

**Node.js (Prisma):**

```bash
# Update schema
vim prisma/schema.prisma

# Create migration
npx prisma migrate dev --name add_user_profile_fields

# Review migration
cat prisma/migrations/xxx_add_user_profile_fields/migration.sql
```

**Go (golang-migrate):**

```bash
# Create migration
migrate create -ext sql -dir migrations -seq add_user_profile_fields

# Write up migration
vim migrations/000002_add_user_profile_fields.up.sql

# Write down migration
vim migrations/000002_add_user_profile_fields.down.sql
```

## Commit Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes
- `build`: Build system changes

### Scopes

- `api`: API changes
- `auth`: Authentication
- `db`: Database
- `docker`: Docker configuration
- `ci`: CI/CD
- `docs`: Documentation
- `config`: Configuration
- `deps`: Dependencies

### Examples

```bash
# Feature
git commit -m "feat(api): add user profile endpoint"

# Bug fix
git commit -m "fix(auth): resolve JWT token expiration issue"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Breaking change
git commit -m "feat(api)!: change user endpoint response format

BREAKING CHANGE: User endpoint now returns array instead of object"

# Multiple changes
git commit -m "feat(api): add pagination support

- Add limit and offset query parameters
- Update response format to include metadata
- Add tests for pagination"
```

## Pull Request Process

### Before Submitting

1. ✅ All tests pass
2. ✅ Code follows style guidelines
3. ✅ Documentation updated
4. ✅ No merge conflicts with main
5. ✅ Commits follow conventional commit format
6. ✅ PR description is clear and complete

### PR Template

```markdown
## Description

Brief description of changes.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Related Issues

Fixes #123
Related to #456

## Changes Made

- Added user profile endpoint
- Updated database schema
- Added unit tests

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

### Test Instructions

1. Start the service
2. Call POST /api/users/profile
3. Verify response format

## Screenshots (if applicable)

[Add screenshots here]

## Checklist

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published
```

### Review Process

1. Create PR with clear description
2. Wait for automated checks to pass
3. Request review from maintainers
4. Address review comments
5. Get approval from at least 1 maintainer
6. Maintainer merges PR

### After Merge

1. Delete your feature branch
2. Update your fork:

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

## Testing Requirements

### Unit Tests

Test individual functions/methods:

```python
# Python
def test_create_user():
    user_data = UserCreate(email="test@example.com", username="test")
    user = UserService.create_user(db, user_data)
    assert user.email == "test@example.com"
```

### Integration Tests

Test API endpoints:

```python
# Python
def test_create_user_endpoint(client):
    response = client.post(
        "/api/users",
        json={"email": "test@example.com", "username": "test", "password": "pass"}
    )
    assert response.status_code == 201
    assert response.json()["email"] == "test@example.com"
```

### E2E Tests

Test complete workflows:

```javascript
// Cypress
describe('User Registration', () => {
  it('should register new user', () => {
    cy.visit('/register');
    cy.get('#email').type('test@example.com');
    cy.get('#password').type('SecurePass123!');
    cy.get('button[type=submit]').click();
    cy.url().should('include', '/dashboard');
  });
});
```

### Coverage Requirements

- Minimum 80% code coverage
- All new features must have tests
- Bug fixes must include regression tests

```bash
# Check coverage
pytest --cov=app --cov-report=term-missing --cov-fail-under=80
```

## Documentation

### Code Documentation

- Add docstrings to all public functions/classes
- Use type hints (Python, TypeScript)
- Comment complex logic

### README Updates

Update README.md when:
- Adding new features
- Changing setup process
- Updating dependencies

### API Documentation

Update API docs for:
- New endpoints
- Changed request/response formats
- New authentication requirements

### Examples

Provide examples for:
- New features
- Complex usage patterns
- Common use cases

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Discord**: Real-time chat (link TBD)
- **Email**: [dev@nexusforge.example.com](mailto:dev@nexusforge.example.com)

### Getting Help

1. Check existing documentation
2. Search GitHub Issues
3. Ask in GitHub Discussions
4. Join our Discord server

### Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- GitHub contributors page
- Release notes
- Annual contributor spotlight

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to NexusForge Platform! 🎉

[← Back to README](../README.md)
