"""
ML Backend for Enhanced Trip Detection

Optional machine learning models to improve trip detection accuracy
and transportation mode classification.
"""

from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from enum import Enum
import logging
import json
import statistics
from collections import deque, defaultdict

logger = logging.getLogger(__name__)


class TransportMode(Enum):
    """Transportation modes for ML classification"""

    WALKING = "walking"
    RUNNING = "running"
    CYCLING = "cycling"
    CAR = "car"
    BUS = "bus"
    TRAIN = "train"
    METRO = "metro"
    STATIONARY = "stationary"
    UNKNOWN = "unknown"


@dataclass
class MLFeatures:
    """Feature set for ML models"""

    # Speed features
    avg_speed_kmh: float
    max_speed_kmh: float
    speed_variance: float
    speed_percentile_95: float

    # Acceleration features
    avg_acceleration: float
    max_acceleration: float
    acceleration_variance: float

    # Movement patterns
    stop_frequency: float  # stops per minute
    direction_changes: int
    distance_straight_line: float
    distance_actual: float

    # Time features
    duration_minutes: float
    time_of_day: int  # hour of day
    day_of_week: int

    # Activity recognition
    activity_confidence: float
    activity_consistency: float

    # GPS quality
    avg_accuracy: float
    gps_point_count: int

    # Motion sensors (if available)
    motion_variance: Optional[float] = None
    stationary_periods: Optional[int] = None


