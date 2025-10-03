"""
User management API endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, status
from app.models.schemas import UserProfile, UserStats, APIResponse
from app.middleware.auth import get_current_user
from app.services.user_service import UserService
import logging

logger = logging.getLogger(__name__)

router = APIRouter()
user_service = UserService()


@router.get("/profile", response_model=UserProfile)
async def get_user_profile(current_user: dict = Depends(get_current_user)):
    """Get current user's profile"""
    try:
        profile = await user_service.get_user_profile(current_user["user_id"])

        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found"
            )

        return UserProfile(**profile)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/stats", response_model=UserStats)
async def get_user_stats(current_user: dict = Depends(get_current_user)):
    """Get user statistics"""
    try:
        stats = await user_service.get_user_stats(current_user["user_id"])

        return UserStats(**stats)

    except Exception as e:
        logger.error(f"Error getting user stats: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.put("/profile", response_model=APIResponse)
async def update_user_profile(
    profile_data: dict, current_user: dict = Depends(get_current_user)
):
    """Update user profile"""
    try:
        success = await user_service.update_user_profile(
            current_user["user_id"], profile_data
        )

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update profile",
            )

        return APIResponse(success=True, message="Profile updated successfully")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating user profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.delete("/account", response_model=APIResponse)
async def delete_user_account(current_user: dict = Depends(get_current_user)):
    """Delete user account and all associated data"""
    try:
        success = await user_service.delete_user_account(current_user["user_id"])

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delete account",
            )

        return APIResponse(success=True, message="Account deleted successfully")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting user account: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


