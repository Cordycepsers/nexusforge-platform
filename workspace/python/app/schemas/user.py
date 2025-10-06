"""
User Schemas
Pydantic models for user data validation and serialization
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field, field_validator, ConfigDict


class UserBase(BaseModel):
    """Base user schema with common fields"""

    email: EmailStr = Field(..., description="User email address")
    username: str = Field(..., min_length=3, max_length=100, description="Username")
    full_name: Optional[str] = Field(None, max_length=255, description="Full name")

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        """Validate username format"""
        if not v.replace("_", "").isalnum():
            raise ValueError("Username can only contain letters, numbers, and underscores")
        return v.lower()


class UserCreate(UserBase):
    """Schema for creating a new user"""

    password: str = Field(
        ..., min_length=8, max_length=100, description="User password (min 8 characters)"
    )

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        """Validate password strength"""
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.islower() for c in v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one digit")
        return v


class UserUpdate(BaseModel):
    """Schema for updating user information"""

    model_config = ConfigDict(extra="forbid")

    email: Optional[EmailStr] = Field(None, description="User email address")
    username: Optional[str] = Field(None, min_length=3, max_length=100, description="Username")
    full_name: Optional[str] = Field(None, max_length=255, description="Full name")
    password: Optional[str] = Field(None, min_length=8, max_length=100, description="New password")
    is_active: Optional[bool] = Field(None, description="Active status")

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: Optional[str]) -> Optional[str]:
        """Validate username format"""
        if v and not v.replace("_", "").isalnum():
            raise ValueError("Username can only contain letters, numbers, and underscores")
        return v.lower() if v else v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: Optional[str]) -> Optional[str]:
        """Validate password strength"""
        if v:
            if len(v) < 8:
                raise ValueError("Password must be at least 8 characters")
            if not any(c.isupper() for c in v):
                raise ValueError("Password must contain at least one uppercase letter")
            if not any(c.islower() for c in v):
                raise ValueError("Password must contain at least one lowercase letter")
            if not any(c.isdigit() for c in v):
                raise ValueError("Password must contain at least one digit")
        return v


class UserResponse(BaseModel):
    """Schema for user response"""

    model_config = ConfigDict(from_attributes=True)

    id: int = Field(..., description="User ID")
    email: EmailStr = Field(..., description="User email")
    username: str = Field(..., description="Username")
    full_name: Optional[str] = Field(None, description="Full name")
    is_active: bool = Field(..., description="Active status")
    is_verified: bool = Field(..., description="Email verification status")
    is_superuser: bool = Field(..., description="Superuser status")
    created_at: datetime = Field(..., description="Creation timestamp")
    updated_at: datetime = Field(..., description="Last update timestamp")
    last_login_at: Optional[datetime] = Field(None, description="Last login timestamp")


class UserListResponse(BaseModel):
    """Schema for paginated user list response"""

    users: List[UserResponse] = Field(..., description="List of users")
    total: int = Field(..., description="Total number of users")
    skip: int = Field(..., description="Number of skipped records")
    limit: int = Field(..., description="Maximum number of records returned")

    @property
    def has_more(self) -> bool:
        """Check if there are more records"""
        return self.skip + len(self.users) < self.total


class Token(BaseModel):
    """JWT token response schema"""

    access_token: str = Field(..., description="JWT access token")
    token_type: str = Field(default="bearer", description="Token type")
    expires_in: int = Field(..., description="Token expiration in seconds")


class TokenData(BaseModel):
    """Token payload data"""

    user_id: Optional[int] = None
    username: Optional[str] = None
    email: Optional[str] = None
