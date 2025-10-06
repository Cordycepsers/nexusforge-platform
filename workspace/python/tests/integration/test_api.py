"""
API Integration Tests
Test API endpoints end-to-end
"""

import pytest
from httpx import AsyncClient
from fastapi import status


@pytest.mark.asyncio
async def test_create_user_api(client: AsyncClient, sample_user_data):
    """Test creating user via API"""
    response = await client.post("/api/v1/users", json=sample_user_data)

    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()

    assert "id" in data
    assert data["email"] == sample_user_data["email"]
    assert data["username"] == sample_user_data["username"]
    assert data["is_active"] is True
    assert "password" not in data
    assert "hashed_password" not in data


@pytest.mark.asyncio
async def test_create_user_invalid_email(client: AsyncClient):
    """Test creating user with invalid email"""
    user_data = {
        "email": "invalid-email",
        "username": "testuser",
        "password": "TestPass123!",
        "full_name": "Test User",
    }

    response = await client.post("/api/v1/users", json=user_data)

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_create_user_weak_password(client: AsyncClient):
    """Test creating user with weak password"""
    user_data = {
        "email": "test@example.com",
        "username": "testuser",
        "password": "weak",
        "full_name": "Test User",
    }

    response = await client.post("/api/v1/users", json=user_data)

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_create_duplicate_user(client: AsyncClient, sample_user_data):
    """Test creating duplicate user"""
    # Create first user
    await client.post("/api/v1/users", json=sample_user_data)

    # Try to create duplicate
    response = await client.post("/api/v1/users", json=sample_user_data)

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "already registered" in response.json()["detail"]


@pytest.mark.asyncio
async def test_list_users_requires_auth(client: AsyncClient):
    """Test that listing users requires authentication"""
    response = await client.get("/api/v1/users")

    assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.asyncio
async def test_get_user_requires_auth(client: AsyncClient):
    """Test that getting user requires authentication"""
    response = await client.get("/api/v1/users/1")

    assert response.status_code == status.HTTP_403_FORBIDDEN
