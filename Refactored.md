# Refactored NexusForge Platform - DRY Principles Applied

---

## 🔄 Part 9: Refactored CI/CD with Reusable Components

### 9.1 Centralized Configuration

**File: `.github/config/environments.yml`**

```yaml
# Centralized Environment Configuration for NexusForge Platform
# This file defines all environment-specific settings

shared:
  project_id: nexusforge-platform
  region: us-central1
  zone: us-central1-a
  team_name: nexusforge
  docker_registry: us-central1-docker.pkg.dev
  
  # Service configuration
  services:
    - python
    - node
    - go
  
  # Docker image paths
  image_base_path: us-central1-docker.pkg.dev/nexusforge-platform/nexusforge-docker
  
  # Common labels
  labels:
    team: nexusforge
    managed-by: github-actions
  
  # Security scanning
  security:
    trivy_severity: CRITICAL,HIGH,MEDIUM
    trivy_exit_code: 0
    trivy_timeout: 10m

environments:
  dev:
    cloud_run:
      min_instances: 0
      max_instances: 10
      memory: 512Mi
      cpu: 1
      timeout: 300
      concurrency: 80
      ingress: all
      allow_unauthenticated: true
    
    database:
      instance: nexusforge-dev-db
      tier: db-f1-micro
    
    vm:
      machine_type: e2-standard-4
      disk_size: 100
      disk_type: pd-balanced
  
  staging:
    cloud_run:
      min_instances: 1
      max_instances: 20
      memory: 1Gi
      cpu: 2
      timeout: 300
      concurrency: 80
      ingress: internal-and-cloud-load-balancing
      allow_unauthenticated: false
    
    database:
      instance: nexusforge-staging-db
      tier: db-g1-small
    
    vm:
      machine_type: e2-standard-4
      disk_size: 150
      disk_type: pd-balanced
  
  prod:
    cloud_run:
      min_instances: 2
      max_instances: 50
      memory: 2Gi
      cpu: 2
      timeout: 300
      concurrency: 80
      ingress: internal-and-cloud-load-balancing
      allow_unauthenticated: false
    
    database:
      instance: nexusforge-prod-db
      tier: db-custom-2-7680
    
    vm:
      machine_type: e2-standard-8
      disk_size: 200
      disk_type: pd-ssd
```

**File: `.github/config/services.yml`**

```yaml
# Service-specific configuration

services:
  python:
    port: 8000
    dockerfile: config/docker/Dockerfile.python
    health_endpoint: /health
    linters:
      - black
      - pylint
      - mypy
    test_command: pytest --cov --cov-report=xml
    
  node:
    port: 3000
    dockerfile: config/docker/Dockerfile.node
    health_endpoint: /health
    linters:
      - eslint
      - prettier
    test_command: npm test
    
  go:
    port: 8080
    dockerfile: config/docker/Dockerfile.go
    health_endpoint: /health
    linters:
      - golangci-lint
    test_command: go test -v -race -coverprofile=coverage.out ./...
```

### 9.2 Composite Actions

**File: `.github/actions/setup-gcp/action.yml`**

```yaml
name: 'Setup GCP Environment'
description: 'Authenticate to GCP and configure gcloud CLI'

inputs:
  workload_identity_provider:
    description: 'Workload Identity Provider'
    required: true
  service_account:
    description: 'Service Account email'
    required: true
  project_id:
    description: 'GCP Project ID'
    required: true
  region:
    description: 'GCP Region'
    required: false
    default: 'us-central1'

runs:
  using: 'composite'
  steps:
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        workload_identity_provider: ${{ inputs.workload_identity_provider }}
        service_account: ${{ inputs.service_account }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2
      with:
        project_id: ${{ inputs.project_id }}

    - name: Configure gcloud defaults
      shell: bash
      run: |
        gcloud config set project ${{ inputs.project_id }}
        gcloud config set compute/region ${{ inputs.region }}

    - name: Verify authentication
      shell: bash
      run: |
        gcloud auth list
        gcloud config list
```

**File: `.github/actions/security-scan/action.yml`**

