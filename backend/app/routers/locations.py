"""
Location tracking API endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, status
from typing import List
from app.models.schemas import LocationPoint, LocationBatch, APIResponse
from app.middleware.auth import get_current_user
from app.database import db_service
from app.services.location_service import LocationService
import logging

logger = logging.getLogger(__name__)

router = APIRouter()
location_service = LocationService()


@router.post("/", response_model=APIResponse)
async def save_location(
    location: LocationPoint, current_user: dict = Depends(get_current_user)
):
    """Save a single location point"""
    try:
        # Ensure user_id matches authenticated user
        location.user_id = current_user["user_id"]

        success = await location_service.save_location(location.dict())

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save location",
            )

        return APIResponse(success=True, message="Location saved successfully")

    except Exception as e:
        logger.error(f"Error saving location: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.post("/batch", response_model=APIResponse)
async def save_locations_batch(
    location_batch: LocationBatch, current_user: dict = Depends(get_current_user)
):
    """Save multiple location points in batch"""
    try:
        # Ensure all locations have the correct user_id
        locations_data = []
        for location in location_batch.locations:
            location_dict = location.dict()
            location_dict["user_id"] = current_user["user_id"]
            locations_data.append(location_dict)

        success = await db_service.save_locations_batch(locations_data)

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save location batch",
            )

        return APIResponse(
            success=True,
            message=f"Saved {len(locations_data)} locations successfully",
            data={"count": len(locations_data)},
        )

    except Exception as e:
        logger.error(f"Error saving location batch: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/recent", response_model=List[dict])
async def get_recent_locations(
    current_user: dict = Depends(get_current_user), limit: int = 100
):
    """Get recent location points for the user"""
    try:
        locations = await location_service.get_recent_locations(
            current_user["user_id"], limit=limit
        )

        return locations

    except Exception as e:
        logger.error(f"Error getting recent locations: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.delete("/cleanup", response_model=APIResponse)
async def cleanup_old_locations(
    current_user: dict = Depends(get_current_user), days_old: int = 30
):
    """Clean up old location data"""
    try:
        deleted_count = await location_service.cleanup_old_locations(
            current_user["user_id"], days_old=days_old
        )

        return APIResponse(
            success=True,
            message=f"Cleaned up {deleted_count} old location records",
            data={"deleted_count": deleted_count},
        )

    except Exception as e:
        logger.error(f"Error cleaning up locations: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


