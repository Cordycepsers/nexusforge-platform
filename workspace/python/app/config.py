"""
Configuration Management
Centralized configuration using Pydantic Settings
"""

from typing import List, Optional
from functools import lru_cache

from pydantic import Field, field_validator, PostgresDsn, RedisDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings with environment variable support"""

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", case_sensitive=False, extra="ignore"
    )

    # Application
    app_name: str = Field(default="NexusForge Python Service", description="Application name")
    app_version: str = Field(default="1.0.0", description="Application version")
    environment: str = Field(
        default="development", description="Environment (development, staging, production)"
    )
    debug: bool = Field(default=False, description="Debug mode")
    log_level: str = Field(default="INFO", description="Logging level")

    # Server
    host: str = Field(default="0.0.0.0", description="Server host")
    port: int = Field(default=8000, description="Server port")
    workers: int = Field(default=4, description="Number of workers")
    reload: bool = Field(default=False, description="Auto-reload on code changes")

    # Database
    database_url: str = Field(
        default="postgresql+asyncpg://nexusforge:password@localhost:5432/nexusforge_dev",
        description="Database connection URL",
    )
    database_pool_size: int = Field(default=20, description="Database connection pool size")
    database_max_overflow: int = Field(default=10, description="Database max overflow connections")
    database_echo: bool = Field(default=False, description="Echo SQL queries")

    # Redis
    redis_url: str = Field(
        default="redis://:password@localhost:6379/0", description="Redis connection URL"
    )
    redis_max_connections: int = Field(default=50, description="Redis max connections")
    redis_decode_responses: bool = Field(default=True, description="Decode Redis responses")
    redis_socket_keepalive: bool = Field(default=True, description="Keep Redis socket alive")

    # JWT Authentication
    jwt_secret_key: str = Field(default="your-secret-key", description="JWT secret key")
    jwt_algorithm: str = Field(default="HS256", description="JWT algorithm")
    jwt_access_token_expire_minutes: int = Field(
        default=30, description="Access token expiration (minutes)"
    )
    jwt_refresh_token_expire_days: int = Field(
        default=7, description="Refresh token expiration (days)"
    )

    # Security
    cors_origins: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8000"],
        description="CORS allowed origins",
    )
    allowed_hosts: List[str] = Field(
        default=["localhost", "127.0.0.1"], description="Allowed hosts"
    )
    secret_key: str = Field(default="super-secret-key", description="Application secret key")

    # Rate Limiting
    rate_limit_enabled: bool = Field(default=True, description="Enable rate limiting")
    rate_limit_per_minute: int = Field(default=60, description="Rate limit per minute")

    # Monitoring
    enable_metrics: bool = Field(default=True, description="Enable Prometheus metrics")
    metrics_port: int = Field(default=8000, description="Metrics endpoint port")
    sentry_dsn: Optional[str] = Field(default=None, description="Sentry DSN")

    # External Services
    external_api_url: Optional[str] = Field(default=None, description="External API URL")
    external_api_key: Optional[str] = Field(default=None, description="External API key")

    # Feature Flags
    enable_cache: bool = Field(default=True, description="Enable Redis caching")
    enable_tracing: bool = Field(default=False, description="Enable distributed tracing")
    enable_profiling: bool = Field(default=False, description="Enable profiling")

    # Cloud Configuration (GCP)
    gcp_project_id: Optional[str] = Field(default=None, description="GCP Project ID")
    gcp_bucket_name: Optional[str] = Field(default=None, description="GCP Storage bucket")
    gcp_credentials_path: Optional[str] = Field(
        default=None, description="GCP credentials file path"
    )

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, v):
        """Parse CORS origins from string or list"""
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v

    @field_validator("allowed_hosts", mode="before")
    @classmethod
    def parse_allowed_hosts(cls, v):
        """Parse allowed hosts from string or list"""
        if isinstance(v, str):
            return [host.strip() for host in v.split(",")]
        return v

    @field_validator("log_level")
    @classmethod
    def validate_log_level(cls, v):
        """Validate log level"""
        valid_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if v.upper() not in valid_levels:
            raise ValueError(f"Log level must be one of {valid_levels}")
        return v.upper()

    @property
    def is_production(self) -> bool:
        """Check if running in production"""
        return self.environment.lower() == "production"

    @property
    def is_development(self) -> bool:
        """Check if running in development"""
        return self.environment.lower() == "development"

    @property
    def database_url_sync(self) -> str:
        """Get synchronous database URL (for Alembic)"""
        return self.database_url.replace("+asyncpg", "").replace("+psycopg", "")


@lru_cache()
def get_settings() -> Settings:
    """
    Get cached settings instance
    Using lru_cache to avoid reading .env file multiple times
    """
    return Settings()


# Global settings instance
settings = get_settings()
