"""
Health Check Tests
Test health check endpoints
"""

import pytest
from httpx import AsyncClient
from fastapi import status


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """Test basic health check endpoint"""
    response = await client.get("/health")

    assert response.status_code == status.HTTP_200_OK
    data = response.json()

    assert data["status"] == "healthy"
    assert "service" in data
    assert "version" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_liveness_check(client: AsyncClient):
    """Test liveness check endpoint"""
    response = await client.get("/health/live")

    assert response.status_code == status.HTTP_200_OK
    data = response.json()

    assert data["status"] == "alive"
    assert "service" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_readiness_check(client: AsyncClient):
    """Test readiness check endpoint"""
    response = await client.get("/health/ready")

    # May be 200 or 503 depending on Redis connection
    assert response.status_code in [status.HTTP_200_OK, status.HTTP_503_SERVICE_UNAVAILABLE]
    data = response.json()

    assert "status" in data
    assert "checks" in data
    assert "database" in data["checks"]
    assert "redis" in data["checks"]


@pytest.mark.asyncio
async def test_root_endpoint(client: AsyncClient):
    """Test root endpoint"""
    response = await client.get("/")

    assert response.status_code == status.HTTP_200_OK
    data = response.json()

    assert "service" in data
    assert "version" in data
    assert "status" in data
    assert data["status"] == "running"
