"""
Mobile Sensor Data Processor

Handles incoming sensor data from mobile devices including:
- GPS data (speed, location, accuracy)
- Activity Recognition (walking, in_vehicle, still, etc.)
- Motion sensors (accelerometer, gyroscope)
"""

from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from enum import Enum
import logging
import statistics
from collections import deque

logger = logging.getLogger(__name__)


class ActivityType(Enum):
    """Activity types from mobile activity recognition APIs"""

    STILL = "still"
    WALKING = "walking"
    RUNNING = "running"
    IN_VEHICLE = "in_vehicle"
    ON_BICYCLE = "on_bicycle"
    ON_FOOT = "on_foot"
    TILTING = "tilting"
    UNKNOWN = "unknown"


@dataclass
class RawSensorData:
    """Raw sensor data from mobile device"""

    user_id: str
    timestamp: datetime

    # GPS data
    latitude: float
    longitude: float
    accuracy: float
    speed_mps: Optional[float] = None  # meters per second
    altitude: Optional[float] = None
    bearing: Optional[float] = None

    # Activity recognition
    activity_type: Optional[str] = None
    activity_confidence: Optional[float] = None

    # Motion sensors (optional)
    accelerometer_x: Optional[float] = None
    accelerometer_y: Optional[float] = None
    accelerometer_z: Optional[float] = None

    # Device info
    device_id: Optional[str] = None
    platform: Optional[str] = None  # android, ios


@dataclass
class ProcessedSensorData:
    """Processed and validated sensor data"""

    user_id: str
    timestamp: datetime

    # Processed GPS
    latitude: float
    longitude: float
    accuracy: float
    speed_kmh: float

    # Processed activity
    activity_type: ActivityType
    activity_confidence: float

    # Derived metrics
    is_moving: bool
    movement_confidence: float
    location_quality: str  # excellent, good, fair, poor

    # Optional fields (must come after required fields)
    altitude: Optional[float] = None
    bearing: Optional[float] = None
    motion_variance: Optional[float] = None
    is_stationary: Optional[bool] = None


class SensorDataValidator:
    """Validates and filters sensor data"""

    def __init__(self):
        self.config = {
            "max_accuracy_threshold": 100,  # meters
            "max_speed_kmh": 200,  # km/h
            "min_confidence_threshold": 0.3,
            "coordinate_bounds": {
                "lat_min": -90,
                "lat_max": 90,
                "lon_min": -180,
                "lon_max": 180,
            },
        }

    def validate_gps_data(self, data: RawSensorData) -> Tuple[bool, str]:
        """Validate GPS data quality"""

        # Check coordinate bounds
        if not (
            self.config["coordinate_bounds"]["lat_min"]
            <= data.latitude
            <= self.config["coordinate_bounds"]["lat_max"]
        ):
            return False, "Invalid latitude"

        if not (
            self.config["coordinate_bounds"]["lon_min"]
            <= data.longitude
            <= self.config["coordinate_bounds"]["lon_max"]
        ):
            return False, "Invalid longitude"

        # Check accuracy
        if data.accuracy > self.config["max_accuracy_threshold"]:
            return False, f"Poor accuracy: {data.accuracy}m"

        # Check speed (if available)
        if data.speed_mps is not None:
            speed_kmh = data.speed_mps * 3.6
            if speed_kmh > self.config["max_speed_kmh"]:
                return False, f"Unrealistic speed: {speed_kmh} km/h"

        return True, "Valid"

    def get_location_quality(self, accuracy: float) -> str:
        """Determine location quality based on accuracy"""
        if accuracy <= 5:
            return "excellent"
        elif accuracy <= 15:
            return "good"
        elif accuracy <= 50:
            return "fair"
        else:
            return "poor"


