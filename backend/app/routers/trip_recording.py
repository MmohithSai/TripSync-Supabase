"""
Trip Recording System API Endpoints

Provides REST API for the Trip State Machine and Route Recorder modules.
Handles sensor data input, trip state management, and route recording control.
"""

from fastapi import APIRouter, HTTPException, Depends, status, BackgroundTasks
from typing import Optional
from datetime import datetime
import logging
from pydantic import BaseModel, Field

from app.middleware.auth import get_current_user
from app.modules.trip_state_machine import (
    trip_state_manager,
    SensorData,
)
from app.modules.route_recorder import route_recorder_manager, RouteRecorderManager
from app.modules.sensor_processor import sensor_processor, RawSensorData
from app.database import db_service

logger = logging.getLogger(__name__)

router = APIRouter()


# Development/testing endpoint (no auth required)
@router.get("/test")
async def test_endpoint():
    """Test endpoint to verify the trip recording system is working"""
    return {
        "status": "ok",
        "message": "Trip Recording System is operational",
        "timestamp": datetime.now().isoformat(),
        "modules": {
            "trip_state_manager": "loaded",
            "route_recorder_manager": "loaded",
            "sensor_processor": "loaded",
            "ml_backend": "loaded",
        },
    }


class SensorDataInput(BaseModel):
    """Input model for sensor data"""

    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy: float = Field(..., ge=0)
    speed_mps: Optional[float] = Field(None, ge=0)
    altitude: Optional[float] = None
    bearing: Optional[float] = Field(None, ge=0, le=360)

    # Activity recognition
    activity_type: Optional[str] = None
    activity_confidence: Optional[float] = Field(None, ge=0, le=1)

    # Motion sensors
    accelerometer_x: Optional[float] = None
    accelerometer_y: Optional[float] = None
    accelerometer_z: Optional[float] = None

    # Device info
    device_id: Optional[str] = None
    platform: Optional[str] = None
    timestamp: Optional[float] = None  # Unix timestamp


class TripConfigInput(BaseModel):
    """Input model for trip configuration"""

    speed_threshold_kmh: Optional[float] = Field(None, ge=0, le=50)
    duration_threshold_seconds: Optional[int] = Field(None, ge=10, le=300)
    stop_duration_threshold_seconds: Optional[int] = Field(None, ge=10, le=300)
    gps_collection_interval_seconds: Optional[int] = Field(None, ge=5, le=300)


class GPSPointInput(BaseModel):
    """Input model for GPS points"""

    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy: float = Field(..., ge=0)
    speed_kmh: Optional[float] = Field(None, ge=0)
    altitude: Optional[float] = None
    bearing: Optional[float] = Field(None, ge=0, le=360)
    timestamp: Optional[float] = None


# Initialize route recorder manager
def get_route_recorder() -> RouteRecorderManager:
    """Get route recorder manager instance"""
    global route_recorder_manager
    if route_recorder_manager is None:
        route_recorder_manager = RouteRecorderManager(db_service)
    return route_recorder_manager


