"""
Trip business logic service
"""

from typing import List, Dict, Any, Optional
from app.database import supabase_client
import logging

logger = logging.getLogger(__name__)


class TripService:
    """Service for trip-related business logic"""

    def __init__(self):
        self.client = supabase_client

    async def get_trip_by_id(
        self, trip_id: str, user_id: str
    ) -> Optional[Dict[str, Any]]:
        """Get a trip by ID, ensuring it belongs to the user"""
        try:
            response = (
                self.client.table("trips")
                .select("*")
                .eq("id", trip_id)
                .eq("user_id", user_id)
                .execute()
            )

            return response.data[0] if response.data else None
        except Exception as e:
            logger.error(f"Error getting trip {trip_id}: {e}")
            return None

    async def update_trip(
        self, trip_id: str, update_data: Dict[str, Any], user_id: str
    ) -> bool:
        """Update a trip"""
        try:
            response = (
                self.client.table("trips")
                .update(update_data)
                .eq("id", trip_id)
                .eq("user_id", user_id)
                .execute()
            )

            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Error updating trip {trip_id}: {e}")
            return False

    async def delete_trip(self, trip_id: str, user_id: str) -> bool:
        """Delete a trip"""
        try:
            response = (
                self.client.table("trips")
                .delete()
                .eq("id", trip_id)
                .eq("user_id", user_id)
                .execute()
            )

            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Error deleting trip {trip_id}: {e}")
            return False

    async def create_trips_batch(self, trips_data: List[Dict[str, Any]]) -> int:
        """Create multiple trips in batch"""
        try:
            response = self.client.table("trips").insert(trips_data).execute()
            return len(response.data) if response.data else 0
        except Exception as e:
            logger.error(f"Error creating trips batch: {e}")
            return 0

    async def validate_trip_data(self, trip_data: Dict[str, Any]) -> Dict[str, Any]:
        """Validate and enrich trip data"""
        # Add validation logic here
        # For example: validate coordinates, calculate distance, etc.

        # Basic validation
        start_location = trip_data.get("start_location", {})
        end_location = trip_data.get("end_location", {})

        if (
            not start_location
            or "lat" not in start_location
            or "lng" not in start_location
        ):
            raise ValueError("Invalid start location")

        # Calculate distance if end location is provided
        if end_location and "lat" in end_location and "lng" in end_location:
            distance = self._calculate_distance(start_location, end_location)
            trip_data["distance_km"] = distance

        return trip_data

    def _calculate_distance(
        self, start: Dict[str, float], end: Dict[str, float]
    ) -> float:
        """Calculate distance between two points using Haversine formula"""
        from math import radians, cos, sin, asin, sqrt

        # Convert decimal degrees to radians
        lat1, lon1, lat2, lon2 = map(
            radians, [start["lat"], start["lng"], end["lat"], end["lng"]]
        )

        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))

        # Radius of earth in kilometers
        r = 6371

        return c * r


