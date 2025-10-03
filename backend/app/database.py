"""
Supabase database client and utilities
"""

from supabase import create_client, Client
from app.config import settings
from typing import Optional, Dict, Any, List
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

# Initialize Supabase client
supabase_client: Optional[Client] = None


def initialize_supabase():
    """Initialize Supabase client with error handling"""
    global supabase_client
    try:
        if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
            logger.warning(
                "Supabase credentials not configured. Database operations will be disabled."
            )
            return None

        if (
            settings.SUPABASE_SERVICE_ROLE_KEY
            == "PLACEHOLDER_REPLACE_WITH_ACTUAL_SERVICE_ROLE_KEY"
        ):
            logger.warning(
                "Supabase service role key is placeholder. Database operations will be disabled."
            )
            return None

        supabase_client = create_client(
            settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY
        )
        logger.info("Supabase client initialized successfully")
        return supabase_client
    except Exception as e:
        logger.error(f"Failed to initialize Supabase client: {e}")
        return None


# Initialize on import
initialize_supabase()


class SupabaseService:
    """Service class for Supabase operations"""

    def __init__(self):
        self.client = supabase_client

    def _check_client(self) -> bool:
        """Check if Supabase client is available"""
        if self.client is None:
            logger.warning(
                "Supabase client not initialized. Database operation skipped."
            )
            return False
        return True

    async def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        if not self._check_client():
            return None
        try:
            response = (
                self.client.table("users").select("*").eq("id", user_id).execute()
            )
            return response.data[0] if response.data else None
        except Exception as e:
            logger.error(f"Error getting user {user_id}: {e}")
            return None

    async def create_user_profile(self, user_id: str, email: str = None) -> Optional[Dict[str, Any]]:
        """Create user profile in public.users table"""
        if not self._check_client():
            return None
        try:
            user_data = {
                "id": user_id,
                "email": email,
                "created_at": "now()",
                "updated_at": "now()"
            }
            response = self.client.table("users").insert(user_data).execute()
            if response.data:
                logger.info(f"Created user profile for {user_id}")
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error creating user profile for {user_id}: {e}")
            return None

    async def create_trip(self, trip_data: Dict[str, Any]) -> Optional[str]:
        """Create a new trip"""
        if not self._check_client():
            return None
        try:
            response = self.client.table("trips").insert(trip_data).execute()
            return response.data[0]["id"] if response.data else None
        except Exception as e:
            logger.error(f"Error creating trip: {e}")
            return None

    async def get_user_trips(
        self, user_id: str, limit: int = 100, offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get trips for a user"""
        if not self._check_client():
            return []
        try:
            response = (
                self.client.table("trips")
                .select("*")
                .eq("user_id", user_id)
                .order("created_at", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
            )
            return response.data or []
        except Exception as e:
            logger.error(f"Error getting trips for user {user_id}: {e}")
            return []

    async def save_locations_batch(self, locations: List[Dict[str, Any]]) -> bool:
        """Save multiple location points"""
        if not self._check_client():
            return False
        try:
            response = self.client.table("locations").insert(locations).execute()
            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Error saving location batch: {e}")
            return False

    async def get_trip_analytics(
        self, user_id: str, start_date: str, end_date: str
    ) -> Dict[str, Any]:
        """Get analytics data for trips"""
        if not self._check_client():
            return {}
        try:
            # Get trips in date range
            response = (
                self.client.table("trips")
                .select("*")
                .eq("user_id", user_id)
                .gte("created_at", start_date)
                .lte("created_at", end_date)
                .execute()
            )

            trips = response.data or []

            # Calculate analytics
            total_trips = len(trips)
            total_distance = sum(trip.get("distance_km", 0) for trip in trips)
            total_duration = sum(trip.get("duration_min", 0) for trip in trips)

            # Mode distribution
            mode_counts = {}
            for trip in trips:
                mode = trip.get("mode", "unknown")
                mode_counts[mode] = mode_counts.get(mode, 0) + 1

            return {
                "total_trips": total_trips,
                "total_distance_km": total_distance,
                "total_duration_min": total_duration,
                "avg_distance_km": total_distance / total_trips
                if total_trips > 0
                else 0,
                "avg_duration_min": total_duration / total_trips
                if total_trips > 0
                else 0,
                "mode_distribution": mode_counts,
                "trips": trips,
            }
        except Exception as e:
            logger.error(f"Error getting analytics: {e}")
            return {}

    async def save_trip_record(self, trip_data: Dict[str, Any]) -> bool:
        """Save a trip record to the trips table (compatible with Flutter format)"""
        if not self._check_client():
            return False
        try:
            # Convert backend trip format to Flutter-compatible format
            flutter_trip_data = {
                "user_id": trip_data["user_id"],
                "start_location": {
                    "lat": trip_data.get("start_latitude", 0.0),
                    "lng": trip_data.get("start_longitude", 0.0),
                },
                "end_location": {
                    "lat": trip_data.get("end_latitude", 0.0),
                    "lng": trip_data.get("end_longitude", 0.0),
                },
                "distance_km": trip_data.get("total_distance_km", 0.0),
                "duration_min": trip_data.get("duration_minutes", 0),
                "timestamp": trip_data.get("start_time", datetime.now().isoformat()),
                "mode": trip_data.get("mode", "unknown"),
                "purpose": trip_data.get("purpose", "unknown"),
                "companions": trip_data.get(
                    "companions", {"adults": 0, "children": 0, "seniors": 0}
                ),
                "is_recurring": False,
                "trip_number": trip_data.get("trip_number"),
                "chain_id": trip_data.get("chain_id"),
                "notes": trip_data.get("notes"),
                # Add end time if available
                "end_time": trip_data.get("end_time"),
            }

            logger.info(f"Attempting to save trip record: {flutter_trip_data}")
            response = self.client.table("trips").insert(flutter_trip_data).execute()
            success = len(response.data) > 0 if response.data else False

            if success:
                logger.info(
                    f"✅ Successfully saved trip record for user {trip_data['user_id']}: {response.data}"
                )
            else:
                logger.warning(
                    f"❌ Failed to save trip record for user {trip_data['user_id']}: {response}"
                )

            return success

        except Exception as e:
            logger.error(f"Error saving trip record: {e}")
            return False

    async def save_trip_points(
        self, trip_id: str, gps_points: List[Dict[str, Any]]
    ) -> bool:
        """Save GPS points for a trip to the locations table"""
        if not self._check_client():
            return False
        try:
            # Convert GPS points to locations table format
            location_data = []
            for point in gps_points:
                location_data.append(
                    {
                        "user_id": point.get("user_id"),
                        "trip_id": trip_id,
                        "latitude": point.get("latitude"),
                        "longitude": point.get("longitude"),
                        "accuracy": point.get("accuracy"),
                        "altitude": point.get("altitude"),
                        "speed": point.get("speed_kmh"),
                        "heading": point.get("bearing"),
                        "timestamp": point.get("timestamp", datetime.now().isoformat()),
                        "client_timestamp_ms": point.get(
                            "client_timestamp_ms",
                            int(datetime.now().timestamp() * 1000),
                        ),  # Required field
                        "timezone_offset_minutes": 0,  # Default value
                    }
                )

            if location_data:
                response = (
                    self.client.table("locations").insert(location_data).execute()
                )
                success = len(response.data) > 0 if response.data else False

                if success:
                    logger.info(
                        f"Successfully saved {len(location_data)} GPS points for trip {trip_id}"
                    )
                else:
                    logger.warning(f"Failed to save GPS points for trip {trip_id}")

                return success

            return True  # No points to save is considered success

        except Exception as e:
            logger.error(f"Error saving trip points for trip {trip_id}: {e}")
            return False


# Global service instance
db_service = SupabaseService()
