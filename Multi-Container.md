# Enhanced NexusForge Platform - Multi-Container Single Instance Option

I'll add a comprehensive multi-container setup option that allows running all services on a single VM instance. This is more cost-effective for smaller teams while maintaining full functionality.

---

## 📦 Part 8: Multi-Container Single Instance Setup

### 8.1 Enhanced Docker Compose Configuration

**File: `config/docker/docker-compose-all-in-one.yml`**

```yaml
version: '3.8'

services:
  # ============================================
  # Reverse Proxy / Load Balancer
  # ============================================
  nginx:
    image: nginx:alpine
    container_name: nexusforge-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx-all-in-one.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - nginx-cache:/var/cache/nginx
      - nginx-logs:/var/log/nginx
    depends_on:
      - python-app
      - nodejs-app
      - go-app
      - vscode-server
    networks:
      - nexusforge-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ============================================
  # VS Code Server
  # ============================================
  vscode-server:
    image: codercom/code-server:latest
    container_name: nexusforge-vscode
    environment:
      - PASSWORD=${VSCODE_PASSWORD:-nexusforge2024}
      - SUDO_PASSWORD=${VSCODE_PASSWORD:-nexusforge2024}
    volumes:
      - vscode-data:/home/coder
      - vscode-config:/home/coder/.config
      - ./workspace:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - nexusforge-network
    restart: unless-stopped
    user: "1000:1000"
    command: --bind-addr 0.0.0.0:8080 --auth password

  # ============================================
  # Python Application (FastAPI)
  # ============================================
  python-app:
    build:
      context: ../../
      dockerfile: config/docker/Dockerfile.python
    container_name: nexusforge-python
    environment:
      - ENVIRONMENT=${ENVIRONMENT:-development}
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD:-postgres}@postgres:5432/nexusforge_python
      - REDIS_URL=redis://redis:6379/0
      - LOG_LEVEL=info
    volumes:
      - ./workspace/python:/app
      - python-logs:/var/log/app
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - nexusforge-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  # ============================================
  # Node.js Application (Express)
  # ============================================
  nodejs-app:
    build:
      context: ../../
      dockerfile: config/docker/Dockerfile.node
    container_name: nexusforge-nodejs
    environment:
      - NODE_ENV=${NODE_ENV:-development}
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD:-postgres}@postgres:5432/nexusforge_nodejs
      - REDIS_URL=redis://redis:6379/1
      - PORT=3000
    volumes:
      - ./workspace/nodejs:/app
      - nodejs-logs:/var/log/app
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - nexusforge-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  # ============================================
  # Go Application
  # ============================================
  go-app:
    build:
      context: ../../
      dockerfile: config/docker/Dockerfile.go
    container_name: nexusforge-go
    environment:
      - ENVIRONMENT=${ENVIRONMENT:-development}
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD:-postgres}@postgres:5432/nexusforge_go
      - REDIS_URL=redis://redis:6379/2
      - PORT=8080
    volumes:
      - ./workspace/go:/app
      - go-logs:/var/log/app
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - nexusforge-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  # ============================================
  # PostgreSQL Database
  # ============================================
  postgres:
    image: postgres:14-alpine
    container_name: nexusforge-postgres
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
      - POSTGRES_MULTIPLE_DATABASES=nexusforge_python,nexusforge_nodejs,nexusforge_go
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./postgres/init-multiple-databases.sh:/docker-entrypoint-initdb.d/init-multiple-databases.sh:ro
      - postgres-backups:/backups
    ports:
      - "5432:5432"
    networks:
      - nexusforge-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 1G

  # ============================================
  # Redis Cache
  # ============================================
  redis:
    image: redis:7-alpine
    container_name: nexusforge-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-redis}
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
    networks:
      - nexusforge-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # ============================================
  # PgAdmin (Database Management)
  # ============================================
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: nexusforge-pgadmin
    environment:
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL:-admin@nexusforge.local}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD:-admin}
      - PGADMIN_CONFIG_SERVER_MODE=False
    volumes:
      - pgadmin-data:/var/lib/pgadmin
    ports:
      - "5050:80"
    networks:
      - nexusforge-network
    restart: unless-stopped
    depends_on:
      - postgres

  # ============================================
  # Redis Commander (Redis Management)
  # ============================================
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: nexusforge-redis-commander
    environment:
      - REDIS_HOSTS=local:redis:6379:0:${REDIS_PASSWORD:-redis}
    ports:
      - "8081:8081"
    networks:
      - nexusforge-network
    restart: unless-stopped
    depends_on:
      - redis

  # ============================================
  # Prometheus (Metrics Collection)
  # ============================================
  prometheus:
    image: prom/prometheus:latest
    container_name: nexusforge-prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - nexusforge-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # ============================================
  # Grafana (Metrics Visualization)
  # ============================================
  grafana:
    image: grafana/grafana:latest
    container_name: nexusforge-grafana
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}
      - GF_INSTALL_PLUGINS=redis-datasource
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    ports:
      - "3001:3000"
    networks:
      - nexusforge-network
    restart: unless-stopped
    depends_on:
      - prometheus

  # ============================================
  # Jaeger (Distributed Tracing)
  # ============================================
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: nexusforge-jaeger
    environment:
      - COLLECTOR_ZIPKIN_HOST_PORT=:9411
    ports:
      - "5775:5775/udp"
      - "6831:6831/udp"
      - "6832:6832/udp"
      - "5778:5778"
      - "16686:16686"
      - "14268:14268"
      - "14250:14250"
      - "9411:9411"
    networks:
      - nexusforge-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # ============================================
  # Mailhog (Email Testing)
  # ============================================
  mailhog:
    image: mailhog/mailhog:latest
    container_name: nexusforge-mailhog
    ports:
      - "1025:1025"
      - "8025:8025"
    networks:
      - nexusforge-network
    restart: unless-stopped

  # ============================================
  # Portainer (Container Management)
  # ============================================
  portainer:
    image: portainer/portainer-ce:latest
    container_name: nexusforge-portainer
    command: -H unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer-data:/data
    ports:
      - "9443:9443"
      - "9000:9000"
    networks:
      - nexusforge-network
    restart: unless-stopped

# ============================================
# Networks
# ============================================
networks:
  nexusforge-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16

# ============================================
# Volumes
# ============================================
volumes:
  vscode-data:
  vscode-config:
  postgres-data:
  postgres-backups:
  redis-data:
  pgadmin-data:
  prometheus-data:
  grafana-data:
  portainer-data:
  nginx-cache:
  nginx-logs:
  python-logs:
  nodejs-logs:
  go-logs:
```

### 8.2 PostgreSQL Multiple Database Initialization

**File: `config/docker/postgres/init-multiple-databases.sh`**

```bash
#!/bin/bash

set -e
set -u

function create_user_and_database() {
    local database=$1
    echo "Creating database '$database'"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_user_and_database $db
    done
    echo "Multiple databases created"
fi
```

### 8.3 Nginx Configuration for All-in-One

**File: `config/nginx/nginx-all-in-one.conf`**

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/rss+xml font/truetype font/opentype 
               application/vnd.ms-fontobject image/svg+xml;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

    # Connection limiting
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    # Cache settings
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m max_size=1g 
                     inactive=60m use_temp_path=off;

    # Upstream definitions
    upstream vscode {
        least_conn;
        server vscode-server:8080 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream python_backend {
        least_conn;
        server python-app:8000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream node_backend {
        least_conn;
        server nodejs-app:3000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream go_backend {
        least_conn;
        server go-app:8080 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream pgadmin {
        server pgadmin:80;
    }

    upstream redis_commander {
        server redis-commander:8081;
    }

    upstream grafana {
        server grafana:3000;
    }

    upstream prometheus {
        server prometheus:9090;
    }

    upstream jaeger {
        server jaeger:16686;
    }

    upstream mailhog {
        server mailhog:8025;
    }

    upstream portainer {
        server portainer:9000;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80 default_server;
        server_name _;
        return 301 https://$host$request_uri;
    }

    # Main HTTPS server
    server {
        listen 443 ssl http2 default_server;
        server_name _;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Connection limiting
        limit_conn addr 10;

        # Root location - VS Code Server
        location / {
            limit_req zone=general burst=20 nodelay;
            
            proxy_pass http://vscode;
            proxy_set_header Host $host;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Accept-Encoding gzip;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_http_version 1.1;
            proxy_buffering off;
            proxy_read_timeout 86400;
            proxy_redirect off;
        }

        # Python API
        location /api/python {
            limit_req zone=api burst=20 nodelay;
            
            rewrite ^/api/python/(.*) /$1 break;
            proxy_pass http://python_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_buffering on;
            proxy_cache app_cache;
            proxy_cache_valid 200 5m;
            proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
            add_header X-Cache-Status $upstream_cache_status;
        }

        # Node.js API
        location /api/node {
            limit_req zone=api burst=20 nodelay;
            
            rewrite ^/api/node/(.*) /$1 break;
            proxy_pass http://node_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # Go API
        location /api/go {
            limit_req zone=api burst=20 nodelay;
            
            rewrite ^/api/go/(.*) /$1 break;
            proxy_pass http://go_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # PgAdmin
        location /pgadmin/ {
            proxy_pass http://pgadmin/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Script-Name /pgadmin;
        }

        # Redis Commander
        location /redis/ {
            proxy_pass http://redis_commander/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Grafana
        location /grafana/ {
            proxy_pass http://grafana/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Prometheus
        location /prometheus/ {
            proxy_pass http://prometheus/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Jaeger
        location /jaeger/ {
            proxy_pass http://jaeger/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Mailhog
        location /mailhog/ {
            proxy_pass http://mailhog/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Portainer
        location /portainer/ {
            proxy_pass http://portainer/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Health check endpoint
        location /health {
            access_log off;
            default_type application/json;
            return 200 '{"status":"healthy","timestamp":"$time_iso8601"}';
        }

        # Nginx status for monitoring
        location /nginx-status {
            stub_status on;
            access_log off;
            allow 172.28.0.0/16;
            deny all;
        }
    }
}
```

### 8.4 Prometheus Configuration

**File: `config/prometheus/prometheus.yml`**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'nexusforge-dev'
    environment: 'development'

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Nginx metrics
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: /nginx-status

  # Python application
  - job_name: 'python-app'
    static_configs:
      - targets: ['python-app:8000']
    metrics_path: /metrics

  # Node.js application
  - job_name: 'nodejs-app'
    static_configs:
      - targets: ['nodejs-app:3000']
    metrics_path: /metrics

  # Go application
  - job_name: 'go-app'
    static_configs:
      - targets: ['go-app:8080']
    metrics_path: /metrics

  # PostgreSQL exporter (if added)
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Redis exporter (if added)
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  # Docker container metrics
  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']

alerting:
  alertmanagers:
    - static_configs:
        - targets: []
```

### 8.5 Enhanced VM Setup Script with All-in-One Option

**File: `infrastructure/scripts/03-dev-vm-all-in-one-setup.sh`**

```bash
#!/bin/bash

###############################################################################
# NexusForge Platform - All-in-One VM Setup
# 
# This script sets up a single VM with all services running in containers
#
# Usage: ./03-dev-vm-all-in-one-setup.sh
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ID="${PROJECT_ID:-nexusforge-platform}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
TEAM_NAME="nexusforge"
INSTANCE_NAME="${TEAM_NAME}-all-in-one-vm"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-4}"  # 4 vCPUs, 16 GB RAM
DISK_SIZE="${DISK_SIZE:-100}"  # GB

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create startup script
create_startup_script() {
    cat > /tmp/startup-script.sh << 'STARTUP_SCRIPT_EOF'
#!/bin/bash

set -euo pipefail

echo "Starting NexusForge All-in-One setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install additional tools
apt-get install -y \
    git \
    curl \
    wget \
    vim \
    htop \
    netcat \
    postgresql-client \
    redis-tools \
    jq \
    python3-pip \
    build-essential

# Create directory structure
mkdir -p /opt/nexusforge/{docker,workspace/{python,nodejs,go},logs,backups}
cd /opt/nexusforge

# Clone configuration from repository (or create if not available)
if [ ! -d "config" ]; then
    git clone https://github.com/your-org/nexusforge-platform.git temp-repo
    cp -r temp-repo/config docker/
    rm -rf temp-repo
fi

# Generate self-signed SSL certificate
mkdir -p docker/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout docker/nginx/ssl/key.pem \
    -out docker/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=NexusForge/CN=nexusforge.local"

# Create .env file
cat > docker/.env << 'ENV_EOF'
# NexusForge All-in-One Environment Configuration
ENVIRONMENT=development
TEAM_NAME=nexusforge

# Passwords (CHANGE THESE!)
POSTGRES_PASSWORD=changeme_postgres
REDIS_PASSWORD=changeme_redis
VSCODE_PASSWORD=changeme_vscode
PGADMIN_EMAIL=admin@nexusforge.local
PGADMIN_PASSWORD=changeme_pgadmin
GRAFANA_USER=admin
GRAFANA_PASSWORD=changeme_grafana

# Node.js
NODE_ENV=development

# Python
PYTHONUNBUFFERED=1
ENV_EOF

# Start all services
cd docker
docker-compose -f docker-compose-all-in-one.yml up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 30

# Run health checks
docker-compose -f docker-compose-all-in-one.yml ps

# Create systemd service for auto-start
cat > /etc/systemd/system/nexusforge-all-in-one.service << 'SERVICE_EOF'
[Unit]
Description=NexusForge All-in-One Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/nexusforge/docker
ExecStart=/usr/local/bin/docker-compose -f docker-compose-all-in-one.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose-all-in-one.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable nexusforge-all-in-one.service

# Create backup script
cat > /opt/nexusforge/scripts/backup.sh << 'BACKUP_EOF'
#!/bin/bash
BACKUP_DIR="/opt/nexusforge/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Backup PostgreSQL
docker exec nexusforge-postgres pg_dumpall -U postgres > "${BACKUP_DIR}/postgres-${TIMESTAMP}.sql"

# Backup volumes
docker run --rm -v nexusforge_postgres-data:/data -v ${BACKUP_DIR}:/backup \
    alpine tar czf /backup/postgres-data-${TIMESTAMP}.tar.gz -C /data .

# Rotate old backups (keep last 7 days)
find ${BACKUP_DIR} -name "*.sql" -mtime +7 -delete
find ${BACKUP_DIR} -name "*.tar.gz" -mtime +7 -delete
BACKUP_EOF

chmod +x /opt/nexusforge/scripts/backup.sh

# Setup daily backup cron
echo "0 2 * * * /opt/nexusforge/scripts/backup.sh" | crontab -

echo "NexusForge All-in-One setup completed!"
echo "Services accessible at:"
echo "  VS Code:         https://$(curl -s ifconfig.me)"
echo "  Python API:      https://$(curl -s ifconfig.me)/api/python"
echo "  Node.js API:     https://$(curl -s ifconfig.me)/api/node"
echo "  Go API:          https://$(curl -s ifconfig.me)/api/go"
echo "  PgAdmin:         https://$(curl -s ifconfig.me)/pgadmin"
echo "  Redis Commander: https://$(curl -s ifconfig.me)/redis"
echo "  Grafana:         https://$(curl -s ifconfig.me)/grafana"
echo "  Prometheus:      https://$(curl -s ifconfig.me)/prometheus"
echo "  Jaeger:          https://$(curl -s ifconfig.me)/jaeger"
echo "  Mailhog:         https://$(curl -s ifconfig.me)/mailhog"
echo "  Portainer:       https://$(curl -s ifconfig.me)/portainer"

STARTUP_SCRIPT_EOF
}

# Create the VM
create_vm() {
    print_info "Creating All-in-One VM instance..."
    
    create_startup_script
    
    gcloud compute instances create "${INSTANCE_NAME}" \
        --project="${PROJECT_ID}" \
        --zone="${ZONE}" \
        --machine-type="${MACHINE_TYPE}" \
        --network-interface="subnet=${TEAM_NAME}-subnet-dev,network-tier=PREMIUM" \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --service-account="${TEAM_NAME}-dev-vm@${PROJECT_ID}.iam.gserviceaccount.com" \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --create-disk="auto-delete=yes,boot=yes,device-name=${INSTANCE_NAME},image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts,mode=rw,size=${DISK_SIZE},type=projects/${PROJECT_ID}/zones/${ZONE}/diskTypes/pd-balanced" \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --labels="team=${TEAM_NAME},environment=all-in-one,managed-by=script" \
        --metadata-from-file=startup-script=/tmp/startup-script.sh \
        --tags="${TEAM_NAME}-all-in-one"
    
    rm /tmp/startup-script.sh
    
    print_success "VM instance created"
}

# Create firewall rule for all services
create_firewall_rule() {
    print_info "Creating firewall rule for all services..."
    
    if ! gcloud compute firewall-rules describe "${TEAM_NAME}-allow-all-in-one" &>/dev/null; then
        gcloud compute firewall-rules create "${TEAM_NAME}-allow-all-in-one" \
            --project="${PROJECT_ID}" \
            --network="${TEAM_NAME}-vpc" \
            --allow=tcp:80,tcp:443,tcp:22 \
            --source-ranges=0.0.0.0/0 \
            --target-tags="${TEAM_NAME}-all-in-one" \
            --description="Allow HTTP, HTTPS, and SSH to all-in-one VM"
        print_success "Firewall rule created"
    else
        print_info "Firewall rule already exists"
    fi
}

# Get VM external IP
get_vm_ip() {
    print_info "Getting VM external IP..."
    
    EXTERNAL_IP=$(gcloud compute instances describe "${INSTANCE_NAME}" \
        --zone="${ZONE}" \
        --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
    
    print_success "VM External IP: ${EXTERNAL_IP}"
}

# Display access information
display_access_info() {
    echo ""
    print_success "========================================"
    print_success "All-in-One VM Setup Complete!"
    print_success "========================================"
    echo ""
    print_info "VM Name: ${INSTANCE_NAME}"
    print_info "External IP: ${EXTERNAL_IP}"
    echo ""
    print_info "SSH Access:"
    echo "  gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE}"
    echo ""
    print_info "Service URLs (accessible after ~5 minutes):"
    echo "  VS Code Server:  https://${EXTERNAL_IP}"
    echo "  Python API:      https://${EXTERNAL_IP}/api/python/health"
    echo "  Node.js API:     https://${EXTERNAL_IP}/api/node/health"
    echo "  Go API:          https://${EXTERNAL_IP}/api/go/health"
    echo "  PgAdmin:         https://${EXTERNAL_IP}/pgadmin"
    echo "  Redis Commander: https://${EXTERNAL_IP}/redis"
    echo "  Grafana:         https://${EXTERNAL_IP}/grafana"
    echo "  Prometheus:      https://${EXTERNAL_IP}/prometheus"
    echo "  Jaeger:          https://${EXTERNAL_IP}/jaeger"
    echo "  Mailhog:         https://${EXTERNAL_IP}/mailhog"
    echo "  Portainer:       https://${EXTERNAL_IP}/portainer"
    echo ""
    print_warning "Default passwords are set to 'changeme_*' - UPDATE THEM!"
    print_warning "Update passwords in: /opt/nexusforge/docker/.env"
    echo ""
    print_info "To view startup progress:"
    echo "  gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE} --command='journalctl -u google-startup-scripts -f'"
    echo ""
}

# Main execution
main() {
    print_info "========================================"
    print_info "NexusForge All-in-One VM Setup"
    print_info "========================================"
    echo ""
    
    create_vm
    create_firewall_rule
    get_vm_ip
    display_access_info
}

main
```

### 8.6 Environment File Template

**File: `config/docker/.env.example`**

```bash
# NexusForge All-in-One Environment Configuration
# Copy this file to .env and update with your values

# ==============================================
# General Configuration
# ==============================================
ENVIRONMENT=development
TEAM_NAME=nexusforge
NODE_ENV=development

# ==============================================
# Security - CHANGE ALL THESE PASSWORDS!
# ==============================================
POSTGRES_PASSWORD=CHANGE_ME_STRONG_PASSWORD
REDIS_PASSWORD=CHANGE_ME_STRONG_PASSWORD
VSCODE_PASSWORD=CHANGE_ME_STRONG_PASSWORD
PGADMIN_EMAIL=admin@nexusforge.local
PGADMIN_PASSWORD=CHANGE_ME_STRONG_PASSWORD
GRAFANA_USER=admin
GRAFANA_PASSWORD=CHANGE_ME_STRONG_PASSWORD

# ==============================================
# Python Application
# ==============================================
PYTHONUNBUFFERED=1
PYTHON_LOG_LEVEL=INFO

# ==============================================
# Resource Limits
# ==============================================
# Adjust based on your VM size
PYTHON_MAX_WORKERS=4
NODE_CLUSTER_WORKERS=4
GO_MAX_PROCS=4

# ==============================================
# Monitoring
# ==============================================
PROMETHEUS_RETENTION=15d
GRAFANA_INSTALL_PLUGINS=redis-datasource,postgres-datasource

# ==============================================
# Backup Configuration
# ==============================================
BACKUP_RETENTION_DAYS=7
BACKUP_SCHEDULE=0 2 * * *

# ==============================================
# Performance Tuning
# ==============================================
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB
REDIS_MAXMEMORY=512mb
REDIS_MAXMEMORY_POLICY=allkeys-lru
```

### 8.7 Resource Monitoring Script

**File: `scripts/utilities/monitor-all-in-one.sh`**

```bash
#!/bin/bash

###############################################################################
# Resource Monitoring Script for All-in-One VM
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# System resources
check_system_resources() {
    print_header "System Resources"
    
    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "CPU Usage: ${CPU_USAGE}%"
    
    # Memory
    MEM_INFO=$(free -m | awk 'NR==2{printf "Memory Usage: %.2f%% (%s/%s MB)\n", $3*100/$2, $3,$2 }')
    echo -e "$MEM_INFO"
    
    # Disk
    DISK_INFO=$(df -h / | awk 'NR==2{printf "Disk Usage: %s (%s used of %s)\n", $5,$3,$2}')
    echo -e "$DISK_INFO"
    
    echo ""
}

# Docker containers status
check_containers() {
    print_header "Docker Containers Status"
    
    cd /opt/nexusforge/docker
    docker-compose -f docker-compose-all-in-one.yml ps
    
    echo ""
}

# Container resource usage
check_container_resources() {
    print_header "Container Resource Usage"
    
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
    echo ""
}

# Service health checks
check_service_health() {
    print_header "Service Health Checks"
    
    services=(
        "nginx:443:HTTPS"
        "python-app:8000:Python API"
        "nodejs-app:3000:Node.js API"
        "go-app:8080:Go API"
        "postgres:5432:PostgreSQL"
        "redis:6379:Redis"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r container port name <<< "$service_info"
        
        if docker exec "${container}" sh -c "nc -z localhost ${port}" 2>/dev/null; then
            print_info "${name} is healthy ✓"
        else
            print_error "${name} is unhealthy ✗"
        fi
    done
    
    echo ""
}

# Database connections
check_database() {
    print_header "Database Information"
    
    # PostgreSQL connections
    CONN_COUNT=$(docker exec nexusforge-postgres psql -U postgres -t -c \
        "SELECT count(*) FROM pg_stat_activity WHERE datname != 'postgres';" 2>/dev/null || echo "N/A")
    echo -e "Active PostgreSQL Connections: ${CONN_COUNT}"
    
    # Redis info
    REDIS_INFO=$(docker exec nexusforge-redis redis-cli INFO keyspace 2>/dev/null || echo "N/A")
    echo -e "Redis Info:\n${REDIS_INFO}"
    
    echo ""
}

# Log recent errors
check_logs() {
    print_header "Recent Errors (Last 10)"
    
    docker-compose -f /opt/nexusforge/docker/docker-compose-all-in-one.yml logs --tail=10 2>&1 | grep -i "error" || echo "No recent errors found"
    
    echo ""
}

# Network information
check_network() {
    print_header "Network Information"
    
    # Active connections
    CONN_COUNT=$(netstat -an | grep ESTABLISHED | wc -l)
    echo -e "Active Network Connections: ${CONN_COUNT}"
    
    # Listening ports
    echo -e "\nListening Ports:"
    netstat -tuln | grep LISTEN | awk '{print $4}' | sort -u
    
    echo ""
}

# Backup status
check_backups() {
    print_header "Backup Status"
    
    BACKUP_DIR="/opt/nexusforge/backups"
    if [ -d "${BACKUP_DIR}" ]; then
        LATEST_BACKUP=$(ls -t ${BACKUP_DIR}/*.sql 2>/dev/null | head -1)
        if [ -n "${LATEST_BACKUP}" ]; then
            BACKUP_AGE=$(stat -c %y "${LATEST_BACKUP}" | cut -d' ' -f1,2)
            BACKUP_SIZE=$(du -h "${LATEST_BACKUP}" | cut -f1)
            echo -e "Latest Backup: ${LATEST_BACKUP}"
            echo -e "Backup Date: ${BACKUP_AGE}"
            echo -e "Backup Size: ${BACKUP_SIZE}"
        else
            print_warning "No backups found"
        fi
    else
        print_warning "Backup directory does not exist"
    fi
    
    echo ""
}

# Alert on high resource usage
check_alerts() {
    print_header "Resource Alerts"
    
    # CPU threshold
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)
    if [ "${CPU_USAGE}" -gt 80 ]; then
        print_warning "High CPU usage detected: ${CPU_USAGE}%"
    fi
    
    # Memory threshold
    MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    if [ "${MEM_USAGE}" -gt 85 ]; then
        print_warning "High memory usage detected: ${MEM_USAGE}%"
    fi
    
    # Disk threshold
    DISK_USAGE=$(df / | tail -1 | awk '{print int($5)}')
    if [ "${DISK_USAGE}" -gt 85 ]; then
        print_warning "High disk usage detected: ${DISK_USAGE}%"
    fi
    
    echo ""
}

# Main execution
main() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║  NexusForge All-in-One Monitoring        ║"
    echo "║  $(date +'%Y-%m-%d %H:%M:%S')                    ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    check_system_resources
    check_containers
    check_container_resources
    check_service_health
    check_database
    check_network
    check_backups
    check_alerts
    
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}Monitoring complete!${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Run with watch for continuous monitoring
if [ "${1:-}" == "--watch" ]; then
    watch -n 5 -c "$0"
else
    main
fi
```

### 8.8 Quick Setup Documentation

**File: `docs/06-ALL-IN-ONE-SETUP.md`**

```markdown
# All-in-One VM Setup Guide

## Overview

The All-in-One setup runs all NexusForge services on a single VM instance, making it ideal for:
- Development and testing
- Small teams
- Cost optimization
- Learning and experimentation

## Architecture

```
Single VM Instance (e2-standard-4: 4 vCPUs, 16 GB RAM)
│
├── Nginx (Reverse Proxy)
│   └── Routes to all services
│
├── Application Services
│   ├── Python (FastAPI/Flask/Django)
│   ├── Node.js (Express/NestJS)
│   └── Go (net/http/Gin)
│
├── Development Tools
│   ├── VS Code Server
│   └── Portainer
│
├── Databases
│   ├── PostgreSQL (3 databases)
│   └── Redis
│
├── Management Tools
│   ├── PgAdmin
│   └── Redis Commander
│
└── Monitoring Stack
    ├── Prometheus
    ├── Grafana
    ├── Jaeger
    └── Mailhog
```

## Cost Comparison

| Setup | Monthly Cost | Use Case |
|-------|--------------|----------|
| **All-in-One** | ~$100 | Dev/Test, Small teams |
| **Full Platform** | ~$465 | Production, Multiple environments |

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and configured
- Project created and configured

## Quick Setup

### Step 1: Run Setup Script

```bash
cd infrastructure/scripts
chmod +x 03-dev-vm-all-in-one-setup.sh
./03-dev-vm-all-in-one-setup.sh
```

### Step 2: Wait for Initialization

The VM will take approximately **5-10 minutes** to:
- Install Docker and Docker Compose
- Pull container images
- Start all services
- Run health checks

### Step 3: Update Passwords

SSH into the VM:
```bash
gcloud compute ssh nexusforge-all-in-one-vm --zone=us-central1-a
```

Update passwords:
```bash
cd /opt/nexusforge/docker
nano .env
```

Change all `CHANGE_ME` passwords to strong values.

Restart services:
```bash
docker-compose -f docker-compose-all-in-one.yml restart
```

### Step 4: Access Services

Get your VM's external IP:
```bash
gcloud compute instances describe nexusforge-all-in-one-vm \
  --zone=us-central1-a \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
```

Access services at:
- **VS Code**: https://YOUR_IP
- **Python API**: https://YOUR_IP/api/python/health
- **Node.js API**: https://YOUR_IP/api/node/health
- **Go API**: https://YOUR_IP/api/go/health
- **PgAdmin**: https://YOUR_IP/pgadmin
- **Grafana**: https://YOUR_IP/grafana
- **Prometheus**: https://YOUR_IP/prometheus
- **Portainer**: https://YOUR_IP/portainer

## Service Management

### View All Containers
```bash
cd /opt/nexusforge/docker
docker-compose -f docker-compose-all-in-one.yml ps
```

### View Logs
```bash
# All services
docker-compose -f docker-compose-all-in-one.yml logs -f

# Specific service
docker-compose -f docker-compose-all-in-one.yml logs -f python-app
```

### Restart Services
```bash
# All services
docker-compose -f docker-compose-all-in-one.yml restart

# Specific service
docker-compose -f docker-compose-all-in-one.yml restart python-app
```

### Stop Services
```bash
docker-compose -f docker-compose-all-in-one.yml down
```

### Start Services
```bash
docker-compose -f docker-compose-all-in-one.yml up -d
```

## Monitoring

### Real-time Monitoring
```bash
/opt/nexusforge/scripts/monitor.sh --watch
```

### Check Container Resources
```bash
docker stats
```

### View System Resources
```bash
htop
```

## Backup & Restore

### Manual Backup
```bash
/opt/nexusforge/scripts/backup.sh
```

### Restore from Backup
```bash
# List backups
ls -lh /opt/nexusforge/backups/

# Restore specific backup
docker exec -i nexusforge-postgres psql -U postgres < /opt/nexusforge/backups/postgres-20240101-120000.sql
```

## Scaling Considerations

### When to Scale Up VM Size

Upgrade to `e2-standard-8` (8 vCPUs, 32 GB RAM) if:
- CPU usage consistently > 70%
- Memory usage consistently > 80%
- Response times increasing
- Multiple concurrent users

```bash
# Stop VM
gcloud compute instances stop nexusforge-all-in-one-vm --zone=us-central1-a

# Change machine type
gcloud compute instances set-machine-type nexusforge-all-in-one-vm \
  --machine-type=e2-standard-8 \
  --zone=us-central1-a

# Start VM
gcloud compute instances start nexusforge-all-in-one-vm --zone=us-central1-a
```

### When to Move to Full Platform

Consider moving to the full distributed setup when:
- Team size > 10 developers
- Need separate staging/production
- Require high availability (99.9%+)
- Multiple concurrent applications
- Compliance requirements

## Troubleshooting

### Services Not Starting

Check logs:
```bash
docker-compose -f /opt/nexusforge/docker/docker-compose-all-in-one.yml logs
```

### Cannot Access Services

1. Check firewall rules:
```bash
gcloud compute firewall-rules list --filter="name:nexusforge"
```

2. Verify nginx is running:
```bash
docker logs nexusforge-nginx
```

3. Check individual service health:
```bash
docker-compose -f /opt/nexusforge/docker/docker-compose-all-in-one.yml ps
```

### High Memory Usage

Check which containers are using most memory:
```bash
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | sort -k2 -h
```

Restart memory-heavy services:
```bash
docker-compose -f /opt/nexusforge/docker/docker-compose-all-in-one.yml restart <service-name>
```

### Database Connection Issues

Check PostgreSQL logs:
```bash
docker logs nexusforge-postgres
```

Verify connections:
```bash
docker exec nexusforge-postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

## Security Hardening

### Change All Default Passwords
Update passwords in `/opt/nexusforge/docker/.env`

### Restrict Access by IP
```bash
gcloud compute firewall-rules update nexusforge-allow-all-in-one \
  --source-ranges=YOUR_IP/32
```

### Enable HTTPS with Real Certificate

1. Get a domain name
2. Point DNS to VM IP
3. Use Let's Encrypt:

```bash
docker run -it --rm \
  -v /opt/nexusforge/docker/nginx/ssl:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d your-domain.com
```

4. Update nginx config to use new certificates

## Maintenance

### Update All Containers
```bash
cd /opt/nexusforge/docker
docker-compose -f docker-compose-all-in-one.yml pull
docker-compose -f docker-compose-all-in-one.yml up -d
```

### Clean Up Old Images
```bash
docker image prune -a
```

### Check Disk Space
```bash
df -h
du -sh /opt/nexusforge/*
```

## Advanced Configuration

### Customize Resource Limits

Edit `docker-compose-all-in-one.yml`:
```yaml
services:
  python-app:
    deploy:
      resources:
        limits:
          cpus: '2.0'    # Increase CPU
          memory: 2G     # Increase memory
```

### Add New Services

Add to `docker-compose-all-in-one.yml`:
```yaml
  my-new-service:
    image: my-image:latest
    networks:
      - nexusforge-network
```

Update nginx config to route traffic.

## Support

For issues or questions:
1. Check logs: `/opt/nexusforge/docker/logs/`
2. Run diagnostics: `/opt/nexusforge/scripts/monitor.sh`
3. Review documentation
4. Create GitHub issue
```

---

This All-in-One setup provides a complete development environment on a single VM, perfect for teams wanting to minimize costs while maintaining full functionality. All services are containerized, making it easy to scale individual components as needed.
