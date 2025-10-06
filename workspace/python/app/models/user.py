"""
User Model
SQLAlchemy model for user management
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, Column, Integer, String, DateTime, Index
from sqlalchemy.orm import validates

from app.models.base import Base, TimestampMixin, SoftDeleteMixin


class User(Base, TimestampMixin, SoftDeleteMixin):
    """
    User model for authentication and authorization
    """

    __tablename__ = "users"

    # Primary Key
    id = Column(
        Integer, primary_key=True, index=True, autoincrement=True, comment="User unique identifier"
    )

    # Authentication
    email = Column(
        String(255), unique=True, nullable=False, index=True, comment="User email address (unique)"
    )

    username = Column(
        String(100), unique=True, nullable=False, index=True, comment="User username (unique)"
    )

    hashed_password = Column(String(255), nullable=False, comment="Bcrypt hashed password")

    # Profile Information
    full_name = Column(String(255), nullable=True, comment="User full name")

    # Status Flags
    is_active = Column(Boolean, default=True, nullable=False, comment="Account active status")

    is_verified = Column(
        Boolean, default=False, nullable=False, comment="Email verification status"
    )

    is_superuser = Column(Boolean, default=False, nullable=False, comment="Superuser/admin status")

    # Timestamps
    last_login_at = Column(DateTime, nullable=True, comment="Last login timestamp")

    email_verified_at = Column(DateTime, nullable=True, comment="Email verification timestamp")

    # Indexes
    __table_args__ = (
        Index("ix_users_email_active", "email", "is_active"),
        Index("ix_users_username_active", "username", "is_active"),
        Index("ix_users_created_at", "created_at"),
        {"comment": "User accounts table"},
    )

    @validates("email")
    def validate_email(self, key: str, email: str) -> str:
        """Validate and normalize email"""
        if not email or "@" not in email:
            raise ValueError("Invalid email address")
        return email.lower().strip()

    @validates("username")
    def validate_username(self, key: str, username: str) -> str:
        """Validate and normalize username"""
        if not username or len(username) < 3:
            raise ValueError("Username must be at least 3 characters")
        if not username.isalnum() and "_" not in username:
            raise ValueError("Username can only contain letters, numbers, and underscores")
        return username.lower().strip()

    def update_last_login(self) -> None:
        """Update last login timestamp"""
        self.last_login_at = datetime.utcnow()

    def verify_email(self) -> None:
        """Mark email as verified"""
        self.is_verified = True
        self.email_verified_at = datetime.utcnow()

    def __repr__(self) -> str:
        return f"<User(id={self.id}, username='{self.username}', email='{self.email}')>"

    def to_dict(self, include_sensitive: bool = False) -> dict:
        """Convert user to dictionary (excluding sensitive data by default)"""
        data = {
            "id": self.id,
            "email": self.email,
            "username": self.username,
            "full_name": self.full_name,
            "is_active": self.is_active,
            "is_verified": self.is_verified,
            "is_superuser": self.is_superuser,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "last_login_at": self.last_login_at.isoformat() if self.last_login_at else None,
        }

        if include_sensitive:
            data["hashed_password"] = self.hashed_password
            data["deleted_at"] = self.deleted_at.isoformat() if self.deleted_at else None

        return data