```yaml
name: 'Security Scanning'
description: 'Run comprehensive security scans on code and dependencies'

inputs:
  scan_type:
    description: 'Type of scan (code, container, dependencies)'
    required: false
    default: 'all'
  severity:
    description: 'Severity levels to check'
    required: false
    default: 'CRITICAL,HIGH,MEDIUM'
  exit_on_error:
    description: 'Exit with error code if vulnerabilities found'
    required: false
    default: 'false'

outputs:
  scan_results:
    description: 'Path to scan results'
    value: ${{ steps.scan.outputs.results_path }}

runs:
  using: 'composite'
  steps:
    - name: Run Trivy filesystem scan
      if: inputs.scan_type == 'all' || inputs.scan_type == 'code'
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: ${{ inputs.severity }}
        exit-code: ${{ inputs.exit_on_error == 'true' && '1' || '0' }}

    - name: Upload Trivy results to GitHub Security
      if: inputs.scan_type == 'all' || inputs.scan_type == 'code'
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Detect secrets
      if: inputs.scan_type == 'all' || inputs.scan_type == 'code'
      shell: bash
      run: |
        pip install detect-secrets
        detect-secrets scan --all-files --force-use-all-plugins > secrets-baseline.json || true

    - name: Check for Python vulnerabilities
      if: inputs.scan_type == 'all' || inputs.scan_type == 'dependencies'
      shell: bash
      run: |
        if [ -f "requirements.txt" ]; then
          pip install safety bandit
          safety check --json --output safety-report.json || true
          bandit -r . -f json -o bandit-report.json || true
        fi

    - name: Check for Node.js vulnerabilities
      if: inputs.scan_type == 'all' || inputs.scan_type == 'dependencies'
      shell: bash
      run: |
        if [ -f "package.json" ]; then
          npm audit --json > npm-audit.json || true
        fi

    - name: Check for Go vulnerabilities
      if: inputs.scan_type == 'all' || inputs.scan_type == 'dependencies'
      uses: securego/gosec@master
      if: hashFiles('**/*.go') != ''
      with:
        args: '-fmt json -out gosec-report.json ./...'

    - name: Upload security reports
      uses: actions/upload-artifact@v4
      with:
        name: security-reports-${{ github.sha }}
        path: |
          *-report.json
          *-results.json
          *-baseline.json
        retention-days: 30
```

**File: `.github/actions/build-and-push-image/action.yml`**

```yaml
name: 'Build and Push Docker Image'
description: 'Build Docker image and push to Artifact Registry'

inputs:
  service:
    description: 'Service name (python, node, go)'
    required: true
  dockerfile:
    description: 'Path to Dockerfile'
    required: true
  project_id:
    description: 'GCP Project ID'
    required: true
  region:
    description: 'GCP Region'
    required: true
  team_name:
    description: 'Team name'
    required: true
  image_tag:
    description: 'Image tag'
    required: true
  additional_tags:
    description: 'Additional tags (comma-separated)'
    required: false
    default: ''
  build_args:
    description: 'Build arguments (KEY=VALUE format, one per line)'
    required: false
    default: ''
  scan_image:
    description: 'Run security scan on built image'
    required: false
    default: 'true'

outputs:
  image_url:
    description: 'Full image URL'
    value: ${{ steps.build.outputs.image_url }}
  digest:
    description: 'Image digest'
    value: ${{ steps.build.outputs.digest }}

runs:
  using: 'composite'
  steps:
    - name: Configure Docker for Artifact Registry
      shell: bash
      run: |
        gcloud auth configure-docker ${{ inputs.region }}-docker.pkg.dev

    - name: Build Docker image
      id: build
      shell: bash
      run: |
        IMAGE_BASE="${{ inputs.region }}-docker.pkg.dev/${{ inputs.project_id }}/${{ inputs.team_name }}-docker/${{ inputs.service }}"
        IMAGE_URL="${IMAGE_BASE}:${{ inputs.image_tag }}"
        
        # Prepare build args
        BUILD_ARGS=""
        if [ -n "${{ inputs.build_args }}" ]; then
          while IFS= read -r arg; do
            BUILD_ARGS="${BUILD_ARGS} --build-arg ${arg}"
          done <<< "${{ inputs.build_args }}"
        fi
        
        # Build command
        docker build \
          -f ${{ inputs.dockerfile }} \
          -t ${IMAGE_URL} \
          ${BUILD_ARGS} \
          .
        
        # Additional tags
        if [ -n "${{ inputs.additional_tags }}" ]; then
          IFS=',' read -ra TAGS <<< "${{ inputs.additional_tags }}"
          for tag in "${TAGS[@]}"; do
            docker tag ${IMAGE_URL} ${IMAGE_BASE}:${tag}
          done
        fi
        
        echo "image_url=${IMAGE_URL}" >> $GITHUB_OUTPUT
        echo "digest=$(docker inspect --format='{{.Id}}' ${IMAGE_URL})" >> $GITHUB_OUTPUT

    - name: Scan image with Trivy
      if: inputs.scan_image == 'true'
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ steps.build.outputs.image_url }}
        format: 'table'
        exit-code: '0'
        severity: 'CRITICAL,HIGH'

    - name: Push Docker image
      shell: bash
      run: |
        IMAGE_BASE="${{ inputs.region }}-docker.pkg.dev/${{ inputs.project_id }}/${{ inputs.team_name }}-docker/${{ inputs.service }}"
        
        # Push main tag
        docker push ${{ steps.build.outputs.image_url }}
        
        # Push additional tags
        if [ -n "${{ inputs.additional_tags }}" ]; then
          IFS=',' read -ra TAGS <<< "${{ inputs.additional_tags }}"
          for tag in "${TAGS[@]}"; do
            docker push ${IMAGE_BASE}:${tag}
          done
        fi
```

**File: `.github/actions/deploy-cloud-run/action.yml`**

