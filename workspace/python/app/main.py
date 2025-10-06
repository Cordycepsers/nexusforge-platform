"""
NexusForge Platform - Main Application
FastAPI application with full production features
"""

import time
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import make_asgi_app

from app.config import settings
from app.utils.logger import get_logger, log_request
from app.utils.database import database_manager
from app.routes import health, api
from app.middleware.rate_limit import RateLimitMiddleware


# Initialize logger
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """
    Application lifespan manager
    Handles startup and shutdown events
    """
    # Startup
    logger.info(
        "Starting NexusForge Python Service",
        extra={"environment": settings.environment, "version": settings.app_version},
    )

    try:
        # Initialize database
        await database_manager.connect()
        logger.info("Database connection established")

        # Initialize Redis
        from app.utils.cache import cache_manager

        await cache_manager.connect()
        logger.info("Redis connection established")

        logger.info("Application startup complete")

        yield

    finally:
        # Shutdown
        logger.info("Shutting down application")

        # Close database connections
        await database_manager.disconnect()
        logger.info("Database connection closed")

        # Close Redis connections
        from app.utils.cache import cache_manager

        await cache_manager.disconnect()
        logger.info("Redis connection closed")

        logger.info("Application shutdown complete")


# Create FastAPI application
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="NexusForge Platform - Python Microservice",
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
    openapi_url="/openapi.json" if not settings.is_production else None,
    lifespan=lifespan,
)


# ============================================
# Middleware Configuration
# ============================================

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# GZip Compression
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Rate Limiting
if settings.rate_limit_enabled:
    app.add_middleware(RateLimitMiddleware, requests_per_minute=settings.rate_limit_per_minute)


# ============================================
# Request Logging Middleware
# ============================================


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all incoming requests"""
    start_time = time.time()

    # Process request
    response = await call_next(request)

    # Calculate duration
    duration = time.time() - start_time

    # Log request details
    log_request(
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration=duration,
        client_ip=request.client.host if request.client else "unknown",
    )

    # Add custom headers
    response.headers["X-Process-Time"] = str(duration)
    response.headers["X-Service-Version"] = settings.app_version

    return response


# ============================================
# Exception Handlers
# ============================================


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(
        "Unhandled exception",
        extra={"error": str(exc), "path": request.url.path, "method": request.method},
        exc_info=True,
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Internal server error",
            "message": "An unexpected error occurred",
            "path": request.url.path,
        },
    )


# ============================================
# Router Registration
# ============================================

# Health check routes
app.include_router(health.router, prefix="", tags=["Health"])

# API routes
app.include_router(api.router, prefix="/api/v1", tags=["API"])


# ============================================
# Prometheus Metrics
# ============================================

if settings.enable_metrics:
    # Mount Prometheus metrics endpoint
    metrics_app = make_asgi_app()
    app.mount("/metrics", metrics_app)


# ============================================
# Root Endpoint
# ============================================


@app.get("/", include_in_schema=False)
async def root():
    """Root endpoint"""
    return {
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
        "status": "running",
        "endpoints": {
            "health": "/health",
            "docs": "/docs" if not settings.is_production else "disabled",
            "metrics": "/metrics" if settings.enable_metrics else "disabled",
        },
    }


# ============================================
# Application Entry Point
# ============================================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.reload,
        workers=1 if settings.reload else settings.workers,
        log_level=settings.log_level.lower(),
        access_log=True,
    )