class ActivityRecognitionProcessor:
    """Processes activity recognition data"""

    def __init__(self):
        self.activity_mapping = {
            # Android Activity Recognition API
            "IN_VEHICLE": ActivityType.IN_VEHICLE,
            "ON_BICYCLE": ActivityType.ON_BICYCLE,
            "ON_FOOT": ActivityType.ON_FOOT,
            "RUNNING": ActivityType.RUNNING,
            "STILL": ActivityType.STILL,
            "TILTING": ActivityType.TILTING,
            "WALKING": ActivityType.WALKING,
            # iOS Core Motion
            "automotive": ActivityType.IN_VEHICLE,
            "cycling": ActivityType.ON_BICYCLE,
            "running": ActivityType.RUNNING,
            "walking": ActivityType.WALKING,
            "stationary": ActivityType.STILL,
            # Common variations
            "in_vehicle": ActivityType.IN_VEHICLE,
            "on_bicycle": ActivityType.ON_BICYCLE,
            "on_foot": ActivityType.ON_FOOT,
            "still": ActivityType.STILL,
            "unknown": ActivityType.UNKNOWN,
        }

    def process_activity(
        self, activity_type: str, confidence: float = None
    ) -> Tuple[ActivityType, float]:
        """Process raw activity recognition data"""

        # Normalize activity type
        normalized_activity = self.activity_mapping.get(
            activity_type.upper() if activity_type else "UNKNOWN", ActivityType.UNKNOWN
        )

        # Normalize confidence
        normalized_confidence = max(0.0, min(1.0, confidence or 0.5))

        return normalized_activity, normalized_confidence

    def determine_movement_state(
        self, activity: ActivityType, confidence: float, speed_kmh: float
    ) -> Tuple[bool, float]:
        """Determine if user is moving based on activity and speed"""

        # Movement indicators by activity type
        movement_activities = {
            ActivityType.IN_VEHICLE: 0.9,
            ActivityType.ON_BICYCLE: 0.9,
            ActivityType.RUNNING: 0.95,
            ActivityType.WALKING: 0.8,
            ActivityType.ON_FOOT: 0.7,
            ActivityType.STILL: 0.1,
            ActivityType.TILTING: 0.3,
            ActivityType.UNKNOWN: 0.5,
        }

        activity_movement_score = movement_activities.get(activity, 0.5)

        # Speed-based movement detection
        speed_movement_score = min(1.0, speed_kmh / 5.0)  # Normalize to 5 km/h

        # Combine scores with confidence weighting
        combined_score = activity_movement_score * confidence + speed_movement_score * (
            1 - confidence
        )

        is_moving = combined_score > 0.5
        movement_confidence = combined_score

        return is_moving, movement_confidence


class MotionAnalyzer:
    """Analyzes motion sensor data for additional insights"""

    def __init__(self, window_size: int = 10):
        self.window_size = window_size
        self.motion_history: deque = deque(maxlen=window_size)

    def add_motion_data(self, accel_x: float, accel_y: float, accel_z: float):
        """Add accelerometer data point"""
        magnitude = (accel_x**2 + accel_y**2 + accel_z**2) ** 0.5
        self.motion_history.append(
            {
                "timestamp": datetime.now(),
                "magnitude": magnitude,
                "x": accel_x,
                "y": accel_y,
                "z": accel_z,
            }
        )

    def calculate_motion_variance(self) -> Optional[float]:
        """Calculate variance in motion over recent window"""
        if len(self.motion_history) < 3:
            return None

        magnitudes = [point["magnitude"] for point in self.motion_history]
        return statistics.variance(magnitudes)

    def is_stationary(self, threshold: float = 0.5) -> Optional[bool]:
        """Determine if device is stationary based on motion variance"""
        variance = self.calculate_motion_variance()
        if variance is None:
            return None

        return variance < threshold