```yaml
name: 'Deploy to Cloud Run'
description: 'Deploy service to Google Cloud Run'

inputs:
  service_name:
    description: 'Cloud Run service name'
    required: true
  image:
    description: 'Docker image URL'
    required: true
  region:
    description: 'GCP Region'
    required: true
  service_account:
    description: 'Service account email'
    required: true
  environment:
    description: 'Environment name (dev, staging, prod)'
    required: true
  min_instances:
    description: 'Minimum instances'
    required: false
    default: '0'
  max_instances:
    description: 'Maximum instances'
    required: false
    default: '10'
  memory:
    description: 'Memory allocation'
    required: false
    default: '512Mi'
  cpu:
    description: 'CPU allocation'
    required: false
    default: '1'
  timeout:
    description: 'Request timeout'
    required: false
    default: '300'
  concurrency:
    description: 'Concurrent requests per instance'
    required: false
    default: '80'
  env_vars:
    description: 'Environment variables (KEY=VALUE format, one per line)'
    required: false
    default: ''
  secrets:
    description: 'Secret references (KEY=SECRET_NAME:VERSION format, one per line)'
    required: false
    default: ''
  vpc_connector:
    description: 'VPC connector name'
    required: false
    default: ''
  ingress:
    description: 'Ingress settings'
    required: false
    default: 'all'
  allow_unauthenticated:
    description: 'Allow unauthenticated access'
    required: false
    default: 'false'
  traffic_split:
    description: 'Traffic split percentage for canary (0-100)'
    required: false
    default: '100'
  revision_suffix:
    description: 'Revision suffix'
    required: false
    default: ''

outputs:
  service_url:
    description: 'Cloud Run service URL'
    value: ${{ steps.deploy.outputs.url }}
  revision:
    description: 'Deployed revision name'
    value: ${{ steps.deploy.outputs.revision }}

runs:
  using: 'composite'
  steps:
    - name: Prepare deployment flags
      id: prepare
      shell: bash
      run: |
        FLAGS=""
        FLAGS="${FLAGS} --service-account=${{ inputs.service_account }}"
        FLAGS="${FLAGS} --min-instances=${{ inputs.min_instances }}"
        FLAGS="${FLAGS} --max-instances=${{ inputs.max_instances }}"
        FLAGS="${FLAGS} --memory=${{ inputs.memory }}"
        FLAGS="${FLAGS} --cpu=${{ inputs.cpu }}"
        FLAGS="${FLAGS} --timeout=${{ inputs.timeout }}"
        FLAGS="${FLAGS} --concurrency=${{ inputs.concurrency }}"
        FLAGS="${FLAGS} --ingress=${{ inputs.ingress }}"
        
        if [ "${{ inputs.allow_unauthenticated }}" == "true" ]; then
          FLAGS="${FLAGS} --allow-unauthenticated"
        else
          FLAGS="${FLAGS} --no-allow-unauthenticated"
        fi
        
        if [ -n "${{ inputs.vpc_connector }}" ]; then
          FLAGS="${FLAGS} --vpc-connector=${{ inputs.vpc_connector }}"
        fi
        
        if [ -n "${{ inputs.revision_suffix }}" ]; then
          FLAGS="${FLAGS} --revision-suffix=${{ inputs.revision_suffix }}"
        fi
        
        if [ "${{ inputs.traffic_split }}" != "100" ]; then
          FLAGS="${FLAGS} --no-traffic"
        fi
        
        # Environment variables
        if [ -n "${{ inputs.env_vars }}" ]; then
          ENV_VARS=""
          while IFS= read -r var; do
            if [ -z "${ENV_VARS}" ]; then
              ENV_VARS="${var}"
            else
              ENV_VARS="${ENV_VARS},${var}"
            fi
          done <<< "${{ inputs.env_vars }}"
          FLAGS="${FLAGS} --set-env-vars=${ENV_VARS}"
        fi
        
        # Secrets
        if [ -n "${{ inputs.secrets }}" ]; then
          SECRETS=""
          while IFS= read -r secret; do
            if [ -z "${SECRETS}" ]; then
              SECRETS="${secret}"
            else
              SECRETS="${SECRETS},${secret}"
            fi
          done <<< "${{ inputs.secrets }}"
          FLAGS="${FLAGS} --set-secrets=${SECRETS}"
        fi
        
        # Labels
        FLAGS="${FLAGS} --labels=environment=${{ inputs.environment }},managed-by=github-actions"
        
        echo "flags=${FLAGS}" >> $GITHUB_OUTPUT

    - name: Deploy to Cloud Run
      id: deploy
      uses: google-github-actions/deploy-cloudrun@v2
      with:
        service: ${{ inputs.service_name }}
        region: ${{ inputs.region }}
        image: ${{ inputs.image }}
        flags: ${{ steps.prepare.outputs.flags }}

    - name: Configure traffic split
      if: inputs.traffic_split != '100'
      shell: bash
      run: |
        REVISION=$(gcloud run services describe ${{ inputs.service_name }} \
          --region=${{ inputs.region }} \
          --format='value(status.latestCreatedRevisionName)')
        
        gcloud run services update-traffic ${{ inputs.service_name }} \
          --region=${{ inputs.region }} \
          --to-revisions=${REVISION}=${{ inputs.traffic_split }}

    - name: Run smoke test
      shell: bash
      run: |
        SERVICE_URL="${{ steps.deploy.outputs.url }}"
        echo "Testing service at: ${SERVICE_URL}/health"
        
        # Wait a bit for service to be ready
        sleep 10
        
        # Try up to 3 times
        for i in {1..3}; do
          if curl -f -s "${SERVICE_URL}/health" > /dev/null; then
            echo "✅ Health check passed"
            exit 0
          fi
          echo "⚠️  Attempt $i failed, retrying..."
          sleep 5
        done
        
        echo "❌ Health check failed after 3 attempts"
        exit 1
```

