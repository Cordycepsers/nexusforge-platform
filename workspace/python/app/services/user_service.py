"""
User Service
Business logic for user management
"""

from typing import Optional, List, Tuple
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.utils.security import get_password_hash
from app.utils.logger import get_logger
from app.utils.cache import cache_manager


logger = get_logger(__name__)


class UserService:
    """Service class for user operations"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_user(self, user_data: UserCreate) -> User:
        """
        Create a new user

        Args:
            user_data: User creation data

        Returns:
            Created user object

        Raises:
            ValueError: If email or username already exists
        """
        # Check if email exists
        existing_user = await self.get_user_by_email(user_data.email)
        if existing_user:
            raise ValueError(f"Email '{user_data.email}' is already registered")

        # Check if username exists
        existing_user = await self.get_user_by_username(user_data.username)
        if existing_user:
            raise ValueError(f"Username '{user_data.username}' is already taken")

        # Hash password
        hashed_password = get_password_hash(user_data.password)

        # Create user
        user = User(
            email=user_data.email,
            username=user_data.username,
            full_name=user_data.full_name,
            hashed_password=hashed_password,
            is_active=True,
            is_verified=False,
            is_superuser=False,
        )

        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)

        logger.info(f"User created: {user.username} (ID: {user.id})")

        return user

    async def get_user_by_id(self, user_id: int) -> Optional[User]:
        """
        Get user by ID

        Args:
            user_id: User ID

        Returns:
            User object or None
        """
        # Try cache first
        cache_key = f"user:{user_id}"
        cached_user = await cache_manager.get(cache_key)

        if cached_user:
            logger.debug(f"User {user_id} found in cache")
            return cached_user

        # Query database
        result = await self.db.execute(
            select(User).where(User.id == user_id, User.deleted_at.is_(None))
        )
        user = result.scalar_one_or_none()

        # Cache result
        if user:
            await cache_manager.set(cache_key, user, ttl=300)  # 5 minutes

        return user

    async def get_user_by_email(self, email: str) -> Optional[User]:
        """
        Get user by email

        Args:
            email: User email

        Returns:
            User object or None
        """
        result = await self.db.execute(
            select(User).where(User.email == email.lower(), User.deleted_at.is_(None))
        )
        return result.scalar_one_or_none()

    async def get_user_by_username(self, username: str) -> Optional[User]:
        """
        Get user by username

        Args:
            username: Username

        Returns:
            User object or None
        """
        result = await self.db.execute(
            select(User).where(User.username == username.lower(), User.deleted_at.is_(None))
        )
        return result.scalar_one_or_none()

    async def get_users(
        self, skip: int = 0, limit: int = 100, is_active: Optional[bool] = None
    ) -> Tuple[List[User], int]:
        """
        Get paginated list of users

        Args:
            skip: Number of records to skip
            limit: Maximum number of records to return
            is_active: Filter by active status

        Returns:
            Tuple of (users list, total count)
        """
        # Build query
        query = select(User).where(User.deleted_at.is_(None))

        if is_active is not None:
            query = query.where(User.is_active == is_active)

        # Get total count
        count_query = select(func.count()).select_from(User).where(User.deleted_at.is_(None))
        if is_active is not None:
            count_query = count_query.where(User.is_active == is_active)

        total_result = await self.db.execute(count_query)
        total = total_result.scalar()

        # Get users with pagination
        query = query.offset(skip).limit(limit).order_by(User.created_at.desc())
        result = await self.db.execute(query)
        users = result.scalars().all()

        return list(users), total

    async def update_user(self, user_id: int, user_data: UserUpdate) -> Optional[User]:
        """
        Update user information

        Args:
            user_id: User ID
            user_data: Update data

        Returns:
            Updated user object or None

        Raises:
            ValueError: If email or username already exists
        """
        user = await self.get_user_by_id(user_id)
        if not user:
            return None

        # Check email uniqueness
        if user_data.email and user_data.email != user.email:
            existing_user = await self.get_user_by_email(user_data.email)
            if existing_user:
                raise ValueError(f"Email '{user_data.email}' is already registered")
            user.email = user_data.email

        # Check username uniqueness
        if user_data.username and user_data.username != user.username:
            existing_user = await self.get_user_by_username(user_data.username)
            if existing_user:
                raise ValueError(f"Username '{user_data.username}' is already taken")
            user.username = user_data.username

        # Update other fields
        if user_data.full_name is not None:
            user.full_name = user_data.full_name

        if user_data.password:
            user.hashed_password = get_password_hash(user_data.password)

        if user_data.is_active is not None:
            user.is_active = user_data.is_active

        await self.db.commit()
        await self.db.refresh(user)

        # Invalidate cache
        cache_key = f"user:{user_id}"
        await cache_manager.delete(cache_key)

        logger.info(f"User updated: {user.username} (ID: {user.id})")

        return user

    async def delete_user(self, user_id: int) -> bool:
        """
        Soft delete user

        Args:
            user_id: User ID

        Returns:
            True if deleted, False if not found
        """
        user = await self.get_user_by_id(user_id)
        if not user:
            return False

        # Soft delete
        user.soft_delete()
        user.is_active = False

        await self.db.commit()

        # Invalidate cache
        cache_key = f"user:{user_id}"
        await cache_manager.delete(cache_key)

        logger.info(f"User deleted: {user.username} (ID: {user.id})")

        return True

    async def verify_user_email(self, user_id: int) -> Optional[User]:
        """
        Verify user email

        Args:
            user_id: User ID

        Returns:
            Updated user or None
        """
        user = await self.get_user_by_id(user_id)
        if not user:
            return None

        user.verify_email()
        await self.db.commit()
        await self.db.refresh(user)

        # Invalidate cache
        cache_key = f"user:{user_id}"
        await cache_manager.delete(cache_key)

        logger.info(f"User email verified: {user.username} (ID: {user.id})")

        return user
