"""
Database Utilities
SQLAlchemy async database connection and session management
"""

from typing import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    create_async_engine,
    AsyncSession,
    async_sessionmaker,
    AsyncEngine,
)
from sqlalchemy.pool import NullPool, QueuePool

from app.config import settings
from app.utils.logger import get_logger


logger = get_logger(__name__)


class DatabaseManager:
    """Database connection manager"""

    def __init__(self):
        self._engine: AsyncEngine = None
        self._session_factory: async_sessionmaker = None

    async def connect(self) -> None:
        """Initialize database connection"""
        if self._engine:
            logger.warning("Database already connected")
            return

        # Create async engine
        self._engine = create_async_engine(
            settings.database_url,
            echo=settings.database_echo,
            pool_size=settings.database_pool_size,
            max_overflow=settings.database_max_overflow,
            poolclass=QueuePool if not settings.debug else NullPool,
            pool_pre_ping=True,  # Verify connections before using
            pool_recycle=3600,  # Recycle connections after 1 hour
        )

        # Create session factory
        self._session_factory = async_sessionmaker(
            bind=self._engine,
            class_=AsyncSession,
            expire_on_commit=False,
            autocommit=False,
            autoflush=False,
        )

        logger.info("Database connection established")

    async def disconnect(self) -> None:
        """Close database connection"""
        if not self._engine:
            logger.warning("Database not connected")
            return

        await self._engine.dispose()
        self._engine = None
        self._session_factory = None

        logger.info("Database connection closed")

    @asynccontextmanager
    async def session(self) -> AsyncGenerator[AsyncSession, None]:
        """
        Context manager for database sessions

        Usage:
            async with database_manager.session() as db:
                result = await db.execute(query)
        """
        if not self._session_factory:
            raise RuntimeError("Database not connected. Call connect() first.")

        async with self._session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception as e:
                await session.rollback()
                logger.error(f"Database session error: {e}", exc_info=True)
                raise
            finally:
                await session.close()

    def get_session_factory(self) -> async_sessionmaker:
        """Get session factory for dependency injection"""
        if not self._session_factory:
            raise RuntimeError("Database not connected. Call connect() first.")
        return self._session_factory

    @property
    def engine(self) -> AsyncEngine:
        """Get database engine"""
        return self._engine


# Global database manager instance
database_manager = DatabaseManager()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency for getting database sessions in FastAPI

    Usage:
        @app.get("/items")
        async def get_items(db: AsyncSession = Depends(get_db)):
            result = await db.execute(select(Item))
            return result.scalars().all()
    """
    session_factory = database_manager.get_session_factory()

    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception as e:
            await session.rollback()
            logger.error(f"Database transaction error: {e}", exc_info=True)
            raise
        finally:
            await session.close()
