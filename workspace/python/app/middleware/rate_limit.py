"""
Rate Limiting Middleware
Simple rate limiting using Redis
"""

import time
from typing import Callable

from fastapi import Request, Response, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.utils.cache import cache_manager
from app.utils.logger import get_logger


logger = get_logger(__name__)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Rate limiting middleware using sliding window algorithm
    """

    def __init__(self, app, requests_per_minute: int = 60):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.window_size = 60  # seconds

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """
        Process request with rate limiting

        Args:
            request: Incoming request
            call_next: Next middleware/handler

        Returns:
            Response
        """
        # Skip rate limiting for health checks
        if request.url.path.startswith("/health"):
            return await call_next(request)

        # Get client identifier (IP address)
        client_ip = request.client.host if request.client else "unknown"

        # Create rate limit key
        rate_limit_key = f"rate_limit:{client_ip}"

        try:
            # Get current request count
            redis = cache_manager.get_client()

            # Increment counter
            current_count = await redis.incr(rate_limit_key)

            # Set expiration on first request
            if current_count == 1:
                await redis.expire(rate_limit_key, self.window_size)

            # Get TTL for rate limit window
            ttl = await redis.ttl(rate_limit_key)

            # Check if rate limit exceeded
            if current_count > self.requests_per_minute:
                logger.warning(
                    "Rate limit exceeded",
                    extra={
                        "client_ip": client_ip,
                        "path": request.url.path,
                        "count": current_count,
                    },
                )

                return JSONResponse(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    content={
                        "error": "Rate limit exceeded",
                        "message": f"Too many requests. Please try again in {ttl} seconds.",
                        "retry_after": ttl,
                    },
                    headers={
                        "Retry-After": str(ttl),
                        "X-RateLimit-Limit": str(self.requests_per_minute),
                        "X-RateLimit-Remaining": "0",
                        "X-RateLimit-Reset": str(int(time.time()) + ttl),
                    },
                )

            # Process request
            response = await call_next(request)

            # Add rate limit headers
            remaining = max(0, self.requests_per_minute - current_count)
            response.headers["X-RateLimit-Limit"] = str(self.requests_per_minute)
            response.headers["X-RateLimit-Remaining"] = str(remaining)
            response.headers["X-RateLimit-Reset"] = str(int(time.time()) + ttl)

            return response

        except Exception as e:
            logger.error(f"Rate limit middleware error: {e}", exc_info=True)
            # On error, allow request to proceed
            return await call_next(request)
