"""
Redis Cache Utilities
Redis connection and caching functionality
"""

import json
import pickle
from typing import Any, Optional, Union
from contextlib import asynccontextmanager

import redis.asyncio as redis
from redis.asyncio import Redis, ConnectionPool

from app.config import settings
from app.utils.logger import get_logger


logger = get_logger(__name__)


class CacheManager:
    """Redis cache manager"""

    def __init__(self):
        self._redis: Redis = None
        self._pool: ConnectionPool = None

    async def connect(self) -> None:
        """Initialize Redis connection"""
        if self._redis:
            logger.warning("Redis already connected")
            return

        # Create connection pool
        self._pool = ConnectionPool.from_url(
            settings.redis_url,
            max_connections=settings.redis_max_connections,
            decode_responses=settings.redis_decode_responses,
            socket_keepalive=settings.redis_socket_keepalive,
            socket_connect_timeout=5,
            retry_on_timeout=True,
        )

        # Create Redis client
        self._redis = Redis(connection_pool=self._pool)

        # Test connection
        await self._redis.ping()

        logger.info("Redis connection established")

    async def disconnect(self) -> None:
        """Close Redis connection"""
        if not self._redis:
            logger.warning("Redis not connected")
            return

        await self._redis.close()
        await self._pool.disconnect()

        self._redis = None
        self._pool = None

        logger.info("Redis connection closed")

    def get_client(self) -> Redis:
        """Get Redis client"""
        if not self._redis:
            raise RuntimeError("Redis not connected. Call connect() first.")
        return self._redis

    async def get(self, key: str, default: Any = None) -> Any:
        """
        Get value from cache

        Args:
            key: Cache key
            default: Default value if key not found

        Returns:
            Cached value or default
        """
        if not settings.enable_cache:
            return default

        try:
            value = await self._redis.get(key)
            if value is None:
                return default

            # Try to deserialize JSON
            try:
                return json.loads(value)
            except (json.JSONDecodeError, TypeError):
                # If not JSON, try pickle
                try:
                    return pickle.loads(value)
                except (pickle.PickleError, TypeError):
                    # Return raw value
                    return value
        except Exception as e:
            logger.error(f"Cache get error for key '{key}': {e}")
            return default

    async def set(self, key: str, value: Any, ttl: Optional[int] = None) -> bool:
        """
        Set value in cache

        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds (optional)

        Returns:
            True if successful
        """
        if not settings.enable_cache:
            return False

        try:
            # Serialize value
            if isinstance(value, (dict, list, tuple)):
                serialized = json.dumps(value)
            elif isinstance(value, (str, int, float, bool)):
                serialized = value
            else:
                # Use pickle for complex objects
                serialized = pickle.dumps(value)

            # Set with TTL
            if ttl:
                await self._redis.setex(key, ttl, serialized)
            else:
                await self._redis.set(key, serialized)

            return True
        except Exception as e:
            logger.error(f"Cache set error for key '{key}': {e}")
            return False

    async def delete(self, key: str) -> bool:
        """
        Delete key from cache

        Args:
            key: Cache key

        Returns:
            True if deleted
        """
        if not settings.enable_cache:
            return False

        try:
            result = await self._redis.delete(key)
            return result > 0
        except Exception as e:
            logger.error(f"Cache delete error for key '{key}': {e}")
            return False

    async def exists(self, key: str) -> bool:
        """
        Check if key exists in cache

        Args:
            key: Cache key

        Returns:
            True if exists
        """
        if not settings.enable_cache:
            return False

        try:
            result = await self._redis.exists(key)
            return result > 0
        except Exception as e:
            logger.error(f"Cache exists error for key '{key}': {e}")
            return False

    async def clear_pattern(self, pattern: str) -> int:
        """
        Delete all keys matching pattern

        Args:
            pattern: Key pattern (e.g., 'user:*')

        Returns:
            Number of keys deleted
        """
        if not settings.enable_cache:
            return 0

        try:
            keys = []
            async for key in self._redis.scan_iter(match=pattern):
                keys.append(key)

            if keys:
                return await self._redis.delete(*keys)
            return 0
        except Exception as e:
            logger.error(f"Cache clear pattern error for '{pattern}': {e}")
            return 0

    async def increment(self, key: str, amount: int = 1) -> int:
        """
        Increment counter

        Args:
            key: Cache key
            amount: Increment amount

        Returns:
            New value
        """
        try:
            return await self._redis.incrby(key, amount)
        except Exception as e:
            logger.error(f"Cache increment error for key '{key}': {e}")
            return 0

    async def expire(self, key: str, ttl: int) -> bool:
        """
        Set expiration on key

        Args:
            key: Cache key
            ttl: Time to live in seconds

        Returns:
            True if successful
        """
        try:
            return await self._redis.expire(key, ttl)
        except Exception as e:
            logger.error(f"Cache expire error for key '{key}': {e}")
            return False


# Global cache manager instance
cache_manager = CacheManager()


async def get_redis() -> Redis:
    """
    Dependency for getting Redis client in FastAPI

    Usage:
        @app.get("/items")
        async def get_items(redis: Redis = Depends(get_redis)):
            await redis.set("key", "value")
    """
    return cache_manager.get_client()