class SensorDataProcessor:
    """
    Main sensor data processor

    Processes raw sensor data from mobile devices and converts it
    into structured data for the Trip State Machine
    """

    def __init__(self):
        self.validator = SensorDataValidator()
        self.activity_processor = ActivityRecognitionProcessor()
        self.motion_analyzers: Dict[str, MotionAnalyzer] = {}

        # Data smoothing windows per user
        self.speed_windows: Dict[str, deque] = {}
        self.location_windows: Dict[str, deque] = {}

        self.config = {
            "speed_smoothing_window": 5,
            "location_smoothing_window": 3,
            "min_time_between_updates": 5,  # seconds
        }

    async def process_sensor_data(
        self, raw_data: RawSensorData
    ) -> Optional[ProcessedSensorData]:
        """
        Process raw sensor data into structured format

        Args:
            raw_data: Raw sensor data from mobile device

        Returns:
            ProcessedSensorData or None if invalid
        """
        try:
            # Validate GPS data
            is_valid, error_msg = self.validator.validate_gps_data(raw_data)
            if not is_valid:
                logger.warning(
                    f"Invalid GPS data for user {raw_data.user_id}: {error_msg}"
                )
                return None

            # Process speed
            speed_kmh = self._process_speed(raw_data)

            # Process activity recognition
            activity_type, activity_confidence = (
                self.activity_processor.process_activity(
                    raw_data.activity_type, raw_data.activity_confidence
                )
            )

            # Determine movement state
            is_moving, movement_confidence = (
                self.activity_processor.determine_movement_state(
                    activity_type, activity_confidence, speed_kmh
                )
            )

            # Process motion sensors (if available)
            motion_variance = None
            is_stationary = None
            if all(
                x is not None
                for x in [
                    raw_data.accelerometer_x,
                    raw_data.accelerometer_y,
                    raw_data.accelerometer_z,
                ]
            ):
                motion_variance, is_stationary = self._process_motion_data(raw_data)

            # Create processed data
            processed_data = ProcessedSensorData(
                user_id=raw_data.user_id,
                timestamp=raw_data.timestamp,
                latitude=raw_data.latitude,
                longitude=raw_data.longitude,
                accuracy=raw_data.accuracy,
                speed_kmh=speed_kmh,
                altitude=raw_data.altitude,
                bearing=raw_data.bearing,
                activity_type=activity_type,
                activity_confidence=activity_confidence,
                is_moving=is_moving,
                movement_confidence=movement_confidence,
                location_quality=self.validator.get_location_quality(raw_data.accuracy),
                motion_variance=motion_variance,
                is_stationary=is_stationary,
            )

            logger.debug(
                f"Processed sensor data for user {raw_data.user_id}: speed={speed_kmh:.1f}km/h, activity={activity_type.value}, moving={is_moving}"
            )

            return processed_data

        except Exception as e:
            logger.error(
                f"Failed to process sensor data for user {raw_data.user_id}: {e}"
            )
            return None

    def _process_speed(self, raw_data: RawSensorData) -> float:
        """Process and smooth speed data"""
        user_id = raw_data.user_id

        # Convert m/s to km/h
        current_speed_kmh = (raw_data.speed_mps or 0) * 3.6

        # Initialize speed window for user
        if user_id not in self.speed_windows:
            self.speed_windows[user_id] = deque(
                maxlen=self.config["speed_smoothing_window"]
            )

        # Add current speed to window
        self.speed_windows[user_id].append(current_speed_kmh)

        # Return smoothed speed (moving average)
        speeds = list(self.speed_windows[user_id])
        return sum(speeds) / len(speeds) if speeds else 0.0

    def _process_motion_data(
        self, raw_data: RawSensorData
    ) -> Tuple[Optional[float], Optional[bool]]:
        """Process motion sensor data"""
        user_id = raw_data.user_id

        # Initialize motion analyzer for user
        if user_id not in self.motion_analyzers:
            self.motion_analyzers[user_id] = MotionAnalyzer()

        analyzer = self.motion_analyzers[user_id]

        # Add motion data
        analyzer.add_motion_data(
            raw_data.accelerometer_x, raw_data.accelerometer_y, raw_data.accelerometer_z
        )

        # Calculate metrics
        motion_variance = analyzer.calculate_motion_variance()
        is_stationary = analyzer.is_stationary()

        return motion_variance, is_stationary

    async def get_user_sensor_summary(self, user_id: str) -> Dict[str, Any]:
        """Get summary of recent sensor data for user"""
        summary = {
            "user_id": user_id,
            "has_speed_data": user_id in self.speed_windows,
            "has_motion_data": user_id in self.motion_analyzers,
            "speed_window_size": len(self.speed_windows.get(user_id, [])),
            "motion_window_size": len(self.motion_analyzers[user_id].motion_history)
            if user_id in self.motion_analyzers
            else 0,
        }

        # Recent speed data
        if user_id in self.speed_windows and self.speed_windows[user_id]:
            speeds = list(self.speed_windows[user_id])
            summary["recent_speeds"] = {
                "current": speeds[-1],
                "average": sum(speeds) / len(speeds),
                "max": max(speeds),
                "min": min(speeds),
            }

        # Recent motion data
        if user_id in self.motion_analyzers:
            analyzer = self.motion_analyzers[user_id]
            summary["motion_analysis"] = {
                "variance": analyzer.calculate_motion_variance(),
                "is_stationary": analyzer.is_stationary(),
            }

        return summary

    def cleanup_user_data(self, user_id: str):
        """Clean up stored data for user"""
        if user_id in self.speed_windows:
            del self.speed_windows[user_id]
        if user_id in self.motion_analyzers:
            del self.motion_analyzers[user_id]
        logger.info(f"Cleaned up sensor data for user {user_id}")


# Global instance
sensor_processor = SensorDataProcessor()