**File: `.github/actions/run-tests/action.yml`**

```yaml
name: 'Run Tests'
description: 'Run tests for different languages with coverage'

inputs:
  language:
    description: 'Language (python, node, go)'
    required: true
  coverage:
    description: 'Generate coverage report'
    required: false
    default: 'true'
  upload_coverage:
    description: 'Upload coverage to artifacts'
    required: false
    default: 'true'

outputs:
  coverage_percentage:
    description: 'Coverage percentage'
    value: ${{ steps.test.outputs.coverage }}

runs:
  using: 'composite'
  steps:
    - name: Setup Python
      if: inputs.language == 'python'
      uses: actions/setup-python@v5
      with:
        python-version: '3.9'
        cache: 'pip'

    - name: Setup Node.js
      if: inputs.language == 'node'
      uses: actions/setup-node@v4
      with:
        node-version: '16'
        cache: 'npm'

    - name: Setup Go
      if: inputs.language == 'go'
      uses: actions/setup-go@v5
      with:
        go-version: '1.18'
        cache: true

    - name: Install Python dependencies
      if: inputs.language == 'python'
      shell: bash
      run: |
        python -m pip install --upgrade pip
        if [ -f "requirements.txt" ]; then
          pip install -r requirements.txt
        fi
        pip install pytest pytest-cov pylint black mypy

    - name: Install Node.js dependencies
      if: inputs.language == 'node'
      shell: bash
      run: |
        if [ -f "package.json" ]; then
          npm ci
        fi

    - name: Install Go dependencies
      if: inputs.language == 'go'
      shell: bash
      run: |
        if [ -f "go.mod" ]; then
          go mod download
        fi

    - name: Lint Python
      if: inputs.language == 'python'
      shell: bash
      run: |
        black --check . || true
        pylint **/*.py || true
        mypy . || true

    - name: Lint Node.js
      if: inputs.language == 'node'
      shell: bash
      run: |
        if [ -f "package.json" ]; then
          npm run lint || true
        fi

    - name: Lint Go
      if: inputs.language == 'go'
      shell: bash
      run: |
        if [ -f "go.mod" ]; then
          go fmt ./...
          go vet ./...
        fi

    - name: Run Python tests
      if: inputs.language == 'python'
      id: test
      shell: bash
      run: |
        if [ "${{ inputs.coverage }}" == "true" ]; then
          pytest --cov --cov-report=term --cov-report=xml --cov-report=html
          COVERAGE=$(python -c "import xml.etree.ElementTree as ET; tree = ET.parse('coverage.xml'); root = tree.getroot(); print(root.attrib['line-rate'])")
          echo "coverage=${COVERAGE}" >> $GITHUB_OUTPUT
        else
          pytest
        fi

    - name: Run Node.js tests
      if: inputs.language == 'node'
      id: test-node
      shell: bash
      run: |
        if [ -f "package.json" ]; then
          if [ "${{ inputs.coverage }}" == "true" ]; then
            npm test -- --coverage
          else
            npm test
          fi
        fi

    - name: Run Go tests
      if: inputs.language == 'go'
      id: test-go
      shell: bash
      run: |
        if [ -f "go.mod" ]; then
          if [ "${{ inputs.coverage }}" == "true" ]; then
            go test -v -race -coverprofile=coverage.out ./...
            go tool cover -html=coverage.out -o coverage.html
            COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}')
            echo "coverage=${COVERAGE}" >> $GITHUB_OUTPUT
          else
            go test -v ./...
          fi
        fi

    - name: Upload coverage reports
      if: inputs.upload_coverage == 'true' && inputs.coverage == 'true'
      uses: actions/upload-artifact@v4
      with:
        name: coverage-${{ inputs.language }}-${{ github.sha }}
        path: |
          coverage.xml
          coverage.html
          htmlcov/
          coverage/
          coverage.out
        retention-days: 30
```

### 9.3 Reusable Workflows

**File: `.github/workflows/reusable-security-scan.yml`**