@router.post("/sensor-data")
async def process_sensor_data(
    sensor_input: SensorDataInput,
    current_user: dict = Depends(get_current_user),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """
    Process incoming sensor data from mobile device

    This endpoint receives sensor data and processes it through:
    1. Sensor data validation and processing
    2. Trip state machine evaluation
    3. Route recorder control (start/stop)
    """
    try:
        user_id = current_user["user_id"]

        # Convert input to raw sensor data
        raw_sensor_data = RawSensorData(
            user_id=user_id,
            timestamp=datetime.fromtimestamp(
                sensor_input.timestamp or datetime.now().timestamp()
            ),
            latitude=sensor_input.latitude,
            longitude=sensor_input.longitude,
            accuracy=sensor_input.accuracy,
            speed_mps=sensor_input.speed_mps,
            altitude=sensor_input.altitude,
            bearing=sensor_input.bearing,
            activity_type=sensor_input.activity_type,
            activity_confidence=sensor_input.activity_confidence,
            accelerometer_x=sensor_input.accelerometer_x,
            accelerometer_y=sensor_input.accelerometer_y,
            accelerometer_z=sensor_input.accelerometer_z,
            device_id=sensor_input.device_id,
            platform=sensor_input.platform,
        )

        # Process sensor data
        processed_data = await sensor_processor.process_sensor_data(raw_sensor_data)
        if not processed_data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid sensor data"
            )

        # Get user's trip state machine
        state_machine = trip_state_manager.get_machine(user_id)

        # Setup route recorder callbacks if not already done
        route_recorder = get_route_recorder()
        if not state_machine.on_trip_start:
            state_machine.set_route_recorder_callbacks(
                on_start=lambda trip_id: background_tasks.add_task(
                    route_recorder.start_trip_recording, trip_id, user_id
                ),
                on_stop=lambda trip_id: background_tasks.add_task(
                    route_recorder.stop_trip_recording, trip_id
                ),
            )

        # Convert processed data to state machine format
        state_machine_data = SensorData(
            speed_kmh=processed_data.speed_kmh,
            latitude=processed_data.latitude,
            longitude=processed_data.longitude,
            accuracy=processed_data.accuracy,
            timestamp=processed_data.timestamp,
            activity_type=processed_data.activity_type.value,
        )

        # Process through state machine
        state_result = state_machine.process_sensor_data(state_machine_data)

        # If trip is active, add GPS point to route recorder
        if state_result["current_state"] == "active" and state_result["trip_id"]:
            gps_data = {
                "latitude": processed_data.latitude,
                "longitude": processed_data.longitude,
                "accuracy": processed_data.accuracy,
                "speed_kmh": processed_data.speed_kmh,
                "altitude": processed_data.altitude,
                "bearing": processed_data.bearing,
                "timestamp": processed_data.timestamp.timestamp(),
            }

            background_tasks.add_task(
                route_recorder.add_gps_data, state_result["trip_id"], gps_data
            )

        return {
            "success": True,
            "state_machine": state_result,
            "processed_sensor_data": {
                "speed_kmh": processed_data.speed_kmh,
                "activity_type": processed_data.activity_type.value,
                "activity_confidence": processed_data.activity_confidence,
                "is_moving": processed_data.is_moving,
                "movement_confidence": processed_data.movement_confidence,
                "location_quality": processed_data.location_quality,
            },
            "timestamp": datetime.now().isoformat(),
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Error processing sensor data for user {current_user.get('user_id')}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.post("/trip/start")
async def manual_start_trip(
    current_user: dict = Depends(get_current_user),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """Manually start a trip"""
    try:
        user_id = current_user["user_id"]

        # Get user's state machine
        state_machine = trip_state_manager.get_machine(user_id)

        # Setup route recorder callbacks
        route_recorder = get_route_recorder()
        state_machine.set_route_recorder_callbacks(
            on_start=lambda trip_id: background_tasks.add_task(
                route_recorder.start_trip_recording, trip_id, user_id
            ),
            on_stop=lambda trip_id: background_tasks.add_task(
                route_recorder.stop_trip_recording, trip_id
            ),
        )

        # Start trip
        trip_id = state_machine.manual_start_trip(user_id)

        return {
            "success": True,
            "trip_id": trip_id,
            "message": "Trip started manually",
            "state": state_machine.get_current_state(),
        }

    except Exception as e:
        logger.error(f"Error starting trip for user {current_user.get('user_id')}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.post("/trip/stop")
async def manual_stop_trip(current_user: dict = Depends(get_current_user)):
    """Manually stop a trip"""
    try:
        user_id = current_user["user_id"]

        # Get user's state machine
        state_machine = trip_state_manager.get_machine(user_id)

        # Stop trip
        success = state_machine.manual_stop_trip()

        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="No active trip to stop"
            )

        return {
            "success": True,
            "message": "Trip stopped manually",
            "state": state_machine.get_current_state(),
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error stopping trip for user {current_user.get('user_id')}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/trip/state")
async def get_trip_state(current_user: dict = Depends(get_current_user)):
    """Get current trip state"""
    try:
        user_id = current_user["user_id"]

        # Get user's state machine
        state_machine = trip_state_manager.get_machine(user_id)

        # Get current state
        current_state = state_machine.get_current_state()

        # Get route recording status if trip is active
        recording_status = None
        if current_state["state"] == "active" and current_state.get("trip_id"):
            route_recorder = get_route_recorder()
            recording_status = await route_recorder.get_recording_status(
                current_state["trip_id"]
            )

        return {
            "success": True,
            "state": current_state,
            "recording_status": recording_status,
        }

    except Exception as e:
        logger.error(
            f"Error getting trip state for user {current_user.get('user_id')}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.post("/gps-point")
async def add_gps_point(
    gps_input: GPSPointInput, current_user: dict = Depends(get_current_user)
):
    """Add GPS point to active trip"""
    try:
        user_id = current_user["user_id"]

        # Get current trip state
        state_machine = trip_state_manager.get_machine(user_id)
        current_state = state_machine.get_current_state()

        if current_state["state"] != "active" or not current_state.get("trip_id"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No active trip to add GPS point to",
            )

        # Add GPS point to route recorder
        route_recorder = get_route_recorder()
        gps_data = {
            "latitude": gps_input.latitude,
            "longitude": gps_input.longitude,
            "accuracy": gps_input.accuracy,
            "speed_kmh": gps_input.speed_kmh,
            "altitude": gps_input.altitude,
            "bearing": gps_input.bearing,
            "timestamp": gps_input.timestamp or datetime.now().timestamp(),
        }

        success = await route_recorder.add_gps_data(current_state["trip_id"], gps_data)

        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to add GPS point",
            )

        return {
            "success": True,
            "message": "GPS point added successfully",
            "trip_id": current_state["trip_id"],
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Error adding GPS point for user {current_user.get('user_id')}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.put("/config")
async def update_trip_config(
    config_input: TripConfigInput, current_user: dict = Depends(get_current_user)
):
    """Update trip detection configuration"""
    try:
        user_id = current_user["user_id"]

        # Get current config
        state_machine = trip_state_manager.get_machine(user_id)
        current_config = state_machine.config

        # Update config with provided values
        if config_input.speed_threshold_kmh is not None:
            current_config.speed_threshold_kmh = config_input.speed_threshold_kmh
        if config_input.duration_threshold_seconds is not None:
            current_config.duration_threshold_seconds = (
                config_input.duration_threshold_seconds
            )
        if config_input.stop_duration_threshold_seconds is not None:
            current_config.stop_duration_threshold_seconds = (
                config_input.stop_duration_threshold_seconds
            )
        if config_input.gps_collection_interval_seconds is not None:
            current_config.gps_collection_interval_seconds = (
                config_input.gps_collection_interval_seconds
            )

        return {
            "success": True,
            "message": "Configuration updated successfully",
            "config": {
                "speed_threshold_kmh": current_config.speed_threshold_kmh,
                "duration_threshold_seconds": current_config.duration_threshold_seconds,
                "stop_duration_threshold_seconds": current_config.stop_duration_threshold_seconds,
                "gps_collection_interval_seconds": current_config.gps_collection_interval_seconds,
            },
        }

    except Exception as e:
        logger.error(
            f"Error updating config for user {current_user.get('user_id')}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/analytics/trip/{trip_id}")
async def analyze_trip(trip_id: str, current_user: dict = Depends(get_current_user)):
    """Analyze completed trip using ML models"""
    try:
        user_id = current_user["user_id"]

        # Get trip data from database
        # This would fetch GPS points and sensor data for the trip
        # For now, we'll return a placeholder response

        # In a real implementation:
        # gps_points = await db_service.get_trip_gps_points(trip_id, user_id)
        # sensor_data = await db_service.get_trip_sensor_data(trip_id, user_id)
        # analysis = await ml_backend.analyze_trip_data(user_id, gps_points, sensor_data)

        analysis = {
            "trip_id": trip_id,
            "transport_mode": "unknown",
            "confidence": 0.0,
            "quality_score": 0.0,
            "message": "Trip analysis not yet implemented - requires trip data from database",
        }

        return {"success": True, "analysis": analysis}

    except Exception as e:
        logger.error(
            f"Error analyzing trip {trip_id} for user {current_user.get('user_id')}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@router.get("/status/all")
async def get_system_status(current_user: dict = Depends(get_current_user)):
    """Get overall system status"""
    try:
        user_id = current_user["user_id"]

        # Get trip state
        state_machine = trip_state_manager.get_machine(user_id)
        trip_state = state_machine.get_current_state()

        # Get recording status
        route_recorder = get_route_recorder()
        recording_status = await route_recorder.get_recording_status()

        # Get sensor summary
        sensor_summary = await sensor_processor.get_user_sensor_summary(user_id)

        # Get all active trips (admin view)
        all_active_trips = trip_state_manager.get_all_active_trips()

        return {
            "success": True,
            "user_status": {
                "user_id": user_id,
                "trip_state": trip_state,
                "sensor_summary": sensor_summary,
            },
            "recording_status": recording_status,
            "system_status": {
                "active_trips_count": len(all_active_trips),
                "active_users": list(all_active_trips.keys()),
            },
        }

    except Exception as e:
        logger.error(
            f"Error getting system status for user {current_user.get('user_id')}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )
