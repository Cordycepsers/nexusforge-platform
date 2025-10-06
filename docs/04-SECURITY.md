# Security Guide

Comprehensive security practices and considerations for the NexusForge Platform.

## Table of Contents

1. [Security Overview](#security-overview)
2. [Authentication & Authorization](#authentication--authorization)
3. [Network Security](#network-security)
4. [Data Security](#data-security)
5. [Application Security](#application-security)
6. [Infrastructure Security](#infrastructure-security)
7. [Secret Management](#secret-management)
8. [Security Monitoring](#security-monitoring)
9. [Compliance](#compliance)
10. [Security Checklist](#security-checklist)

## Security Overview

### Security Principles

1. **Defense in Depth** - Multiple layers of security
2. **Least Privilege** - Minimum necessary permissions
3. **Zero Trust** - Verify everything, trust nothing
4. **Security by Default** - Secure defaults for all configurations
5. **Fail Secure** - Fail closed, not open

### Security Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Internet                             │
└──────────────────────┬──────────────────────────────────┘
                       │
              ┌────────▼─────────┐
              │  Cloud Armor     │  ← DDoS Protection, WAF
              │  (Layer 7)       │
              └────────┬─────────┘
                       │
              ┌────────▼─────────┐
              │  Cloud CDN       │  ← Caching, SSL
              └────────┬─────────┘
                       │
              ┌────────▼─────────┐
              │  Load Balancer   │  ← SSL Termination
              └────────┬─────────┘
                       │
              ┌────────▼─────────┐
              │  IAP (Identity   │  ← Authentication
              │  Aware Proxy)    │
              └────────┬─────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
   │Python   │   │Node.js  │   │Go       │
   │Service  │   │Service  │   │Service  │
   └────┬────┘   └────┬────┘   └────┬────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
              ┌────────▼─────────┐
              │  VPC Network     │  ← Private Network
              └────────┬─────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
   │Cloud SQL│   │Memorystore  │Secret   │
   │(Private)│   │Redis        │Manager  │
   └─────────┘   └─────────────┘└─────────┘
```

## Authentication & Authorization

### JWT Authentication

All services use JWT (JSON Web Tokens) for authentication.

#### Token Structure

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "user_id_123",
    "email": "user@example.com",
    "roles": ["user", "admin"],
    "iat": 1696598400,
    "exp": 1696684800
  },
  "signature": "..."
}
```

#### Implementing JWT in Services

**Python (FastAPI):**

```python
# app/utils/auth.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from datetime import datetime, timedelta
from app.config import settings

security = HTTPBearer()

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(hours=24))
    to_encode.update({"exp": expire})
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET,
        algorithm="HS256"
    )

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    try:
        token = credentials.credentials
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=["HS256"]
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )

# Usage in routes
@router.get("/api/protected")
async def protected_route(current_user = Depends(get_current_user)):
    return {"user": current_user}
```

**Node.js (Express):**

```typescript
// src/middleware/auth.middleware.ts
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

interface JwtPayload {
  sub: string;
  email: string;
  roles: string[];
}

export const authenticate = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const token = authHeader.substring(7);
  
  try {
    const payload = jwt.verify(
      token,
      process.env.JWT_SECRET!
    ) as JwtPayload;
    
    req.user = payload;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Usage in routes
router.get('/api/protected', authenticate, (req, res) => {
  res.json({ user: req.user });
});
```

**Go (Gin):**

```go
// internal/middleware/auth.go
package middleware

import (
    "net/http"
    "strings"
    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v4"
)

type Claims struct {
    UserID string   `json:"sub"`
    Email  string   `json:"email"`
    Roles  []string `json:"roles"`
    jwt.RegisteredClaims
}

func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        
        if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
            c.Abort()
            return
        }
        
        tokenString := strings.TrimPrefix(authHeader, "Bearer ")
        
        claims := &Claims{}
        token, err := jwt.ParseWithClaims(
            tokenString,
            claims,
            func(token *jwt.Token) (interface{}, error) {
                return []byte(jwtSecret), nil
            },
        )
        
        if err != nil || !token.Valid {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }
        
        c.Set("user", claims)
        c.Next()
    }
}

// Usage in routes
router.GET("/api/protected", middleware.AuthMiddleware(jwtSecret), handler)
```

### Role-Based Access Control (RBAC)

#### Define Roles

```yaml
# config/security/rbac-policies.yaml
roles:
  - name: admin
    permissions:
      - users:read
      - users:write
      - users:delete
      - products:read
      - products:write
      - products:delete
      - system:manage
  
  - name: user
    permissions:
      - users:read_own
      - users:write_own
      - products:read
  
  - name: guest
    permissions:
      - products:read
```

#### Implement RBAC Middleware

```python
# Python
from functools import wraps
from fastapi import HTTPException, status

def require_permission(permission: str):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, current_user=None, **kwargs):
            user_permissions = current_user.get("permissions", [])
            if permission not in user_permissions:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Insufficient permissions"
                )
            return await func(*args, current_user=current_user, **kwargs)
        return wrapper
    return decorator

@router.delete("/api/users/{user_id}")
@require_permission("users:delete")
async def delete_user(user_id: int, current_user = Depends(get_current_user)):
    # Delete user logic
    pass
```

### Identity-Aware Proxy (IAP)

Protect services with Google Cloud IAP:

```bash
# Enable IAP
gcloud iap web enable \
  --resource-type=backend-services \
  --service=nexusforge-backend

# Add IAP policy
gcloud iap web add-iam-policy-binding \
  --resource-type=backend-services \
  --service=nexusforge-backend \
  --member=user:admin@example.com \
  --role=roles/iap.httpsResourceAccessor

# Configure OAuth consent screen
gcloud iap oauth-brands create \
  --application_title="NexusForge Platform" \
  --support_email=support@example.com
```

## Network Security

### VPC Configuration

```bash
# Create VPC network
gcloud compute networks create nexusforge-vpc \
  --subnet-mode=custom

# Create subnet
gcloud compute networks subnets create nexusforge-subnet \
  --network=nexusforge-vpc \
  --region=us-central1 \
  --range=10.0.0.0/24 \
  --enable-private-ip-google-access

# Create firewall rules (deny all by default)
gcloud compute firewall-rules create nexusforge-allow-internal \
  --network=nexusforge-vpc \
  --allow=tcp,udp,icmp \
  --source-ranges=10.0.0.0/24

# Allow health checks
gcloud compute firewall-rules create nexusforge-allow-health-check \
  --network=nexusforge-vpc \
  --allow=tcp:80,tcp:443 \
  --source-ranges=130.211.0.0/22,35.191.0.0/16

# Deny all other traffic
gcloud compute firewall-rules create nexusforge-deny-all \
  --network=nexusforge-vpc \
  --action=deny \
  --rules=all \
  --priority=65534
```

### Cloud Armor (WAF)

```yaml
# config/security/cloud-armor-rules.yaml
name: nexusforge-security-policy
description: Security policy for NexusForge Platform

rules:
  # Block known bad IPs
  - priority: 1000
    action: deny(403)
    match:
      versionedExpr: SRC_IPS_V1
      config:
        srcIpRanges:
          - 192.0.2.0/24  # Example bad IP range
    description: "Block known malicious IPs"
  
  # Rate limiting
  - priority: 2000
    action: rate_based_ban
    match:
      versionedExpr: SRC_IPS_V1
      config:
        srcIpRanges:
          - "*"
    rateLimitOptions:
      conformAction: allow
      exceedAction: deny(429)
      enforceOnKey: IP
      rateLimitThreshold:
        count: 100
        intervalSec: 60
    description: "Rate limit: 100 requests per minute per IP"
  
  # Block SQL injection attempts
  - priority: 3000
    action: deny(403)
    match:
      expr:
        expression: >
          evaluatePreconfiguredExpr('sqli-stable')
    description: "Block SQL injection attempts"
  
  # Block XSS attempts
  - priority: 4000
    action: deny(403)
    match:
      expr:
        expression: >
          evaluatePreconfiguredExpr('xss-stable')
    description: "Block XSS attempts"
  
  # Geographic restrictions (example)
  - priority: 5000
    action: deny(403)
    match:
      expr:
        expression: >
          origin.region_code == "CN" || origin.region_code == "RU"
    description: "Block specific regions (if needed)"
  
  # Allow all other traffic
  - priority: 2147483647
    action: allow
    match:
      versionedExpr: SRC_IPS_V1
      config:
        srcIpRanges:
          - "*"
    description: "Default rule: allow"
```

Apply Cloud Armor policy:

```bash
# Create security policy
gcloud compute security-policies create nexusforge-security-policy \
  --description "Security policy for NexusForge"

# Add rules
gcloud compute security-policies rules create 1000 \
  --security-policy nexusforge-security-policy \
  --action deny-403 \
  --src-ip-ranges "192.0.2.0/24" \
  --description "Block malicious IPs"

# Add rate limiting
gcloud compute security-policies rules create 2000 \
  --security-policy nexusforge-security-policy \
  --action rate-based-ban \
  --rate-limit-threshold-count 100 \
  --rate-limit-threshold-interval-sec 60 \
  --conform-action allow \
  --exceed-action deny-429 \
  --enforce-on-key IP

# Attach to backend service
gcloud compute backend-services update nexusforge-backend \
  --security-policy nexusforge-security-policy \
  --global
```

### SSL/TLS Configuration

```bash
# Create managed SSL certificate
gcloud compute ssl-certificates create nexusforge-cert \
  --domains nexusforge.example.com,api.nexusforge.example.com \
  --global

# Or upload existing certificate
gcloud compute ssl-certificates create nexusforge-cert \
  --certificate cert.pem \
  --private-key key.pem \
  --global

# Enforce HTTPS redirect
gcloud compute url-maps create nexusforge-https-redirect \
  --default-service nexusforge-backend

gcloud compute target-http-proxies create nexusforge-http-proxy \
  --url-map nexusforge-https-redirect

gcloud compute forwarding-rules create nexusforge-http-forward \
  --global \
  --target-http-proxy nexusforge-http-proxy \
  --ports 80

# Configure TLS policy
gcloud compute ssl-policies create nexusforge-tls-policy \
  --profile MODERN \
  --min-tls-version 1.2

# Attach TLS policy
gcloud compute target-https-proxies update nexusforge-https-proxy \
  --ssl-policy nexusforge-tls-policy
```

## Data Security

### Database Security

#### Cloud SQL Security

```bash
# Enable Cloud SQL with private IP only
gcloud sql instances create nexusforge-db \
  --database-version=POSTGRES_14 \
  --tier=db-custom-2-7680 \
  --region=us-central1 \
  --network=projects/$PROJECT_ID/global/networks/nexusforge-vpc \
  --no-assign-ip \
  --database-flags=cloudsql.iam_authentication=on

# Create database user with IAM
gcloud sql users create service-account@project-id.iam \
  --instance=nexusforge-db \
  --type=CLOUD_IAM_SERVICE_ACCOUNT

# Enable SSL/TLS
gcloud sql ssl-certs create nexusforge-client-cert \
  --instance=nexusforge-db

# Enable automated backups
gcloud sql instances patch nexusforge-db \
  --backup-start-time=03:00 \
  --retained-backups-count=30

# Enable point-in-time recovery
gcloud sql instances patch nexusforge-db \
  --enable-point-in-time-recovery
```

#### Database Encryption

```python
# Encrypt sensitive fields at application level
from cryptography.fernet import Fernet
import os

class FieldEncryption:
    def __init__(self):
        self.key = os.getenv("FIELD_ENCRYPTION_KEY").encode()
        self.cipher = Fernet(self.key)
    
    def encrypt(self, value: str) -> str:
        return self.cipher.encrypt(value.encode()).decode()
    
    def decrypt(self, encrypted_value: str) -> str:
        return self.cipher.decrypt(encrypted_value.encode()).decode()

# Usage in SQLAlchemy model
from sqlalchemy import String, TypeDecorator

class EncryptedString(TypeDecorator):
    impl = String
    cache_ok = True
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.encryptor = FieldEncryption()
    
    def process_bind_param(self, value, dialect):
        if value is not None:
            return self.encryptor.encrypt(value)
        return value
    
    def process_result_value(self, value, dialect):
        if value is not None:
            return self.encryptor.decrypt(value)
        return value

# Model with encrypted field
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    email = Column(String, unique=True, nullable=False)
    ssn = Column(EncryptedString(255))  # Encrypted field
```

### Data Classification

Classify data by sensitivity:

| Level | Description | Examples | Protection |
|-------|-------------|----------|------------|
| **Public** | Non-sensitive | Product catalog | Standard |
| **Internal** | Business data | Analytics | Access control |
| **Confidential** | Sensitive | User emails | Encryption + RBAC |
| **Restricted** | Highly sensitive | SSN, credit cards | Strong encryption + strict RBAC |

### PII Protection

```python
# Anonymize PII in logs
import hashlib
import logging

class PIIFilter(logging.Filter):
    def filter(self, record):
        # Hash email addresses
        if hasattr(record, 'email'):
            record.email = hashlib.sha256(
                record.email.encode()
            ).hexdigest()[:16]
        return True

# Add filter to logger
logger = logging.getLogger(__name__)
logger.addFilter(PIIFilter())

# Usage
logger.info("User registered", extra={"email": "user@example.com"})
# Logs: "User registered email=a1b2c3d4e5f6g7h8"
```

## Application Security

### Input Validation

```python
# Python (Pydantic)
from pydantic import BaseModel, Field, EmailStr, validator
import re

class UserCreate(BaseModel):
    email: EmailStr  # Validates email format
    username: str = Field(..., min_length=3, max_length=50, regex="^[a-zA-Z0-9_-]+$")
    password: str = Field(..., min_length=12)
    
    @validator('password')
    def validate_password_strength(cls, v):
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain uppercase letter')
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain lowercase letter')
        if not re.search(r'\d', v):
            raise ValueError('Password must contain digit')
        if not re.search(r'[!@#$%^&*]', v):
            raise ValueError('Password must contain special character')
        return v
```

### SQL Injection Prevention

```python
# ✅ GOOD: Use parameterized queries
from sqlalchemy import select

# SQLAlchemy automatically parameterizes
result = await db.execute(
    select(User).where(User.email == user_input)
)

# ❌ BAD: String concatenation
# query = f"SELECT * FROM users WHERE email = '{user_input}'"  # VULNERABLE!
```

### XSS Prevention

```typescript
// Node.js - Sanitize HTML input
import DOMPurify from 'isomorphic-dompurify';

function sanitizeHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a'],
    ALLOWED_ATTR: ['href']
  });
}

// Usage
const userInput = req.body.comment;
const clean = sanitizeHtml(userInput);
```

### CSRF Protection

```python
# Python (FastAPI) - Use CSRF tokens
from fastapi_csrf_protect import CsrfProtect

@app.post("/api/users")
async def create_user(
    user: UserCreate,
    csrf_protect: CsrfProtect = Depends()
):
    await csrf_protect.validate_csrf(request)
    # Process request
```

### CORS Configuration

```python
# Python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://nexusforge.example.com",
        "https://app.nexusforge.example.com"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
    max_age=3600
)
```

## Infrastructure Security

### Workload Identity Federation

No service account keys - use Workload Identity:

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository_owner=='yourusername'"

# Grant service account permissions
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/yourusername/nexusforge-platform"
```

### Least Privilege IAM

```bash
# Create custom role with minimal permissions
gcloud iam roles create cloudRunDeployer \
  --project=$PROJECT_ID \
  --title="Cloud Run Deployer" \
  --description="Can deploy to Cloud Run only" \
  --permissions=run.services.create,run.services.update,run.services.get,run.services.list

# Assign to service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com \
  --role=projects/$PROJECT_ID/roles/cloudRunDeployer
```

### Container Security

```dockerfile
# Use minimal base images
FROM python:3.9-slim  # 150MB vs python:3.9 (900MB)

# Run as non-root user
RUN useradd -m -u 1001 appuser
USER appuser

# Copy only necessary files
COPY --chown=appuser:appuser requirements.txt .
COPY --chown=appuser:appuser app/ ./app/

# Scan for vulnerabilities
RUN pip install --no-cache-dir safety && \
    safety check --file requirements.txt
```

Scan images:

```bash
# Trivy scan
trivy image gcr.io/project/nexusforge-python:latest

# Snyk scan
snyk container test gcr.io/project/nexusforge-python:latest
```

## Secret Management

### Google Secret Manager

```bash
# Create secret
echo -n "my-secret-value" | \
  gcloud secrets create jwt-secret \
  --data-file=- \
  --replication-policy=automatic

# Grant access to service account
gcloud secrets add-iam-policy-binding jwt-secret \
  --member=serviceAccount:nexusforge@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor

# Use in Cloud Run
gcloud run deploy nexusforge-python \
  --set-secrets=JWT_SECRET=jwt-secret:latest
```

### Access Secrets in Code

```python
# Python
from google.cloud import secretmanager

def get_secret(secret_id: str, version: str = "latest") -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/{version}"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

# Usage
JWT_SECRET = get_secret("jwt-secret")
```

### Rotate Secrets

```bash
# Add new version
echo -n "new-secret-value" | \
  gcloud secrets versions add jwt-secret \
  --data-file=-

# Disable old version
gcloud secrets versions disable 1 \
  --secret=jwt-secret

# Destroy old version (after grace period)
gcloud secrets versions destroy 1 \
  --secret=jwt-secret
```

## Security Monitoring

### Audit Logging

```bash
# Enable audit logs
gcloud logging read "protoPayload.@type=type.googleapis.com/google.cloud.audit.AuditLog" \
  --limit 50 \
  --format json

# Monitor for suspicious activity
gcloud logging read \
  "protoPayload.authenticationInfo.principalEmail!~'@example.com$' AND severity>=WARNING" \
  --limit 50
```

### Security Command Center

```bash
# Enable Security Command Center
gcloud services enable securitycenter.googleapis.com

# View findings
gcloud scc findings list organizations/$ORG_ID \
  --filter="state=\"ACTIVE\""
```

### Vulnerability Scanning

```bash
# Enable Container Analysis
gcloud services enable containeranalysis.googleapis.com

# Scan on push (automatic with Artifact Registry)
docker push gcr.io/$PROJECT_ID/nexusforge-python:latest

# View vulnerabilities
gcloud artifacts docker images scan \
  gcr.io/$PROJECT_ID/nexusforge-python:latest
```

## Compliance

### GDPR Compliance

- **Right to Access**: Implement user data export
- **Right to Erasure**: Implement data deletion
- **Data Portability**: Export in machine-readable format
- **Privacy by Design**: Built-in privacy controls

```python
# Example: User data export (GDPR Article 20)
@router.get("/api/users/me/export")
async def export_user_data(current_user = Depends(get_current_user)):
    user_data = {
        "personal_info": await get_user_profile(current_user["sub"]),
        "activity": await get_user_activity(current_user["sub"]),
        "preferences": await get_user_preferences(current_user["sub"])
    }
    return user_data

# Example: User data deletion (GDPR Article 17)
@router.delete("/api/users/me")
async def delete_user_account(current_user = Depends(get_current_user)):
    await anonymize_user_data(current_user["sub"])
    await delete_user(current_user["sub"])
    return {"message": "Account deleted successfully"}
```

### SOC 2 Compliance

- **Security**: Access controls, encryption
- **Availability**: SLAs, monitoring, backups
- **Processing Integrity**: Data validation, error handling
- **Confidentiality**: Data classification, DLP
- **Privacy**: Privacy policies, consent management

## Security Checklist

### Pre-Deployment

- [ ] All secrets stored in Secret Manager
- [ ] No hardcoded credentials in code
- [ ] Input validation on all endpoints
- [ ] Output encoding to prevent XSS
- [ ] Parameterized queries to prevent SQL injection
- [ ] HTTPS enforced everywhere
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] Authentication required for sensitive endpoints
- [ ] RBAC implemented correctly

### Infrastructure

- [ ] VPC with private subnets
- [ ] Cloud Armor configured
- [ ] IAP enabled for admin access
- [ ] Firewall rules reviewed
- [ ] TLS 1.2+ enforced
- [ ] Cloud SQL with private IP only
- [ ] Database backups enabled
- [ ] Workload Identity Federation configured
- [ ] Least privilege IAM roles

### Monitoring

- [ ] Audit logging enabled
- [ ] Security alerts configured
- [ ] Vulnerability scanning enabled
- [ ] Log aggregation configured
- [ ] Incident response plan documented
- [ ] Security metrics dashboards

### Compliance

- [ ] Data classification completed
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Cookie consent (if applicable)
- [ ] Data retention policy defined
- [ ] Incident response plan
- [ ] Regular security audits scheduled

---

[← Back to Deployment Guide](03-DEPLOYMENT-GUIDE.md) | [Next: Troubleshooting →](05-TROUBLESHOOTING.md)
