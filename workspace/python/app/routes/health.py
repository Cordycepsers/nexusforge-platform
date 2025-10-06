"""
Health Check Routes
Endpoints for service health monitoring
"""

from datetime import datetime
from typing import Dict, Any

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from redis.asyncio import Redis

from app.utils.database import get_db
from app.utils.cache import get_redis
from app.config import settings
from app.utils.logger import get_logger


router = APIRouter()
logger = get_logger(__name__)


@router.get(
    "/health",
    status_code=status.HTTP_200_OK,
    response_model=Dict[str, Any],
    summary="Basic Health Check",
    description="Check if the service is running",
)
async def health_check() -> Dict[str, Any]:
    """
    Basic health check endpoint
    Returns service status without checking dependencies
    """
    return {
        "status": "healthy",
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
        "timestamp": datetime.utcnow().isoformat(),
    }


@router.get(
    "/health/ready",
    status_code=status.HTTP_200_OK,
    response_model=Dict[str, Any],
    summary="Readiness Check",
    description="Check if service is ready to accept traffic",
)
async def readiness_check(
    db: AsyncSession = Depends(get_db), redis: Redis = Depends(get_redis)
) -> Dict[str, Any]:
    """
    Readiness check endpoint
    Verifies all dependencies are available
    """
    checks = {
        "database": False,
        "redis": False,
    }

    # Check database connection
    try:
        await db.execute("SELECT 1")
        checks["database"] = True
    except Exception as e:
        logger.error(f"Database health check failed: {e}")

    # Check Redis connection
    try:
        await redis.ping()
        checks["redis"] = True
    except Exception as e:
        logger.error(f"Redis health check failed: {e}")

    # Determine overall status
    all_healthy = all(checks.values())
    status_code = status.HTTP_200_OK if all_healthy else status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "status": "ready" if all_healthy else "not_ready",
        "checks": checks,
        "service": settings.app_name,
        "version": settings.app_version,
        "timestamp": datetime.utcnow().isoformat(),
    }


@router.get(
    "/health/live",
    status_code=status.HTTP_200_OK,
    response_model=Dict[str, Any],
    summary="Liveness Check",
    description="Check if service is alive (for Kubernetes)",
)
async def liveness_check() -> Dict[str, Any]:
    """
    Liveness check endpoint
    Simple check to verify the service process is running
    """
    return {
        "status": "alive",
        "service": settings.app_name,
        "timestamp": datetime.utcnow().isoformat(),
    }
