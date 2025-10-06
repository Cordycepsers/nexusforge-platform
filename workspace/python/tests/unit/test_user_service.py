"""
User Service Unit Tests
Test user service business logic
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.services.user_service import UserService


@pytest.mark.asyncio
async def test_create_user(test_db: AsyncSession, sample_user_data):
    """Test user creation"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    user = await user_service.create_user(user_data)

    assert user.id is not None
    assert user.email == sample_user_data["email"]
    assert user.username == sample_user_data["username"]
    assert user.full_name == sample_user_data["full_name"]
    assert user.is_active is True
    assert user.is_verified is False
    assert user.hashed_password != sample_user_data["password"]


@pytest.mark.asyncio
async def test_create_duplicate_email(test_db: AsyncSession, sample_user_data):
    """Test creating user with duplicate email"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    # Create first user
    await user_service.create_user(user_data)

    # Try to create duplicate
    with pytest.raises(ValueError, match="Email .* is already registered"):
        await user_service.create_user(user_data)


@pytest.mark.asyncio
async def test_create_duplicate_username(test_db: AsyncSession, sample_user_data):
    """Test creating user with duplicate username"""
    user_service = UserService(test_db)

    # Create first user
    user_data1 = UserCreate(**sample_user_data)
    await user_service.create_user(user_data1)

    # Try to create user with different email but same username
    user_data2 = UserCreate(
        email="another@example.com",
        username=sample_user_data["username"],
        password=sample_user_data["password"],
        full_name="Another User",
    )

    with pytest.raises(ValueError, match="Username .* is already taken"):
        await user_service.create_user(user_data2)


@pytest.mark.asyncio
async def test_get_user_by_id(test_db: AsyncSession, sample_user_data):
    """Test getting user by ID"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    # Create user
    created_user = await user_service.create_user(user_data)

    # Get user by ID
    user = await user_service.get_user_by_id(created_user.id)

    assert user is not None
    assert user.id == created_user.id
    assert user.email == created_user.email


@pytest.mark.asyncio
async def test_get_user_by_email(test_db: AsyncSession, sample_user_data):
    """Test getting user by email"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    # Create user
    await user_service.create_user(user_data)

    # Get user by email
    user = await user_service.get_user_by_email(sample_user_data["email"])

    assert user is not None
    assert user.email == sample_user_data["email"]


@pytest.mark.asyncio
async def test_get_user_by_username(test_db: AsyncSession, sample_user_data):
    """Test getting user by username"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    # Create user
    await user_service.create_user(user_data)

    # Get user by username
    user = await user_service.get_user_by_username(sample_user_data["username"])

    assert user is not None
    assert user.username == sample_user_data["username"]


@pytest.mark.asyncio
async def test_update_user(test_db: AsyncSession, sample_user_data):
    """Test updating user"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    # Create user
    user = await user_service.create_user(user_data)

    # Update user
    update_data = UserUpdate(full_name="Updated Name")
    updated_user = await user_service.update_user(user.id, update_data)

    assert updated_user is not None
    assert updated_user.full_name == "Updated Name"
    assert updated_user.email == user.email  # Unchanged


@pytest.mark.asyncio
async def test_delete_user(test_db: AsyncSession, sample_user_data):
    """Test soft deleting user"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    # Create user
    user = await user_service.create_user(user_data)

    # Delete user
    success = await user_service.delete_user(user.id)

    assert success is True

    # Verify user is soft deleted
    deleted_user = await user_service.get_user_by_id(user.id)
    assert deleted_user is None  # Should not be found (soft deleted)


@pytest.mark.asyncio
async def test_get_users_pagination(test_db: AsyncSession):
    """Test getting users with pagination"""
    user_service = UserService(test_db)

    # Create multiple users
    for i in range(5):
        user_data = UserCreate(
            email=f"user{i}@example.com",
            username=f"user{i}",
            password="TestPass123!",
            full_name=f"User {i}",
        )
        await user_service.create_user(user_data)

    # Get first page
    users, total = await user_service.get_users(skip=0, limit=2)

    assert len(users) == 2
    assert total == 5

    # Get second page
    users, total = await user_service.get_users(skip=2, limit=2)

    assert len(users) == 2
    assert total == 5


@pytest.mark.asyncio
async def test_verify_user_email(test_db: AsyncSession, sample_user_data):
    """Test verifying user email"""
    user_service = UserService(test_db)
    user_data = UserCreate(**sample_user_data)

    # Create user
    user = await user_service.create_user(user_data)
    assert user.is_verified is False

    # Verify email
    verified_user = await user_service.verify_user_email(user.id)

    assert verified_user is not None
    assert verified_user.is_verified is True
    assert verified_user.email_verified_at is not None
