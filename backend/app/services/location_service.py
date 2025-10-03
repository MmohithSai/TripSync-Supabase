"""
Location processing service
"""

from typing import List, Dict, Any
from app.database import supabase_client
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


class LocationService:
    """Service for location-related operations"""

    def __init__(self):
        self.client = supabase_client

    async def save_location(self, location_data: Dict[str, Any]) -> bool:
        """Save a single location point"""
        try:
            # Add server timestamp
            location_data["created_at"] = datetime.now().isoformat()

            response = self.client.table("locations").insert(location_data).execute()
            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Error saving location: {e}")
            return False

    async def get_recent_locations(
        self, user_id: str, limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get recent location points for a user"""
        try:
            response = (
                self.client.table("locations")
                .select("*")
                .eq("user_id", user_id)
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )

            return response.data or []
        except Exception as e:
            logger.error(f"Error getting recent locations: {e}")
            return []

    async def cleanup_old_locations(self, user_id: str, days_old: int = 30) -> int:
        """Clean up location data older than specified days"""
        try:
            cutoff_date = datetime.now() - timedelta(days=days_old)

            response = (
                self.client.table("locations")
                .delete()
                .eq("user_id", user_id)
                .lt("created_at", cutoff_date.isoformat())
                .execute()
            )

            return len(response.data) if response.data else 0
        except Exception as e:
            logger.error(f"Error cleaning up locations: {e}")
            return 0

    async def process_location_batch(
        self, locations: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Process a batch of locations for analytics"""
        if not locations:
            return {"processed": 0, "insights": {}}

        # Basic processing
        total_points = len(locations)

        # Calculate bounding box
        lats = [loc["latitude"] for loc in locations]
        lngs = [loc["longitude"] for loc in locations]

        bounding_box = {
            "north": max(lats),
            "south": min(lats),
            "east": max(lngs),
            "west": min(lngs),
        }

        # Calculate total distance traveled
        total_distance = 0.0
        for i in range(1, len(locations)):
            prev_loc = locations[i - 1]
            curr_loc = locations[i]
            distance = self._calculate_distance(
                prev_loc["latitude"],
                prev_loc["longitude"],
                curr_loc["latitude"],
                curr_loc["longitude"],
            )
            total_distance += distance

        return {
            "processed": total_points,
            "insights": {
                "total_distance_km": total_distance,
                "bounding_box": bounding_box,
                "time_span_hours": self._calculate_time_span(locations),
            },
        }

    def _calculate_distance(
        self, lat1: float, lon1: float, lat2: float, lon2: float
    ) -> float:
        """Calculate distance between two points"""
        from math import radians, cos, sin, asin, sqrt

        # Convert to radians
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])

        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))

        # Earth radius in kilometers
        return c * 6371

    def _calculate_time_span(self, locations: List[Dict[str, Any]]) -> float:
        """Calculate time span of location data in hours"""
        if len(locations) < 2:
            return 0.0

        timestamps = [loc.get("timestamp_ms", 0) for loc in locations]
        timestamps = [ts for ts in timestamps if ts > 0]

        if len(timestamps) < 2:
            return 0.0

        time_span_ms = max(timestamps) - min(timestamps)
        return time_span_ms / (1000 * 60 * 60)  # Convert to hours