```yaml
name: Reusable Security Scan

on:
  workflow_call:
    inputs:
      scan_type:
        description: 'Type of scan to run'
        required: false
        type: string
        default: 'all'
      severity:
        description: 'Severity levels'
        required: false
        type: string
        default: 'CRITICAL,HIGH,MEDIUM'
      fail_on_error:
        description: 'Fail workflow on security issues'
        required: false
        type: boolean
        default: false
    outputs:
      scan_status:
        description: 'Status of security scan'
        value: ${{ jobs.scan.outputs.status }}

jobs:
  scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    outputs:
      status: ${{ steps.scan.outcome }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run security scan
        id: scan
        uses: ./.github/actions/security-scan
        with:
          scan_type: ${{ inputs.scan_type }}
          severity: ${{ inputs.severity }}
          exit_on_error: ${{ inputs.fail_on_error }}

      - name: Generate security summary
        if: always()
        run: |
          echo "### 🔒 Security Scan Results" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Scan Type**: ${{ inputs.scan_type }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Severity**: ${{ inputs.severity }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ steps.scan.outcome }}" >> $GITHUB_STEP_SUMMARY
```

**File: `.github/workflows/reusable-test.yml`**

```yaml
name: Reusable Test Workflow

on:
  workflow_call:
    inputs:
      language:
        description: 'Programming language'
        required: true
        type: string
      coverage_threshold:
        description: 'Minimum coverage percentage'
        required: false
        type: number
        default: 80
    outputs:
      test_status:
        description: 'Test execution status'
        value: ${{ jobs.test.outputs.status }}
      coverage:
        description: 'Code coverage percentage'
        value: ${{ jobs.test.outputs.coverage }}

jobs:
  test:
    name: Test ${{ inputs.language }}
    runs-on: ubuntu-latest
    outputs:
      status: ${{ steps.test.outcome }}
      coverage: ${{ steps.test.outputs.coverage_percentage }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tests
        id: test
        uses: ./.github/actions/run-tests
        with:
          language: ${{ inputs.language }}
          coverage: 'true'
          upload_coverage: 'true'

      - name: Check coverage threshold
        if: steps.test.outputs.coverage_percentage != ''
        run: |
          COVERAGE=$(echo "${{ steps.test.outputs.coverage_percentage }}" | sed 's/%//')
          THRESHOLD=${{ inputs.coverage_threshold }}
          
          if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
            echo "❌ Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
            exit 1
          else
            echo "✅ Coverage ${COVERAGE}% meets threshold ${THRESHOLD}%"
          fi

      - name: Generate test summary
        if: always()
        run: |
          echo "### 🧪 Test Results - ${{ inputs.language }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ steps.test.outcome }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Coverage**: ${{ steps.test.outputs.coverage_percentage }}" >> $GITHUB_STEP_SUMMARY
```

**File: `.github/workflows/reusable-build-push.yml`**

```yaml
name: Reusable Build and Push

on:
  workflow_call:
    inputs:
      service:
        description: 'Service name'
        required: true
        type: string
      environment:
        description: 'Target environment'
        required: true
        type: string
      image_tag:
        description: 'Docker image tag'
        required: true
        type: string
    secrets:
      workload_identity_provider:
        required: true
      service_account:
        required: true
      project_id:
        required: true
    outputs:
      image_url:
        description: 'Built image URL'
        value: ${{ jobs.build.outputs.image_url }}

env:
  REGION: us-central1
  TEAM_NAME: nexusforge

jobs:
  build:
    name: Build ${{ inputs.service }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    outputs:
      image_url: ${{ steps.build.outputs.image_url }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup GCP
        uses: ./.github/actions/setup-gcp
        with:
          workload_identity_provider: ${{ secrets.workload_identity_provider }}
          service_account: ${{ secrets.service_account }}
          project_id: ${{ secrets.project_id }}
          region: ${{ env.REGION }}

      - name: Load service configuration
        id: config
        run: |
          SERVICE_CONFIG=$(yq eval ".services.${{ inputs.service }}" .github/config/services.yml)
          DOCKERFILE=$(echo "$SERVICE_CONFIG" | yq eval '.dockerfile' -)
          echo "dockerfile=${DOCKERFILE}" >> $GITHUB_OUTPUT

      - name: Build and push image
        id: build
        uses: ./.github/actions/build-and-push-image
        with:
          service: ${{ inputs.service }}
          dockerfile: ${{ steps.config.outputs.dockerfile }}
          project_id: ${{ secrets.project_id }}
          region: ${{ env.REGION }}
          team_name: ${{ env.TEAM_NAME }}
          image_tag: ${{ inputs.image_tag }}
          additional_tags: ${{ inputs.environment }}-latest
          build_args: |
            BUILD_ENV=${{ inputs.environment }}
          scan_image: 'true'

      - name: Generate build summary
        run: |
          echo "### 🐳 Docker Build - ${{ inputs.service }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Image**: ${{ steps.build.outputs.image_url }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Digest**: ${{ steps.build.outputs.digest }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: ${{ inputs.environment }}" >> $GITHUB_STEP_SUMMARY
```

**File: `.github/workflows/reusable-deploy.yml`**

