"""
API Routes
Main API endpoints for user management
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.utils.database import get_db
from app.services.user_service import UserService
from app.schemas.user import UserCreate, UserUpdate, UserResponse, UserListResponse
from app.utils.auth import get_current_user, get_current_active_user
from app.models.user import User
from app.utils.logger import get_logger


router = APIRouter()
logger = get_logger(__name__)


@router.post(
    "/users",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create User",
    description="Create a new user account",
)
async def create_user(user_data: UserCreate, db: AsyncSession = Depends(get_db)) -> UserResponse:
    """Create a new user"""
    user_service = UserService(db)

    try:
        user = await user_service.create_user(user_data)
        logger.info(f"User created: {user.username}")
        return UserResponse.model_validate(user)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get(
    "/users",
    response_model=UserListResponse,
    summary="List Users",
    description="Get paginated list of users",
)
async def list_users(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Number of records to return"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> UserListResponse:
    """Get list of users with pagination"""
    user_service = UserService(db)

    users, total = await user_service.get_users(skip=skip, limit=limit, is_active=is_active)

    return UserListResponse(
        users=[UserResponse.model_validate(user) for user in users],
        total=total,
        skip=skip,
        limit=limit,
    )


@router.get(
    "/users/{user_id}",
    response_model=UserResponse,
    summary="Get User",
    description="Get user by ID",
)
async def get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> UserResponse:
    """Get user by ID"""
    user_service = UserService(db)

    user = await user_service.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"User with ID {user_id} not found"
        )

    return UserResponse.model_validate(user)


@router.put(
    "/users/{user_id}",
    response_model=UserResponse,
    summary="Update User",
    description="Update user information",
)
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> UserResponse:
    """Update user"""
    # Check if user can update this account
    if current_user.id != user_id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this user"
        )

    user_service = UserService(db)

    try:
        user = await user_service.update_user(user_id, user_data)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail=f"User with ID {user_id} not found"
            )

        logger.info(f"User updated: {user.username}")
        return UserResponse.model_validate(user)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete(
    "/users/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete User",
    description="Soft delete a user",
)
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> None:
    """Delete user (soft delete)"""
    # Only superusers can delete users
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Only superusers can delete users"
        )

    user_service = UserService(db)

    success = await user_service.delete_user(user_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"User with ID {user_id} not found"
        )

    logger.info(f"User deleted: ID {user_id}")


@router.get(
    "/users/me",
    response_model=UserResponse,
    summary="Get Current User",
    description="Get current authenticated user",
)
async def get_current_user_info(
    current_user: User = Depends(get_current_active_user),
) -> UserResponse:
    """Get current user information"""
    return UserResponse.model_validate(current_user)
