"""
Trip Recording System Integration

Integrates all modules of the Trip Recording System:
- Trip State Machine (Brain)
- Route Recorder (Engine)
- Sensor Processor
- ML Backend

This module provides a unified interface for the complete system.
"""

from typing import Dict, Any, Optional, Callable
from datetime import datetime
import logging
import asyncio

from .trip_state_machine import (
    trip_state_manager,
    TripStateMachine,
    SensorData,
    TripState,
)
from .route_recorder import RouteRecorderManager
from .sensor_processor import sensor_processor, RawSensorData, ProcessedSensorData
from .ml_backend import ml_backend

logger = logging.getLogger(__name__)


class TripRecordingSystem:
    """
    Unified Trip Recording System

    Integrates all components and provides a clean interface
    for trip recording functionality.
    """

    def __init__(self, database_service):
        self.db_service = database_service
        self.route_recorder_manager = RouteRecorderManager(database_service)

        # System state
        self._initialized = False
        self._user_callbacks: Dict[str, Dict[str, Callable]] = {}

    async def initialize(self):
        """Initialize the trip recording system"""
        try:
            logger.info("Initializing Trip Recording System...")

            # Initialize components
            await self._setup_state_machine_callbacks()

            self._initialized = True
            logger.info("✅ Trip Recording System initialized successfully")

        except Exception as e:
            logger.error(f"❌ Failed to initialize Trip Recording System: {e}")
            raise

    async def _setup_state_machine_callbacks(self):
        """Setup callbacks between state machine and route recorder"""
        # This will be done per user when they first interact with the system
        pass

    def _ensure_user_setup(self, user_id: str):
        """Ensure user has proper system setup"""
        if user_id not in self._user_callbacks:
            # Get user's state machine
            state_machine = trip_state_manager.get_machine(user_id)

            # Setup callbacks
            state_machine.set_route_recorder_callbacks(
                on_start=lambda trip_id: asyncio.create_task(
                    self.route_recorder_manager.start_trip_recording(trip_id, user_id)
                ),
                on_stop=lambda trip_id: asyncio.create_task(
                    self.route_recorder_manager.stop_trip_recording(trip_id)
                ),
            )

            self._user_callbacks[user_id] = {
                "setup_time": datetime.now(),
                "state_machine": state_machine,
            }

            logger.info(f"Setup trip recording system for user {user_id}")

    async def process_sensor_input(
        self, user_id: str, raw_sensor_data: RawSensorData
    ) -> Dict[str, Any]:
        """
        Process sensor input through the complete system pipeline

        Pipeline:
        1. Sensor Processing & Validation
        2. Trip State Machine Processing
        3. Route Recording (if trip active)
        4. Optional ML Analysis

        Args:
            user_id: User identifier
            raw_sensor_data: Raw sensor data from mobile device

        Returns:
            Complete system response
        """
        try:
            if not self._initialized:
                raise RuntimeError("System not initialized")

            # Ensure user is setup
            self._ensure_user_setup(user_id)

            # Step 1: Process sensor data
            processed_data = await sensor_processor.process_sensor_data(raw_sensor_data)
            if not processed_data:
                return {
                    "success": False,
                    "error": "Invalid sensor data",
                    "step": "sensor_processing",
                }

            # Step 2: Process through state machine
            state_machine = trip_state_manager.get_machine(user_id)

            # Convert to state machine format
            state_machine_input = SensorData(
                speed_kmh=processed_data.speed_kmh,
                latitude=processed_data.latitude,
                longitude=processed_data.longitude,
                accuracy=processed_data.accuracy,
                timestamp=processed_data.timestamp,
                activity_type=processed_data.activity_type.value,
            )

            state_result = state_machine.process_sensor_data(state_machine_input)

            # Step 3: Handle route recording
            route_status = None
            if state_result["current_state"] == "active" and state_result.get(
                "trip_id"
            ):
                # Add GPS point to active trip
                gps_data = {
                    "latitude": processed_data.latitude,
                    "longitude": processed_data.longitude,
                    "accuracy": processed_data.accuracy,
                    "speed_kmh": processed_data.speed_kmh,
                    "altitude": processed_data.altitude,
                    "bearing": processed_data.bearing,
                    "timestamp": processed_data.timestamp.timestamp(),
                }

                success = await self.route_recorder_manager.add_gps_data(
                    state_result["trip_id"], gps_data
                )

                if success:
                    route_status = (
                        await self.route_recorder_manager.get_recording_status(
                            state_result["trip_id"]
                        )
                    )

            # Step 4: Compile response
            return {
                "success": True,
                "timestamp": datetime.now().isoformat(),
                "sensor_processing": {
                    "speed_kmh": processed_data.speed_kmh,
                    "activity_type": processed_data.activity_type.value,
                    "activity_confidence": processed_data.activity_confidence,
                    "is_moving": processed_data.is_moving,
                    "movement_confidence": processed_data.movement_confidence,
                    "location_quality": processed_data.location_quality,
                },
                "trip_state": state_result,
                "route_recording": route_status,
                "system_status": "operational",
            }

        except Exception as e:
            logger.error(f"Error processing sensor input for user {user_id}: {e}")
            return {
                "success": False,
                "error": str(e),
                "timestamp": datetime.now().isoformat(),
            }

    async def manual_trip_control(self, user_id: str, action: str) -> Dict[str, Any]:
        """
        Manual trip control (start/stop)

        Args:
            user_id: User identifier
            action: "start" or "stop"

        Returns:
            Control result
        """
        try:
            if not self._initialized:
                raise RuntimeError("System not initialized")

            # Ensure user is setup
            self._ensure_user_setup(user_id)

            state_machine = trip_state_manager.get_machine(user_id)

            if action == "start":
                trip_id = state_machine.manual_start_trip(user_id)
                return {
                    "success": True,
                    "action": "start",
                    "trip_id": trip_id,
                    "state": state_machine.get_current_state(),
                }

            elif action == "stop":
                success = state_machine.manual_stop_trip()
                return {
                    "success": success,
                    "action": "stop",
                    "state": state_machine.get_current_state(),
                }

            else:
                return {"success": False, "error": f"Invalid action: {action}"}

        except Exception as e:
            logger.error(f"Error in manual trip control for user {user_id}: {e}")
            return {"success": False, "error": str(e)}

    async def get_user_status(self, user_id: str) -> Dict[str, Any]:
        """Get comprehensive user status"""
        try:
            if not self._initialized:
                return {"error": "System not initialized"}

            # Get trip state
            state_machine = trip_state_manager.get_machine(user_id)
            trip_state = state_machine.get_current_state()

            # Get recording status
            recording_status = None
            if trip_state["state"] == "active" and trip_state.get("trip_id"):
                recording_status = (
                    await self.route_recorder_manager.get_recording_status(
                        trip_state["trip_id"]
                    )
                )

            # Get sensor summary
            sensor_summary = await sensor_processor.get_user_sensor_summary(user_id)

            # Get ML patterns (if available)
            ml_patterns = await ml_backend.get_user_travel_patterns(user_id)

            return {
                "success": True,
                "user_id": user_id,
                "trip_state": trip_state,
                "recording_status": recording_status,
                "sensor_summary": sensor_summary,
                "ml_patterns": ml_patterns,
                "system_initialized": self._initialized,
                "last_updated": datetime.now().isoformat(),
            }

        except Exception as e:
            logger.error(f"Error getting user status for {user_id}: {e}")
            return {"success": False, "error": str(e)}

    async def analyze_completed_trip(
        self, user_id: str, trip_id: str
    ) -> Dict[str, Any]:
        """
        Analyze a completed trip using ML models

        Args:
            user_id: User identifier
            trip_id: Trip identifier

        Returns:
            ML analysis results
        """
        try:
            # Get trip data from database
            # This would fetch GPS points and sensor data
            # For now, return placeholder

            logger.info(f"Analyzing trip {trip_id} for user {user_id}")

            # In real implementation:
            # gps_points = await self.db_service.get_trip_gps_points(trip_id, user_id)
            # sensor_data = await self.db_service.get_trip_sensor_data(trip_id, user_id)
            # analysis = await ml_backend.analyze_trip_data(user_id, gps_points, sensor_data)

            return {
                "success": True,
                "trip_id": trip_id,
                "user_id": user_id,
                "analysis": {
                    "transport_mode": "unknown",
                    "confidence": 0.0,
                    "quality_score": 0.0,
                    "message": "Analysis requires trip data from database",
                },
                "timestamp": datetime.now().isoformat(),
            }

        except Exception as e:
            logger.error(f"Error analyzing trip {trip_id} for user {user_id}: {e}")
            return {"success": False, "error": str(e)}

    async def get_system_overview(self) -> Dict[str, Any]:
        """Get system-wide overview"""
        try:
            # Get all active trips
            active_trips = trip_state_manager.get_all_active_trips()

            # Get recording status for all active trips
            all_recordings = await self.route_recorder_manager.get_recording_status()

            return {
                "success": True,
                "system_initialized": self._initialized,
                "active_trips": active_trips,
                "active_recordings": all_recordings,
                "total_users_setup": len(self._user_callbacks),
                "system_components": {
                    "trip_state_machine": "operational",
                    "route_recorder": "operational",
                    "sensor_processor": "operational",
                    "ml_backend": "operational",
                },
                "timestamp": datetime.now().isoformat(),
            }

        except Exception as e:
            logger.error(f"Error getting system overview: {e}")
            return {"success": False, "error": str(e)}

    async def cleanup_user_data(self, user_id: str):
        """Clean up all user data from the system"""
        try:
            # Clean up state machine
            trip_state_manager.remove_machine(user_id)

            # Clean up sensor processor
            sensor_processor.cleanup_user_data(user_id)

            # Remove from callbacks
            if user_id in self._user_callbacks:
                del self._user_callbacks[user_id]

            logger.info(f"Cleaned up all data for user {user_id}")

        except Exception as e:
            logger.error(f"Error cleaning up user data for {user_id}: {e}")


# Global system instance (will be initialized with database service)
trip_recording_system: Optional[TripRecordingSystem] = None


def initialize_trip_system(database_service) -> TripRecordingSystem:
    """Initialize the global trip recording system"""
    global trip_recording_system
    if trip_recording_system is None:
        trip_recording_system = TripRecordingSystem(database_service)
    return trip_recording_system


def get_trip_system() -> TripRecordingSystem:
    """Get the global trip recording system instance"""
    if trip_recording_system is None:
        raise RuntimeError("Trip recording system not initialized")
    return trip_recording_system