```yaml
name: Reusable Deploy to Cloud Run

on:
  workflow_call:
    inputs:
      service:
        description: 'Service name'
        required: true
        type: string
      environment:
        description: 'Target environment'
        required: true
        type: string
      image:
        description: 'Docker image to deploy'
        required: true
        type: string
      traffic_percentage:
        description: 'Traffic percentage for deployment'
        required: false
        type: number
        default: 100
    secrets:
      workload_identity_provider:
        required: true
      service_account:
        required: true
      project_id:
        required: true
    outputs:
      service_url:
        description: 'Deployed service URL'
        value: ${{ jobs.deploy.outputs.url }}

env:
  REGION: us-central1
  TEAM_NAME: nexusforge

jobs:
  deploy:
    name: Deploy ${{ inputs.service }} to ${{ inputs.environment }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    environment:
      name: ${{ inputs.environment }}
      url: ${{ steps.deploy.outputs.service_url }}
    outputs:
      url: ${{ steps.deploy.outputs.service_url }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup GCP
        uses: ./.github/actions/setup-gcp
        with:
          workload_identity_provider: ${{ secrets.workload_identity_provider }}
          service_account: ${{ secrets.service_account }}
          project_id: ${{ secrets.project_id }}
          region: ${{ env.REGION }}

      - name: Load environment configuration
        id: config
        run: |
          CONFIG=$(yq eval ".environments.${{ inputs.environment }}.cloud_run" .github/config/environments.yml)
          
          MIN_INSTANCES=$(echo "$CONFIG" | yq eval '.min_instances' -)
          MAX_INSTANCES=$(echo "$CONFIG" | yq eval '.max_instances' -)
          MEMORY=$(echo "$CONFIG" | yq eval '.memory' -)
          CPU=$(echo "$CONFIG" | yq eval '.cpu' -)
          TIMEOUT=$(echo "$CONFIG" | yq eval '.timeout' -)
          CONCURRENCY=$(echo "$CONFIG" | yq eval '.concurrency' -)
          INGRESS=$(echo "$CONFIG" | yq eval '.ingress' -)
          ALLOW_UNAUTH=$(echo "$CONFIG" | yq eval '.allow_unauthenticated' -)
          
          echo "min_instances=${MIN_INSTANCES}" >> $GITHUB_OUTPUT
          echo "max_instances=${MAX_INSTANCES}" >> $GITHUB_OUTPUT
          echo "memory=${MEMORY}" >> $GITHUB_OUTPUT
          echo "cpu=${CPU}" >> $GITHUB_OUTPUT
          echo "timeout=${TIMEOUT}" >> $GITHUB_OUTPUT
          echo "concurrency=${CONCURRENCY}" >> $GITHUB_OUTPUT
          echo "ingress=${INGRESS}" >> $GITHUB_OUTPUT
          echo "allow_unauthenticated=${ALLOW_UNAUTH}" >> $GITHUB_OUTPUT

      - name: Deploy to Cloud Run
        id: deploy
        uses: ./.github/actions/deploy-cloud-run
        with:
          service_name: ${{ env.TEAM_NAME }}-${{ inputs.service }}-${{ inputs.environment }}
          image: ${{ inputs.image }}
          region: ${{ env.REGION }}
          service_account: ${{ env.TEAM_NAME }}-cloud-run@${{ secrets.project_id }}.iam.gserviceaccount.com
          environment: ${{ inputs.environment }}
          min_instances: ${{ steps.config.outputs.min_instances }}
          max_instances: ${{ steps.config.outputs.max_instances }}
          memory: ${{ steps.config.outputs.memory }}
          cpu: ${{ steps.config.outputs.cpu }}
          timeout: ${{ steps.config.outputs.timeout }}
          concurrency: ${{ steps.config.outputs.concurrency }}
          ingress: ${{ steps.config.outputs.ingress }}
          allow_unauthenticated: ${{ steps.config.outputs.allow_unauthenticated }}
          vpc_connector: ${{ env.TEAM_NAME }}-vpc-connector
          env_vars: |
            ENVIRONMENT=${{ inputs.environment }}
            TEAM_NAME=${{ env.TEAM_NAME }}
          secrets: |
            DATABASE_URL=${{ env.TEAM_NAME }}-${{ inputs.environment }}-db-password:latest
          traffic_split: ${{ inputs.traffic_percentage }}
          revision_suffix: ${{ github.sha }}

      - name: Generate deployment summary
        run: |
          echo "### 🚀 Deployment - ${{ inputs.service }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: ${{ inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Service URL**: ${{ steps.deploy.outputs.service_url }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Revision**: ${{ steps.deploy.outputs.revision }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Traffic**: ${{ inputs.traffic_percentage }}%" >> $GITHUB_STEP_SUMMARY
```

### 9.4 Refactored Main Workflows

**File: `.github/workflows/01-infrastructure-setup.yml`**

