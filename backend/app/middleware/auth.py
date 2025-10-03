"""
Authentication middleware using Supabase JWT tokens
"""

from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from app.config import settings
from app.database import db_service
from typing import Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)

security = HTTPBearer()


async def verify_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    """
    Verify Supabase JWT token and return user info
    """
    token = credentials.credentials

    try:
        # For development, we'll use a simplified approach
        # In production, you should verify the JWT signature properly
        
        # Check if it's a test token (for development)
        if token == "test-token":
            logger.info("Using test token for development")
            return {"user_id": "test-user-id", "email": "test@example.com", "user": {"id": "test-user-id", "email": "test@example.com"}}

        # Extract user ID from token payload (simplified)
        payload = jwt.get_unverified_claims(token)
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: no user ID found",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Get user from database
        user = await db_service.get_user_by_id(user_id)
        if not user:
            # Try to create user profile automatically
            logger.info(f"User {user_id} not found in database, attempting to create profile...")
            user = await db_service.create_user_profile(user_id, payload.get("email"))
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="User not found and could not be created",
                    headers={"WWW-Authenticate": "Bearer"},
                )

        return {"user_id": user_id, "email": user.get("email"), "user": user}

    except JWTError as e:
        logger.error(f"JWT Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Auth Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    auth_data: Dict[str, Any] = Depends(verify_token),
) -> Dict[str, Any]:
    """Get current authenticated user"""
    return auth_data


# Optional auth (for public endpoints that can benefit from user context)
async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    ),
) -> Optional[Dict[str, Any]]:
    """Get current user if authenticated, None otherwise"""
    if not credentials:
        return None

    try:
        return await verify_token(credentials)
    except HTTPException:
        return None

