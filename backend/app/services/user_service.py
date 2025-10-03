"""
User management service
"""

from typing import Dict, Any, Optional
from app.database import supabase_client
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class UserService:
    """Service for user-related operations"""

    def __init__(self):
        self.client = supabase_client

    async def get_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user profile"""
        try:
            response = (
                self.client.table("users").select("*").eq("id", user_id).execute()
            )

            return response.data[0] if response.data else None
        except Exception as e:
            logger.error(f"Error getting user profile: {e}")
            return None

    async def update_user_profile(
        self, user_id: str, profile_data: Dict[str, Any]
    ) -> bool:
        """Update user profile"""
        try:
            # Add updated timestamp
            profile_data["updated_at"] = datetime.now().isoformat()

            response = (
                self.client.table("users")
                .update(profile_data)
                .eq("id", user_id)
                .execute()
            )

            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Error updating user profile: {e}")
            return False

    async def get_user_stats(self, user_id: str) -> Dict[str, Any]:
        """Get comprehensive user statistics"""
        try:
            # Get user creation date
            user_response = (
                self.client.table("users")
                .select("created_at")
                .eq("id", user_id)
                .execute()
            )

            user_data = user_response.data[0] if user_response.data else {}
            created_at = user_data.get("created_at")

            # Calculate account age
            account_age_days = 0
            if created_at:
                created_date = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
                account_age_days = (
                    datetime.now() - created_date.replace(tzinfo=None)
                ).days

            # Get trip statistics
            trips_response = (
                self.client.table("trips")
                .select("mode, distance_km, duration_min")
                .eq("user_id", user_id)
                .execute()
            )

            trips = trips_response.data or []

            # Calculate statistics
            total_trips = len(trips)
            total_distance = sum(trip.get("distance_km", 0) for trip in trips)
            total_duration = sum(trip.get("duration_min", 0) for trip in trips)

            # Find most common mode
            mode_counts = {}
            for trip in trips:
                mode = trip.get("mode", "unknown")
                mode_counts[mode] = mode_counts.get(mode, 0) + 1

            most_common_mode = (
                max(mode_counts, key=mode_counts.get) if mode_counts else "none"
            )

            return {
                "total_trips": total_trips,
                "total_distance_km": round(total_distance, 2),
                "total_duration_hours": round(total_duration / 60, 2),
                "most_common_mode": most_common_mode,
                "account_age_days": account_age_days,
                "avg_trips_per_day": round(total_trips / max(account_age_days, 1), 2),
                "avg_distance_per_trip": round(total_distance / max(total_trips, 1), 2),
            }
        except Exception as e:
            logger.error(f"Error getting user stats: {e}")
            return {
                "total_trips": 0,
                "total_distance_km": 0.0,
                "total_duration_hours": 0.0,
                "most_common_mode": "none",
                "account_age_days": 0,
                "avg_trips_per_day": 0.0,
                "avg_distance_per_trip": 0.0,
            }

    async def delete_user_account(self, user_id: str) -> bool:
        """Delete user account and all associated data"""
        try:
            # Delete in order due to foreign key constraints

            # 1. Delete locations
            self.client.table("locations").delete().eq("user_id", user_id).execute()

            # 2. Delete trips
            self.client.table("trips").delete().eq("user_id", user_id).execute()

            # 3. Delete saved places if exists
            try:
                self.client.table("saved_places").delete().eq(
                    "user_id", user_id
                ).execute()
            except:
                pass  # Table might not exist

            # 4. Delete user profile
            response = self.client.table("users").delete().eq("id", user_id).execute()

            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Error deleting user account: {e}")
            return False

    async def create_user_profile(self, user_id: str, email: str) -> bool:
        """Create user profile (called after Supabase auth signup)"""
        try:
            user_data = {
                "id": user_id,
                "email": email,
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
            }

            response = self.client.table("users").insert(user_data).execute()
            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Error creating user profile: {e}")
            return False