```yaml
name: 01 - Infrastructure Setup

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod
      destroy:
        description: 'Destroy infrastructure'
        required: false
        type: boolean
        default: false
      instance_type:
        description: 'VM instance type'
        required: false
        type: choice
        options:
          - standard
          - all-in-one
        default: 'standard'

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1
  ZONE: us-central1-a
  TEAM_NAME: nexusforge

jobs:
  setup-infrastructure:
    name: Setup Infrastructure
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup GCP
        uses: ./.github/actions/setup-gcp
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          region: ${{ env.REGION }}

      - name: Load environment configuration
        id: config
        run: |
          VM_CONFIG=$(yq eval ".environments.${{ inputs.environment }}.vm" .github/config/environments.yml)
          
          MACHINE_TYPE=$(echo "$VM_CONFIG" | yq eval '.machine_type' -)
          DISK_SIZE=$(echo "$VM_CONFIG" | yq eval '.disk_size' -)
          DISK_TYPE=$(echo "$VM_CONFIG" | yq eval '.disk_type' -)
          
          echo "machine_type=${MACHINE_TYPE}" >> $GITHUB_OUTPUT
          echo "disk_size=${DISK_SIZE}" >> $GITHUB_OUTPUT
          echo "disk_type=${DISK_TYPE}" >> $GITHUB_OUTPUT

      - name: Deploy infrastructure
        if: ${{ !inputs.destroy }}
        run: |
          cd infrastructure/scripts
          chmod +x *.sh
          
          export ENVIRONMENT=${{ inputs.environment }}
          export MACHINE_TYPE=${{ steps.config.outputs.machine_type }}
          export DISK_SIZE=${{ steps.config.outputs.disk_size }}
          
          if [ "${{ inputs.instance_type }}" == "all-in-one" ]; then
            ./03-dev-vm-all-in-one-setup.sh
          else
            ./02-dev-vm-setup.sh
          fi

      - name: Destroy infrastructure
        if: ${{ inputs.destroy }}
        run: |
          INSTANCE_NAME="${{ env.TEAM_NAME }}-${{ inputs.environment }}-vm"
          
          gcloud compute instances delete ${INSTANCE_NAME} \
            --zone=${{ env.ZONE }} \
            --quiet || true

      - name: Generate summary
        if: always()
        run: |
          echo "### 🏗️ Infrastructure Setup" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: ${{ inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Action**: ${{ inputs.destroy && 'Destroy' || 'Deploy' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Instance Type**: ${{ inputs.instance_type }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Machine Type**: ${{ steps.config.outputs.machine_type }}" >> $GITHUB_STEP_SUMMARY
```

**File: `.github/workflows/02-deploy-dev.yml`**

```yaml
name: 02 - Deploy to Development

on:
  push:
    branches:
      - develop
      - feature/*
  workflow_dispatch:

env:
  ENVIRONMENT: dev

jobs:
  security-scan:
    name: Security Scan
    uses: ./.github/workflows/reusable-security-scan.yml
    with:
      scan_type: all
      severity: CRITICAL,HIGH,MEDIUM
      fail_on_error: false

  test:
    name: Run Tests
    needs: security-scan
    strategy:
      matrix:
        language: [python, node, go]
    uses: ./.github/workflows/reusable-test.yml
    with:
      language: ${{ matrix.language }}
      coverage_threshold: 70

  build:
    name: Build Images
    needs: test
    strategy:
      matrix:
        service: [python, node, go]
    uses: ./.github/workflows/reusable-build-push.yml
    with:
      service: ${{ matrix.service }}
      environment: dev
      image_tag: ${{ github.sha }}
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: ${{ secrets.GCP_PROJECT_ID }}

  deploy:
    name: Deploy Services
    needs: build
    strategy:
      matrix:
        service: [python, node, go]
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      service: ${{ matrix.service }}
      environment: dev
      image: ${{ needs.build.outputs.image_url }}
      traffic_percentage: 100
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: ${{ secrets.GCP_PROJECT_ID }}

  notify:
    name: Send Notification
    needs: deploy
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Deployment status
        run: |
          echo "### 📢 Deployment Status - DEV" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ needs.deploy.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Commit**: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Branch**: ${{ github.ref_name }}" >> $GITHUB_STEP_SUMMARY
```

**File: `.github/workflows/03-deploy-staging.yml`**