class FeatureExtractor:
    """Extracts ML features from sensor data and GPS points"""

    def __init__(self):
        self.config = {
            "min_points_for_features": 10,
            "stop_speed_threshold": 2.0,  # km/h
            "direction_change_threshold": 45,  # degrees
        }

    def extract_features(
        self, gps_points: List[Dict[str, Any]], sensor_data: List[Dict[str, Any]] = None
    ) -> Optional[MLFeatures]:
        """
        Extract features from GPS points and sensor data

        Args:
            gps_points: List of GPS points with lat, lon, timestamp, speed, etc.
            sensor_data: Optional sensor data for enhanced features

        Returns:
            MLFeatures object or None if insufficient data
        """
        try:
            if len(gps_points) < self.config["min_points_for_features"]:
                return None

            # Sort points by timestamp
            sorted_points = sorted(gps_points, key=lambda x: x.get("timestamp", 0))

            # Extract basic features
            speed_features = self._extract_speed_features(sorted_points)
            movement_features = self._extract_movement_features(sorted_points)
            time_features = self._extract_time_features(sorted_points)
            gps_features = self._extract_gps_features(sorted_points)

            # Extract sensor features if available
            sensor_features = {}
            if sensor_data:
                sensor_features = self._extract_sensor_features(sensor_data)

            # Combine all features
            features = MLFeatures(
                **speed_features,
                **movement_features,
                **time_features,
                **gps_features,
                **sensor_features,
            )

            return features

        except Exception as e:
            logger.error(f"Failed to extract features: {e}")
            return None

    def _extract_speed_features(self, points: List[Dict[str, Any]]) -> Dict[str, float]:
        """Extract speed-related features"""
        speeds = [
            p.get("speed_kmh", 0) for p in points if p.get("speed_kmh") is not None
        ]

        if not speeds:
            return {
                "avg_speed_kmh": 0.0,
                "max_speed_kmh": 0.0,
                "speed_variance": 0.0,
                "speed_percentile_95": 0.0,
            }

        # Calculate accelerations
        accelerations = []
        for i in range(1, len(speeds)):
            time_diff = 1.0  # Assume 1 second intervals for simplicity
            accel = abs(speeds[i] - speeds[i - 1]) / time_diff
            accelerations.append(accel)

        return {
            "avg_speed_kmh": statistics.mean(speeds),
            "max_speed_kmh": max(speeds),
            "speed_variance": statistics.variance(speeds) if len(speeds) > 1 else 0.0,
            "speed_percentile_95": self._percentile(speeds, 95),
            "avg_acceleration": statistics.mean(accelerations)
            if accelerations
            else 0.0,
            "max_acceleration": max(accelerations) if accelerations else 0.0,
            "acceleration_variance": statistics.variance(accelerations)
            if len(accelerations) > 1
            else 0.0,
        }

    def _extract_movement_features(
        self, points: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Extract movement pattern features"""

        # Calculate stops
        stop_count = 0
        for point in points:
            if point.get("speed_kmh", 0) < self.config["stop_speed_threshold"]:
                stop_count += 1

        duration_hours = self._calculate_duration_hours(points)
        stop_frequency = (
            (stop_count / (duration_hours * 60)) if duration_hours > 0 else 0
        )

        # Calculate direction changes
        direction_changes = self._calculate_direction_changes(points)

        # Calculate distances
        distance_actual = self._calculate_actual_distance(points)
        distance_straight = self._calculate_straight_line_distance(points)

        return {
            "stop_frequency": stop_frequency,
            "direction_changes": direction_changes,
            "distance_actual": distance_actual,
            "distance_straight_line": distance_straight,
        }

    def _extract_time_features(self, points: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Extract time-related features"""
        if not points:
            return {"duration_minutes": 0.0, "time_of_day": 0, "day_of_week": 0}

        first_point = points[0]
        last_point = points[-1]

        # Parse timestamps
        start_time = datetime.fromtimestamp(first_point.get("timestamp", 0))
        end_time = datetime.fromtimestamp(last_point.get("timestamp", 0))

        duration = (end_time - start_time).total_seconds() / 60  # minutes

        return {
            "duration_minutes": duration,
            "time_of_day": start_time.hour,
            "day_of_week": start_time.weekday(),
        }

    def _extract_gps_features(self, points: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Extract GPS quality features"""
        accuracies = [
            p.get("accuracy", 100) for p in points if p.get("accuracy") is not None
        ]

        return {
            "avg_accuracy": statistics.mean(accuracies) if accuracies else 100.0,
            "gps_point_count": len(points),
            "activity_confidence": 0.5,  # Default, should be extracted from sensor data
            "activity_consistency": 0.5,  # Default, should be calculated from activity changes
        }

    def _extract_sensor_features(
        self, sensor_data: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Extract features from sensor data"""
        features = {}

        # Motion variance
        motion_values = []
        for data in sensor_data:
            if all(key in data for key in ["accel_x", "accel_y", "accel_z"]):
                magnitude = (
                    data["accel_x"] ** 2 + data["accel_y"] ** 2 + data["accel_z"] ** 2
                ) ** 0.5
                motion_values.append(magnitude)

        if motion_values:
            features["motion_variance"] = (
                statistics.variance(motion_values) if len(motion_values) > 1 else 0.0
            )

        # Activity confidence
        confidences = [d.get("activity_confidence", 0.5) for d in sensor_data]
        if confidences:
            features["activity_confidence"] = statistics.mean(confidences)

        return features

    def _percentile(self, data: List[float], percentile: int) -> float:
        """Calculate percentile of data"""
        if not data:
            return 0.0
        sorted_data = sorted(data)
        index = int((percentile / 100) * len(sorted_data))
        return sorted_data[min(index, len(sorted_data) - 1)]

    def _calculate_duration_hours(self, points: List[Dict[str, Any]]) -> float:
        """Calculate duration in hours"""
        if len(points) < 2:
            return 0.0

        start_time = points[0].get("timestamp", 0)
        end_time = points[-1].get("timestamp", 0)

        return (end_time - start_time) / 3600  # Convert to hours

    def _calculate_direction_changes(self, points: List[Dict[str, Any]]) -> int:
        """Calculate number of significant direction changes"""
        if len(points) < 3:
            return 0

        direction_changes = 0
        threshold = self.config["direction_change_threshold"]

        for i in range(2, len(points)):
            # Calculate bearings
            bearing1 = self._calculate_bearing(points[i - 2], points[i - 1])
            bearing2 = self._calculate_bearing(points[i - 1], points[i])

            # Calculate angle difference
            angle_diff = abs(bearing2 - bearing1)
            if angle_diff > 180:
                angle_diff = 360 - angle_diff

            if angle_diff > threshold:
                direction_changes += 1

        return direction_changes

    def _calculate_bearing(
        self, point1: Dict[str, Any], point2: Dict[str, Any]
    ) -> float:
        """Calculate bearing between two points"""
        from math import atan2, cos, sin, radians, degrees

        lat1 = radians(point1.get("latitude", 0))
        lat2 = radians(point2.get("latitude", 0))
        lon1 = radians(point1.get("longitude", 0))
        lon2 = radians(point2.get("longitude", 0))

        dlon = lon2 - lon1

        y = sin(dlon) * cos(lat2)
        x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlon)

        bearing = degrees(atan2(y, x))
        return (bearing + 360) % 360

    def _calculate_actual_distance(self, points: List[Dict[str, Any]]) -> float:
        """Calculate actual distance traveled"""
        if len(points) < 2:
            return 0.0

        total_distance = 0.0
        for i in range(1, len(points)):
            distance = self._haversine_distance(points[i - 1], points[i])
            total_distance += distance

        return total_distance

    def _calculate_straight_line_distance(self, points: List[Dict[str, Any]]) -> float:
        """Calculate straight-line distance between start and end"""
        if len(points) < 2:
            return 0.0

        return self._haversine_distance(points[0], points[-1])

    def _haversine_distance(
        self, point1: Dict[str, Any], point2: Dict[str, Any]
    ) -> float:
        """Calculate haversine distance between two points in kilometers"""
        from math import radians, cos, sin, asin, sqrt

        lat1 = radians(point1.get("latitude", 0))
        lon1 = radians(point1.get("longitude", 0))
        lat2 = radians(point2.get("latitude", 0))
        lon2 = radians(point2.get("longitude", 0))

        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))

        return c * 6371  # Earth radius in kilometers


