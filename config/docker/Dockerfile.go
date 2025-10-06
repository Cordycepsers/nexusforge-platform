# ============================================
# Go Service Dockerfile (Gin Framework)
# Multi-stage build for production deployment
# ============================================

# ============================================
# Stage 1: Builder
# ============================================
FROM golang:1.18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /build

# Copy go mod files
COPY workspace/go/go.mod workspace/go/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY workspace/go/ .

# Build the application
# CGO_ENABLED=0: Build static binary
# -ldflags: Strip debug information and reduce binary size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o /build/app \
    cmd/api/main.go

# ============================================
# Stage 2: Runtime
# ============================================
FROM alpine:3.18

# Set environment variables
ENV ENV=production \
    PORT=8080

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    tzdata

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S -u 1001 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=appuser:appuser /build/app .

# Copy timezone data for time operations
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
CMD ["./app"]