```yaml
name: 03 - Deploy to Staging

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  ENVIRONMENT: staging

jobs:
  security-scan:
    name: Security Scan
    uses: ./.github/workflows/reusable-security-scan.yml
    with:
      scan_type: all
      severity: CRITICAL,HIGH,MEDIUM
      fail_on_error: true

  test:
    name: Run Tests
    needs: security-scan
    strategy:
      matrix:
        language: [python, node, go]
    uses: ./.github/workflows/reusable-test.yml
    with:
      language: ${{ matrix.language }}
      coverage_threshold: 80

  build:
    name: Build Images
    needs: test
    strategy:
      matrix:
        service: [python, node, go]
    uses: ./.github/workflows/reusable-build-push.yml
    with:
      service: ${{ matrix.service }}
      environment: staging
      image_tag: ${{ github.sha }}
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: ${{ secrets.GCP_PROJECT_ID }}

  deploy:
    name: Deploy Services
    needs: build
    strategy:
      matrix:
        service: [python, node, go]
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      service: ${{ matrix.service }}
      environment: staging
      image: ${{ needs.build.outputs.image_url }}
      traffic_percentage: 100
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: ${{ secrets.GCP_PROJECT_ID }}

  integration-tests:
    name: Integration Tests
    needs: deploy
    runs-on: ubuntu-latest
    steps:
      - name: Run integration tests
        run: |
          echo "Running integration tests..."
          # Add actual integration test commands

  notify:
    name: Send Notification
    needs: [deploy, integration-tests]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Deployment status
        run: |
          echo "### 📢 Deployment Status - STAGING" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Deploy Status**: ${{ needs.deploy.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Tests Status**: ${{ needs.integration-tests.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Commit**: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
```

**File: `.github/workflows/04-deploy-prod.yml`**

```yaml
name: 04 - Deploy to Production

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      deployment_strategy:
        description: 'Deployment strategy'
        required: true
        type: choice
        options:
          - canary
          - blue-green
        default: canary
      canary_percentage:
        description: 'Initial canary traffic %'
        required: false
        type: number
        default: 10

env:
  ENVIRONMENT: prod

jobs:
  approval:
    name: Manual Approval
    runs-on: ubuntu-latest
    environment:
      name: production-approval
    steps:
      - run: echo "Deployment approved"

  security-scan:
    name: Security Scan
    needs: approval
    uses: ./.github/workflows/reusable-security-scan.yml
    with:
      scan_type: all
      severity: CRITICAL,HIGH,MEDIUM
      fail_on_error: true

  build:
    name: Build Images
    needs: security-scan
    strategy:
      matrix:
        service: [python, node, go]
    uses: ./.github/workflows/reusable-build-push.yml
    with:
      service: ${{ matrix.service }}
      environment: prod
      image_tag: ${{ github.sha }}
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: ${{ secrets.GCP_PROJECT_ID }}

  deploy-canary:
    name: Deploy Canary
    needs: build
    if: github.event.inputs.deployment_strategy == 'canary' || !github.event.inputs.deployment_strategy
    strategy:
      matrix:
        service: [python, node, go]
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      service: ${{ matrix.service }}
      environment: prod
      image: ${{ needs.build.outputs.image_url }}
      traffic_percentage: ${{ github.event.inputs.canary_percentage || 10 }}
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: ${{ secrets.GCP_PROJECT_ID }}

  monitor-canary:
    name: Monitor Canary
    needs: deploy-canary
    runs-on: ubuntu-latest
    steps:
      - name: Wait and monitor
        run: |
          echo "Monitoring canary for 10 minutes..."
          sleep 600
          # Add monitoring checks here

  promote-canary:
    name: Promote Canary
    needs: monitor-canary
    strategy:
      matrix:
        service: [python, node, go]
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      service: ${{ matrix.service }}
      environment: prod
      image: ${{ needs.build.outputs.image_url }}
      traffic_percentage: 100
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      project_id: ${{ secrets.GCP_PROJECT_ID }}

  notify:
    name: Send Notification
    needs: promote-canary
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Deployment status
        run: |
          echo "### 📢 Production Deployment Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ needs.promote-canary.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Strategy**: ${{ github.event.inputs.deployment_strategy || 'canary' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Version**: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
```

### 9.5 Makefile for Local Testing

**File: `Makefile`**

```makefile
# NexusForge Platform Makefile

.PHONY: help setup test lint build deploy clean

# Variables
PROJECT_ID ?= nexusforge-platform
REGION ?= us-central1
ENVIRONMENT ?= dev

help:
	@echo "NexusForge Platform - Available Commands:"
	@echo ""
	@echo "  make setup          - Initial setup"
	@echo "  make test           - Run all tests"
	@echo "  make lint           - Run linters"
	@echo "  make security-scan  - Run security scans"
	@echo "  make build          - Build all containers"
	@echo "  make deploy ENV=dev - Deploy to environment"
	@echo "  make clean          - Clean up artifacts"
	@echo ""

setup:
	@echo "Setting up development environment..."
	pip install -r requirements.txt
	npm install
	go mod download

test:
	@echo "Running tests..."
	pytest --cov
	npm test
	go test ./...

lint:
	@echo "Running linters..."
	black --check .
	pylint **/*.py
	npm run lint
	go fmt ./...
	go vet ./...

security-scan:
	@echo "Running security scans..."
	trivy fs --severity CRITICAL,HIGH .
	safety check
	npm audit

build:
	@echo "Building containers..."
	docker-compose -f config/docker/docker-compose-all-in-one.yml build

deploy:
	@echo "Deploying to $(ENVIRONMENT)..."
	./infrastructure/scripts/deploy.sh $(ENVIRONMENT)

clean:
	@echo "Cleaning up..."
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name node_modules -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	docker system prune -f
```
