"""
Base Model
Base class for all database models
"""

from datetime import datetime
from typing import Any

from sqlalchemy import Column, DateTime, Integer, MetaData
from sqlalchemy.ext.declarative import declared_attr
from sqlalchemy.orm import DeclarativeBase


# Naming convention for constraints
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

metadata = MetaData(naming_convention=NAMING_CONVENTION)


class Base(DeclarativeBase):
    """Base class for all models"""

    metadata = metadata

    @declared_attr
    def __tablename__(cls) -> str:
        """Generate table name from class name"""
        return cls.__name__.lower() + "s"

    def to_dict(self) -> dict[str, Any]:
        """Convert model instance to dictionary"""
        return {column.name: getattr(self, column.name) for column in self.__table__.columns}


class TimestampMixin:
    """Mixin to add created_at and updated_at timestamps"""

    created_at = Column(
        DateTime, default=datetime.utcnow, nullable=False, comment="Record creation timestamp"
    )

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
        comment="Record last update timestamp",
    )


class SoftDeleteMixin:
    """Mixin to add soft delete functionality"""

    deleted_at = Column(
        DateTime, nullable=True, comment="Record deletion timestamp (NULL if active)"
    )

    @property
    def is_deleted(self) -> bool:
        """Check if record is soft deleted"""
        return self.deleted_at is not None

    def soft_delete(self) -> None:
        """Mark record as deleted"""
        self.deleted_at = datetime.utcnow()

    def restore(self) -> None:
        """Restore soft deleted record"""
        self.deleted_at = None
