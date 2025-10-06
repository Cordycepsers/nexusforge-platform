"""
API Routes
"""

from app.routes.health import router as health_router
from app.routes.api import router as api_router

__all__ = ["health_router", "api_router"]
