"""
Analytics and reporting API endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, status, Query
from typing import Optional
from app.models.schemas import AnalyticsResponse, TripStats, APIResponse
from app.middleware.auth import get_current_user
from app.database import db_service
from app.services.analytics_service import AnalyticsService
import logging

logger = logging.getLogger(__name__)

router = APIRouter()
analytics_service = AnalyticsService()


@router.get("/dashboard", response_model=AnalyticsResponse)
async def get_dashboard_analytics(
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    region: Optional[str] = Query(None, description="Filter by region"),
    current_user: dict = Depends(get_current_user),
):
    """Get analytics data for dashboard"""
    try:
        analytics_data = await db_service.get_trip_analytics(
            current_user["user_id"], start_date, end_date
        )

        if not analytics_data:
            return AnalyticsResponse(
                stats=TripStats(
                    total_trips=0,
                    total_distance_km=0.0,
                    total_duration_min=0,
                    avg_distance_km=0.0,
                    avg_duration_min=0.0,
                    mode_distribution={},
                ),
                trips=[],
                date_range={"start_date": start_date, "end_date": end_date},
            )

        return AnalyticsResponse(
            stats=TripStats(**analytics_data),
            trips=analytics_data.get("trips", []),
            date_range={"start_date": start_date, "end_date": end_date},
        )

    except Exception as e:
        logger.error(f"Error getting dashboard analytics: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/mode-distribution")
async def get_mode_distribution(
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user),
):
    """Get transportation mode distribution"""
    try:
        distribution = await analytics_service.get_mode_distribution(
            current_user["user_id"], start_date, end_date
        )

        return APIResponse(
            success=True,
            message="Mode distribution retrieved successfully",
            data=distribution,
        )

    except Exception as e:
        logger.error(f"Error getting mode distribution: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/carbon-footprint")
async def get_carbon_footprint(
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user),
):
    """Calculate carbon footprint for trips"""
    try:
        footprint = await analytics_service.calculate_carbon_footprint(
            current_user["user_id"], start_date, end_date
        )

        return APIResponse(
            success=True,
            message="Carbon footprint calculated successfully",
            data=footprint,
        )

    except Exception as e:
        logger.error(f"Error calculating carbon footprint: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/heatmap")
async def get_location_heatmap(
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user),
):
    """Get location heatmap data"""
    try:
        heatmap_data = await analytics_service.get_location_heatmap(
            current_user["user_id"], start_date, end_date
        )

        return APIResponse(
            success=True,
            message="Heatmap data retrieved successfully",
            data=heatmap_data,
        )

    except Exception as e:
        logger.error(f"Error getting heatmap data: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/export")
async def export_trip_data(
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    format: str = Query("csv", description="Export format: csv, json"),
    current_user: dict = Depends(get_current_user),
):
    """Export trip data in various formats"""
    try:
        export_data = await analytics_service.export_trip_data(
            current_user["user_id"], start_date, end_date, format=format
        )

        return APIResponse(
            success=True,
            message=f"Trip data exported in {format} format",
            data=export_data,
        )

    except Exception as e:
        logger.error(f"Error exporting trip data: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