class SimpleMLClassifier:
    """
    Simple rule-based classifier for transportation mode detection

    This is a placeholder for more sophisticated ML models.
    In production, you would use trained models like Random Forest, LSTM, etc.
    """

    def __init__(self):
        self.rules = self._initialize_classification_rules()

    def _initialize_classification_rules(self) -> Dict[str, Any]:
        """Initialize classification rules"""
        return {
            "speed_thresholds": {
                "walking": (0, 8),  # 0-8 km/h
                "cycling": (8, 25),  # 8-25 km/h
                "car": (15, 120),  # 15-120 km/h
                "bus": (10, 80),  # 10-80 km/h
                "train": (30, 200),  # 30-200 km/h
            },
            "acceleration_thresholds": {
                "walking": (0, 2),
                "cycling": (0, 3),
                "car": (0, 5),
                "bus": (0, 4),
                "train": (0, 3),
            },
            "stop_frequency_thresholds": {
                "walking": (0, 10),  # stops per hour
                "cycling": (0, 5),
                "car": (2, 20),
                "bus": (5, 30),
                "train": (1, 10),
            },
        }

    def classify_transport_mode(
        self, features: MLFeatures
    ) -> Tuple[TransportMode, float]:
        """
        Classify transportation mode based on features

        Args:
            features: Extracted ML features

        Returns:
            Tuple of (predicted_mode, confidence)
        """
        try:
            scores = {}

            # Score each transport mode
            for mode in ["walking", "cycling", "car", "bus", "train"]:
                score = self._calculate_mode_score(features, mode)
                scores[mode] = score

            # Find best match
            best_mode = max(scores, key=scores.get)
            confidence = scores[best_mode]

            # Convert to enum
            mode_enum = TransportMode(best_mode)

            return mode_enum, confidence

        except Exception as e:
            logger.error(f"Classification failed: {e}")
            return TransportMode.UNKNOWN, 0.0

    def _calculate_mode_score(self, features: MLFeatures, mode: str) -> float:
        """Calculate score for a specific transport mode"""
        score = 0.0
        weight_sum = 0.0

        # Speed score
        speed_range = self.rules["speed_thresholds"][mode]
        speed_score = self._score_in_range(features.avg_speed_kmh, speed_range)
        score += speed_score * 0.4
        weight_sum += 0.4

        # Acceleration score
        accel_range = self.rules["acceleration_thresholds"][mode]
        accel_score = self._score_in_range(features.avg_acceleration, accel_range)
        score += accel_score * 0.3
        weight_sum += 0.3

        # Stop frequency score
        stop_range = self.rules["stop_frequency_thresholds"][mode]
        stop_score = self._score_in_range(features.stop_frequency, stop_range)
        score += stop_score * 0.3
        weight_sum += 0.3

        return score / weight_sum if weight_sum > 0 else 0.0

    def _score_in_range(self, value: float, range_tuple: Tuple[float, float]) -> float:
        """Score how well a value fits within a range"""
        min_val, max_val = range_tuple

        if min_val <= value <= max_val:
            # Value is in range, score based on how central it is
            range_size = max_val - min_val
            if range_size == 0:
                return 1.0

            center = (min_val + max_val) / 2
            distance_from_center = abs(value - center)
            normalized_distance = distance_from_center / (range_size / 2)

            return max(0.0, 1.0 - normalized_distance)
        else:
            # Value is outside range, score based on distance
            if value < min_val:
                distance = min_val - value
                penalty_range = min_val * 0.5  # 50% of min value
            else:
                distance = value - max_val
                penalty_range = max_val * 0.5  # 50% of max value

            if penalty_range == 0:
                return 0.0

            penalty = distance / penalty_range
            return max(0.0, 1.0 - penalty)


