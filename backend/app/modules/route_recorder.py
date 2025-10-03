"""
Route Recorder - The Engine of the Trip Recording System

Responsible for tracking and storing route data during active trips.
Controlled by the Trip State Machine through start() and stop() commands.
"""

from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
import asyncio
import logging
import time
from concurrent.futures import ThreadPoolExecutor
import json

logger = logging.getLogger(__name__)


@dataclass
class GPSPoint:
    """Individual GPS point data"""

    latitude: float
    longitude: float
    timestamp: datetime
    accuracy: float
    speed_kmh: Optional[float] = None
    altitude: Optional[float] = None
    bearing: Optional[float] = None


@dataclass
class TripRecord:
    """Complete trip record with metadata and GPS points"""

    trip_id: str
    user_id: str
    start_time: datetime
    end_time: Optional[datetime] = None
    gps_points: List[GPSPoint] = None
    total_distance_km: Optional[float] = None
    duration_minutes: Optional[int] = None
    status: str = "recording"  # recording, completed, processing

    def __post_init__(self):
        if self.gps_points is None:
            self.gps_points = []


class RouteRecorder:
    """
    Route Recorder Engine

    Handles GPS data collection, storage, and post-processing
    for active trips. Controlled by Trip State Machine.
    """

    def __init__(self, database_service, config: Dict[str, Any] = None):
        self.db_service = database_service
        self.config = config or {
            "gps_collection_interval": 45,  # seconds
            "max_accuracy_threshold": 50,  # meters
            "min_distance_filter": 10,  # meters
            "enable_snap_to_roads": True,
            "batch_size": 100,
        }

        # Active trip records
        self._active_trips: Dict[str, TripRecord] = {}

        # Background tasks
        self._collection_tasks: Dict[str, asyncio.Task] = {}
        self._executor = ThreadPoolExecutor(max_workers=4)

    async def start_recording(self, trip_id: str, user_id: str = None) -> bool:
        """
        Start recording route for a trip
        Called by Trip State Machine when trip becomes active
        """
        try:
            if trip_id in self._active_trips:
                logger.warning(f"Trip {trip_id} already being recorded")
                return False

            # Extract user_id from trip_id if not provided
            if not user_id:
                user_id = trip_id.split("_")[0] if "_" in trip_id else "unknown"

            # Create trip record
            trip_record = TripRecord(
                trip_id=trip_id,
                user_id=user_id,
                start_time=datetime.now(),
                status="recording",
            )

            self._active_trips[trip_id] = trip_record

            # Start GPS collection task
            task = asyncio.create_task(self._gps_collection_loop(trip_id))
            self._collection_tasks[trip_id] = task

            logger.info(f"Started route recording for trip {trip_id}")
            return True

        except Exception as e:
            logger.error(f"Failed to start recording for trip {trip_id}: {e}")
            return False

    async def stop_recording(self, trip_id: str) -> Optional[Dict[str, Any]]:
        """
        Stop recording route for a trip
        Called by Trip State Machine when trip becomes idle
        """
        try:
            if trip_id not in self._active_trips:
                logger.warning(f"Trip {trip_id} not found in active recordings")
                return None

            # Stop GPS collection task
            if trip_id in self._collection_tasks:
                self._collection_tasks[trip_id].cancel()
                del self._collection_tasks[trip_id]

            # Finalize trip record
            trip_record = self._active_trips[trip_id]
            trip_record.end_time = datetime.now()
            trip_record.status = "processing"

            # Calculate duration
            if trip_record.start_time and trip_record.end_time:
                duration = trip_record.end_time - trip_record.start_time
                trip_record.duration_minutes = int(duration.total_seconds() / 60)

            # Process route data
            await self._post_process_trip(trip_record)

            # Save to database
            trip_data = await self._save_trip_to_database(trip_record)

            # Remove from active trips
            del self._active_trips[trip_id]

            logger.info(f"Stopped route recording for trip {trip_id}")
            return trip_data

        except Exception as e:
            logger.error(f"Failed to stop recording for trip {trip_id}: {e}")
            return None

    async def add_gps_point(self, trip_id: str, gps_data: Dict[str, Any]) -> bool:
        """
        Add GPS point to active trip
        Can be called externally or by internal collection loop
        """
        try:
            if trip_id not in self._active_trips:
                logger.warning(f"Trip {trip_id} not active, ignoring GPS point")
                return False

            # Validate GPS data
            if not self._validate_gps_data(gps_data):
                logger.warning(f"Invalid GPS data for trip {trip_id}")
                return False

            # Create GPS point
            gps_point = GPSPoint(
                latitude=gps_data["latitude"],
                longitude=gps_data["longitude"],
                timestamp=datetime.fromtimestamp(
                    gps_data.get("timestamp", datetime.now().timestamp())
                ),
                accuracy=gps_data.get("accuracy", 0),
                speed_kmh=gps_data.get("speed_kmh"),
                altitude=gps_data.get("altitude"),
                bearing=gps_data.get("bearing"),
            )

            # Apply distance filter
            trip_record = self._active_trips[trip_id]
            if self._should_add_point(trip_record, gps_point):
                trip_record.gps_points.append(gps_point)

                # Batch save to database periodically
                if len(trip_record.gps_points) % self.config["batch_size"] == 0:
                    await self._batch_save_gps_points(trip_record)

                return True

            return False

        except Exception as e:
            logger.error(f"Failed to add GPS point for trip {trip_id}: {e}")
            return False

    async def get_active_trip_status(self, trip_id: str) -> Optional[Dict[str, Any]]:
        """Get status of active trip recording"""
        if trip_id not in self._active_trips:
            return None

        trip_record = self._active_trips[trip_id]
        return {
            "trip_id": trip_id,
            "user_id": trip_record.user_id,
            "start_time": trip_record.start_time.isoformat(),
            "status": trip_record.status,
            "gps_points_count": len(trip_record.gps_points),
            "duration_minutes": int(
                (datetime.now() - trip_record.start_time).total_seconds() / 60
            ),
            "estimated_distance_km": self._calculate_distance(trip_record.gps_points)
            if trip_record.gps_points
            else 0,
        }

    async def get_all_active_recordings(self) -> Dict[str, Dict[str, Any]]:
        """Get status of all active recordings"""
        active_status = {}
        for trip_id in self._active_trips:
            status = await self.get_active_trip_status(trip_id)
            if status:
                active_status[trip_id] = status
        return active_status

    async def _gps_collection_loop(self, trip_id: str):
        """Background GPS collection loop for a trip"""
        try:
            interval = self.config["gps_collection_interval"]
            logger.info(
                f"Starting GPS collection loop for trip {trip_id} (interval: {interval}s)"
            )

            while trip_id in self._active_trips:
                try:
                    # In a real implementation, this would collect from device GPS
                    # For now, we'll wait for external GPS data via add_gps_point()
                    await asyncio.sleep(interval)

                    # Check if trip is still active
                    if trip_id not in self._active_trips:
                        break

                    # Log collection status
                    trip_record = self._active_trips[trip_id]
                    logger.debug(
                        f"GPS collection heartbeat for trip {trip_id}: {len(trip_record.gps_points)} points"
                    )

                except asyncio.CancelledError:
                    logger.info(f"GPS collection cancelled for trip {trip_id}")
                    break
                except Exception as e:
                    logger.error(
                        f"Error in GPS collection loop for trip {trip_id}: {e}"
                    )
                    await asyncio.sleep(5)  # Brief pause before retry

        except Exception as e:
            logger.error(f"GPS collection loop failed for trip {trip_id}: {e}")

    def _validate_gps_data(self, gps_data: Dict[str, Any]) -> bool:
        """Validate GPS data quality"""
        required_fields = ["latitude", "longitude"]

        # Check required fields
        for field in required_fields:
            if field not in gps_data:
                return False

        # Check coordinate ranges
        lat = gps_data["latitude"]
        lon = gps_data["longitude"]
        if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            return False

        # Check accuracy threshold
        accuracy = gps_data.get("accuracy", 0)
        if accuracy > self.config["max_accuracy_threshold"]:
            return False

        return True

    def _should_add_point(self, trip_record: TripRecord, new_point: GPSPoint) -> bool:
        """Determine if GPS point should be added based on distance filter"""
        if not trip_record.gps_points:
            return True

        last_point = trip_record.gps_points[-1]
        distance = self._calculate_distance_between_points(last_point, new_point)

        return distance >= self.config["min_distance_filter"]

    def _calculate_distance_between_points(
        self, point1: GPSPoint, point2: GPSPoint
    ) -> float:
        """Calculate distance between two GPS points in meters"""
        from geopy.distance import geodesic

        coord1 = (point1.latitude, point1.longitude)
        coord2 = (point2.latitude, point2.longitude)

        return geodesic(coord1, coord2).meters

    def _calculate_distance(self, gps_points) -> float:
        """Calculate total distance of GPS points in kilometers"""
        if len(gps_points) < 2:
            return 0.0

        from geopy.distance import geodesic

        total_distance = 0.0
        for i in range(1, len(gps_points)):
            prev_point = gps_points[i - 1]
            curr_point = gps_points[i]

            # Handle both GPSPoint objects and dictionaries
            if hasattr(prev_point, "latitude"):
                # GPSPoint object
                coord1 = (prev_point.latitude, prev_point.longitude)
                coord2 = (curr_point.latitude, curr_point.longitude)
            else:
                # Dictionary
                coord1 = (prev_point.get("latitude", 0), prev_point.get("longitude", 0))
                coord2 = (curr_point.get("latitude", 0), curr_point.get("longitude", 0))

            # Calculate distance and filter out unrealistic jumps
            distance_meters = geodesic(coord1, coord2).meters
            if (
                distance_meters < 1000
            ):  # Less than 1km between points (filter GPS errors)
                total_distance += distance_meters

        return total_distance / 1000  # Convert to kilometers

    async def _post_process_trip(self, trip_record: TripRecord):
        """Post-process trip data after recording stops"""
        try:
            logger.info(f"Post-processing trip {trip_record.trip_id}")

            # Calculate total distance
            if trip_record.gps_points:
                trip_record.total_distance_km = self._calculate_distance(
                    trip_record.gps_points
                )

            # Optional: Snap to roads API call
            if self.config.get("enable_snap_to_roads", False):
                await self._snap_to_roads(trip_record)

            trip_record.status = "completed"
            logger.info(f"Post-processing completed for trip {trip_record.trip_id}")

        except Exception as e:
            logger.error(f"Post-processing failed for trip {trip_record.trip_id}: {e}")
            trip_record.status = "error"

    async def _snap_to_roads(self, trip_record: TripRecord):
        """Snap GPS points to road network using external API"""
        try:
            # This would integrate with Google Maps Roads API or similar
            # For now, we'll just log the intent
            logger.info(
                f"Snapping {len(trip_record.gps_points)} points to roads for trip {trip_record.trip_id}"
            )

            # Placeholder for actual API integration
            # snapped_points = await self._call_snap_to_roads_api(trip_record.gps_points)
            # trip_record.gps_points = snapped_points

        except Exception as e:
            logger.error(f"Snap to roads failed for trip {trip_record.trip_id}: {e}")

    async def _batch_save_gps_points(self, trip_record: TripRecord):
        """Save GPS points to database in batches"""
        try:
            # Convert GPS points to database format
            points_data = []
            for point in trip_record.gps_points:
                points_data.append(
                    {
                        "trip_id": trip_record.trip_id,
                        "user_id": trip_record.user_id,
                        "latitude": point.latitude,
                        "longitude": point.longitude,
                        "timestamp": point.timestamp.isoformat(),
                        "accuracy": point.accuracy,
                        "speed_kmh": point.speed_kmh,
                        "altitude": point.altitude,
                        "bearing": point.bearing,
                    }
                )

            # Save to database (implementation depends on database service)
            await self.db_service.save_gps_points_batch(points_data)
            logger.debug(
                f"Saved {len(points_data)} GPS points for trip {trip_record.trip_id}"
            )

        except Exception as e:
            logger.error(
                f"Failed to batch save GPS points for trip {trip_record.trip_id}: {e}"
            )

    async def _save_trip_to_database(self, trip_record: TripRecord) -> Dict[str, Any]:
        """Save complete trip record to database"""
        try:
            # Get start and end coordinates from GPSPoint objects
            start_lat = start_lng = end_lat = end_lng = 0.0
            if trip_record.gps_points:
                first_point = trip_record.gps_points[0]
                last_point = trip_record.gps_points[-1]
                start_lat = first_point.latitude
                start_lng = first_point.longitude
                end_lat = last_point.latitude
                end_lng = last_point.longitude

            # Generate trip number and chain ID
            now = trip_record.start_time or datetime.now()
            trip_number = self._generate_trip_number(now)
            chain_id = self._generate_chain_id(now)

            # Prepare trip data in Flutter-compatible format
            trip_data = {
                "user_id": trip_record.user_id,
                "start_time": trip_record.start_time.isoformat()
                if trip_record.start_time
                else datetime.now().isoformat(),
                "end_time": trip_record.end_time.isoformat()
                if trip_record.end_time
                else None,
                "duration_minutes": trip_record.duration_minutes or 0,
                "total_distance_km": trip_record.total_distance_km or 0.0,
                "start_latitude": start_lat,
                "start_longitude": start_lng,
                "end_latitude": end_lat,
                "end_longitude": end_lng,
                "mode": "unknown",  # Default mode
                "purpose": "unknown",  # Default purpose
                "trip_number": trip_number,
                "chain_id": chain_id,
                "gps_points_count": len(trip_record.gps_points),
                "status": trip_record.status,
            }

            # Save trip metadata to trips table
            success = await self.db_service.save_trip_record(trip_data)

            if success and trip_record.gps_points:
                # Get the actual database trip ID (UUID) from the saved trip
                try:
                    trips_response = (
                        self.db_service.client.table("trips")
                        .select("id")
                        .eq("trip_number", trip_number)
                        .execute()
                    )
                    if trips_response.data and len(trips_response.data) > 0:
                        db_trip_id = trips_response.data[0]["id"]

                        # Convert GPSPoint objects to dictionaries and add user_id
                        enhanced_gps_points = []
                        for point in trip_record.gps_points:
                            # Convert GPSPoint to dictionary with all required fields
                            timestamp_ms = (
                                int(point.timestamp.timestamp() * 1000)
                                if point.timestamp
                                else int(time.time() * 1000)
                            )
                            enhanced_point = {
                                "latitude": point.latitude,
                                "longitude": point.longitude,
                                "accuracy": point.accuracy,
                                "speed_kmh": point.speed_kmh,
                                "altitude": point.altitude,
                                "bearing": point.bearing,
                                "timestamp": point.timestamp.isoformat()
                                if point.timestamp
                                else datetime.now().isoformat(),
                                "client_timestamp_ms": timestamp_ms,  # Required field
                                "user_id": trip_record.user_id,
                            }
                            enhanced_gps_points.append(enhanced_point)

                        # Save GPS points to locations table using the database trip ID
                        await self.db_service.save_trip_points(
                            db_trip_id, enhanced_gps_points
                        )
                        logger.info(
                            f"Saved {len(enhanced_gps_points)} GPS points for trip {db_trip_id}"
                        )
                    else:
                        logger.error(
                            f"Could not find database trip ID for trip number {trip_number}"
                        )
                except Exception as e:
                    logger.error(
                        f"Error saving trip points for trip {trip_record.trip_id}: {e}"
                    )

            if success:
                logger.info(
                    f"Successfully saved trip {trip_record.trip_id} with {len(trip_record.gps_points)} GPS points"
                )
            else:
                logger.error(f"Failed to save trip record {trip_record.trip_id}")

            return trip_data

        except Exception as e:
            logger.error(f"Failed to save trip record {trip_record.trip_id}: {e}")
            return {}

    def _generate_trip_number(self, when: datetime) -> str:
        """Generate a unique trip number"""
        y = str(when.year).zfill(4)
        m = str(when.month).zfill(2)
        d = str(when.day).zfill(2)
        hh = str(when.hour).zfill(2)
        mm = str(when.minute).zfill(2)
        ss = str(when.second).zfill(2)
        return f"TRIP-{y}{m}{d}-{hh}{mm}{ss}"

    def _generate_chain_id(self, when: datetime) -> str:
        """Generate a chain ID for grouping related trips"""
        y = str(when.year).zfill(4)
        m = str(when.month).zfill(2)
        d = str(when.day).zfill(2)
        hh = str(when.hour).zfill(2)
        return f"CHAIN-{y}{m}{d}-{hh}"


class RouteRecorderManager:
    """
    Manager for Route Recorder instances
    Handles multiple concurrent trip recordings
    """

    def __init__(self, database_service):
        self.db_service = database_service
        self.recorder = RouteRecorder(database_service)

    async def start_trip_recording(self, trip_id: str, user_id: str = None) -> bool:
        """Start recording for a trip"""
        return await self.recorder.start_recording(trip_id, user_id)

    async def stop_trip_recording(self, trip_id: str) -> Optional[Dict[str, Any]]:
        """Stop recording for a trip"""
        return await self.recorder.stop_recording(trip_id)

    async def add_gps_data(self, trip_id: str, gps_data: Dict[str, Any]) -> bool:
        """Add GPS data point to active trip"""
        return await self.recorder.add_gps_point(trip_id, gps_data)

    async def get_recording_status(self, trip_id: str = None) -> Dict[str, Any]:
        """Get recording status for trip(s)"""
        if trip_id:
            status = await self.recorder.get_active_trip_status(trip_id)
            return {trip_id: status} if status else {}
        else:
            return await self.recorder.get_all_active_recordings()


# Global instance will be initialized with database service
route_recorder_manager: Optional[RouteRecorderManager] = None
