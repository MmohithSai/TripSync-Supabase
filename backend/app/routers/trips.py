"""
Trip management API endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, status, Query
from typing import List, Optional
from app.models.schemas import (
    TripCreate,
    TripUpdate,
    TripResponse,
    APIResponse,
    AnalyticsRequest,
    AnalyticsResponse,
)
from app.middleware.auth import get_current_user
from app.database import db_service
from app.services.trip_service import TripService
import logging

logger = logging.getLogger(__name__)

router = APIRouter()
trip_service = TripService()


@router.post("/", response_model=APIResponse)
async def create_trip(
    trip_data: TripCreate, current_user: dict = Depends(get_current_user)
):
    """Create a new trip"""
    try:
        # Add user_id to trip data
        trip_dict = trip_data.dict()
        trip_dict["user_id"] = current_user["user_id"]

        trip_id = await db_service.create_trip(trip_dict)

        if not trip_id:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create trip",
            )

        return APIResponse(
            success=True, message="Trip created successfully", data={"trip_id": trip_id}
        )

    except Exception as e:
        logger.error(f"Error creating trip: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/", response_model=List[TripResponse])
async def get_user_trips(
    current_user: dict = Depends(get_current_user),
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """Get trips for the current user"""
    try:
        trips = await db_service.get_user_trips(
            current_user["user_id"], limit=limit, offset=offset
        )

        return [TripResponse(**trip) for trip in trips]

    except Exception as e:
        logger.error(f"Error getting trips: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/{trip_id}", response_model=TripResponse)
async def get_trip(trip_id: str, current_user: dict = Depends(get_current_user)):
    """Get a specific trip by ID"""
    try:
        trip = await trip_service.get_trip_by_id(trip_id, current_user["user_id"])

        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found"
            )

        return TripResponse(**trip)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting trip {trip_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.put("/{trip_id}", response_model=APIResponse)
async def update_trip(
    trip_id: str,
    trip_update: TripUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update a trip"""
    try:
        success = await trip_service.update_trip(
            trip_id, trip_update.dict(exclude_unset=True), current_user["user_id"]
        )

        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found or update failed",
            )

        return APIResponse(success=True, message="Trip updated successfully")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating trip {trip_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.delete("/{trip_id}", response_model=APIResponse)
async def delete_trip(trip_id: str, current_user: dict = Depends(get_current_user)):
    """Delete a trip"""
    try:
        success = await trip_service.delete_trip(trip_id, current_user["user_id"])

        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found or delete failed",
            )

        return APIResponse(success=True, message="Trip deleted successfully")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting trip {trip_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.post("/batch", response_model=APIResponse)
async def create_trips_batch(
    trips: List[TripCreate], current_user: dict = Depends(get_current_user)
):
    """Create multiple trips in batch"""
    try:
        # Add user_id to all trips
        trips_data = []
        for trip in trips:
            trip_dict = trip.dict()
            trip_dict["user_id"] = current_user["user_id"]
            trips_data.append(trip_dict)

        created_count = await trip_service.create_trips_batch(trips_data)

        return APIResponse(
            success=True,
            message=f"Created {created_count} trips successfully",
            data={"created_count": created_count},
        )

    except Exception as e:
        logger.error(f"Error creating trips batch: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