class TripDetectionML:
    """
    ML-enhanced trip detection

    Uses machine learning to improve trip start/stop detection
    and transportation mode classification
    """

    def __init__(self):
        self.feature_extractor = FeatureExtractor()
        self.classifier = SimpleMLClassifier()

        # Feature history for users
        self.user_features: Dict[str, deque] = defaultdict(lambda: deque(maxlen=10))

    async def analyze_trip_data(
        self,
        user_id: str,
        gps_points: List[Dict[str, Any]],
        sensor_data: List[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Analyze trip data using ML models

        Args:
            user_id: User identifier
            gps_points: GPS points from the trip
            sensor_data: Optional sensor data

        Returns:
            Analysis results including transport mode and confidence
        """
        try:
            # Extract features
            features = self.feature_extractor.extract_features(gps_points, sensor_data)
            if not features:
                return {"error": "Insufficient data for analysis"}

            # Classify transport mode
            transport_mode, confidence = self.classifier.classify_transport_mode(
                features
            )

            # Store features for user learning
            self.user_features[user_id].append(features)

            # Calculate trip quality score
            quality_score = self._calculate_trip_quality(features)

            return {
                "transport_mode": transport_mode.value,
                "confidence": confidence,
                "quality_score": quality_score,
                "features": {
                    "avg_speed_kmh": features.avg_speed_kmh,
                    "max_speed_kmh": features.max_speed_kmh,
                    "duration_minutes": features.duration_minutes,
                    "distance_km": features.distance_actual,
                    "stop_frequency": features.stop_frequency,
                    "gps_accuracy": features.avg_accuracy,
                },
                "analysis_timestamp": datetime.now().isoformat(),
            }

        except Exception as e:
            logger.error(f"ML analysis failed for user {user_id}: {e}")
            return {"error": str(e)}

    def _calculate_trip_quality(self, features: MLFeatures) -> float:
        """Calculate overall trip quality score"""
        quality_factors = []

        # GPS quality (higher accuracy = better quality)
        gps_quality = max(0.0, 1.0 - (features.avg_accuracy / 100.0))
        quality_factors.append(gps_quality)

        # Data completeness (more points = better quality)
        data_completeness = min(1.0, features.gps_point_count / 50.0)
        quality_factors.append(data_completeness)

        # Duration reasonableness (2-120 minutes is good)
        if 2 <= features.duration_minutes <= 120:
            duration_quality = 1.0
        else:
            duration_quality = 0.5
        quality_factors.append(duration_quality)

        # Speed consistency (low variance = better quality)
        speed_consistency = max(0.0, 1.0 - (features.speed_variance / 100.0))
        quality_factors.append(speed_consistency)

        return sum(quality_factors) / len(quality_factors)

    async def get_user_travel_patterns(self, user_id: str) -> Dict[str, Any]:
        """Get learned travel patterns for user"""
        if user_id not in self.user_features or not self.user_features[user_id]:
            return {"patterns": "insufficient_data"}

        features_list = list(self.user_features[user_id])

        # Calculate average patterns
        avg_speed = statistics.mean([f.avg_speed_kmh for f in features_list])
        common_times = [f.time_of_day for f in features_list]
        avg_duration = statistics.mean([f.duration_minutes for f in features_list])

        return {
            "user_id": user_id,
            "trip_count": len(features_list),
            "average_speed_kmh": avg_speed,
            "average_duration_minutes": avg_duration,
            "common_travel_hours": list(set(common_times)),
            "last_updated": datetime.now().isoformat(),
        }


# Global instance
ml_backend = TripDetectionML()


