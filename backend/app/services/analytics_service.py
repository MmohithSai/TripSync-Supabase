"""
Analytics and data processing service
"""

from typing import Dict, Any, List
from app.database import supabase_client
import json
import csv
from io import StringIO
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class AnalyticsService:
    """Service for analytics and data processing"""

    def __init__(self):
        self.client = supabase_client

    async def get_mode_distribution(
        self, user_id: str, start_date: str, end_date: str
    ) -> Dict[str, Any]:
        """Get transportation mode distribution"""
        try:
            response = (
                self.client.table("trips")
                .select("mode")
                .eq("user_id", user_id)
                .gte("created_at", start_date)
                .lte("created_at", end_date)
                .execute()
            )

            trips = response.data or []

            # Count modes
            mode_counts = {}
            for trip in trips:
                mode = trip.get("mode", "unknown")
                mode_counts[mode] = mode_counts.get(mode, 0) + 1

            # Calculate percentages
            total_trips = sum(mode_counts.values())
            mode_percentages = {}
            if total_trips > 0:
                for mode, count in mode_counts.items():
                    mode_percentages[mode] = {
                        "count": count,
                        "percentage": round((count / total_trips) * 100, 2),
                    }

            return {"total_trips": total_trips, "distribution": mode_percentages}
        except Exception as e:
            logger.error(f"Error getting mode distribution: {e}")
            return {"total_trips": 0, "distribution": {}}

    async def calculate_carbon_footprint(
        self, user_id: str, start_date: str, end_date: str
    ) -> Dict[str, Any]:
        """Calculate carbon footprint based on trips"""
        try:
            response = (
                self.client.table("trips")
                .select("mode, distance_km")
                .eq("user_id", user_id)
                .gte("created_at", start_date)
                .lte("created_at", end_date)
                .execute()
            )

            trips = response.data or []

            # Carbon emission factors (kg CO2 per km)
            emission_factors = {
                "car": 0.21,
                "bus": 0.089,
                "train": 0.041,
                "metro": 0.041,
                "scooter": 0.084,
                "bicycle": 0.0,
                "walk": 0.0,
                "unknown": 0.15,  # Average estimate
            }

            total_emissions = 0.0
            mode_emissions = {}

            for trip in trips:
                mode = trip.get("mode", "unknown")
                distance = trip.get("distance_km", 0.0)

                emission = distance * emission_factors.get(mode, 0.15)
                total_emissions += emission

                if mode not in mode_emissions:
                    mode_emissions[mode] = {"distance": 0.0, "emissions": 0.0}

                mode_emissions[mode]["distance"] += distance
                mode_emissions[mode]["emissions"] += emission

            return {
                "total_emissions_kg": round(total_emissions, 2),
                "by_mode": mode_emissions,
                "period": {"start_date": start_date, "end_date": end_date},
            }
        except Exception as e:
            logger.error(f"Error calculating carbon footprint: {e}")
            return {"total_emissions_kg": 0.0, "by_mode": {}}

    async def get_location_heatmap(
        self, user_id: str, start_date: str, end_date: str
    ) -> Dict[str, Any]:
        """Get location data for heatmap visualization"""
        try:
            response = (
                self.client.table("locations")
                .select("latitude, longitude, created_at")
                .eq("user_id", user_id)
                .gte("created_at", start_date)
                .lte("created_at", end_date)
                .execute()
            )

            locations = response.data or []

            # Process locations for heatmap
            heatmap_points = []
            for loc in locations:
                heatmap_points.append(
                    {
                        "lat": loc["latitude"],
                        "lng": loc["longitude"],
                        "intensity": 1,  # Can be adjusted based on frequency
                    }
                )

            # Calculate center point
            if heatmap_points:
                center_lat = sum(p["lat"] for p in heatmap_points) / len(heatmap_points)
                center_lng = sum(p["lng"] for p in heatmap_points) / len(heatmap_points)
            else:
                center_lat, center_lng = 0.0, 0.0

            return {
                "points": heatmap_points,
                "center": {"lat": center_lat, "lng": center_lng},
                "total_points": len(heatmap_points),
            }
        except Exception as e:
            logger.error(f"Error getting heatmap data: {e}")
            return {"points": [], "center": {"lat": 0.0, "lng": 0.0}, "total_points": 0}

    async def export_trip_data(
        self, user_id: str, start_date: str, end_date: str, format: str = "csv"
    ) -> Dict[str, Any]:
        """Export trip data in specified format"""
        try:
            response = (
                self.client.table("trips")
                .select("*")
                .eq("user_id", user_id)
                .gte("created_at", start_date)
                .lte("created_at", end_date)
                .order("created_at", desc=True)
                .execute()
            )

            trips = response.data or []

            if format.lower() == "csv":
                return self._export_as_csv(trips)
            elif format.lower() == "json":
                return self._export_as_json(trips)
            else:
                raise ValueError(f"Unsupported export format: {format}")

        except Exception as e:
            logger.error(f"Error exporting trip data: {e}")
            return {"error": str(e)}

    def _export_as_csv(self, trips: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Export trips as CSV format"""
        if not trips:
            return {"format": "csv", "data": "", "count": 0}

        # Convert to CSV using built-in csv module
        output = StringIO()
        if trips:
            fieldnames = trips[0].keys()
            writer = csv.DictWriter(output, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(trips)

        csv_data = output.getvalue()
        output.close()

        return {
            "format": "csv",
            "data": csv_data,
            "count": len(trips),
            "filename": f"trips_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
        }

    def _export_as_json(self, trips: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Export trips as JSON format"""
        return {
            "format": "json",
            "data": json.dumps(trips, indent=2, default=str),
            "count": len(trips),
            "filename": f"trips_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json",
        }

    async def generate_weekly_summary(self, user_id: str) -> Dict[str, Any]:
        """Generate weekly summary for user"""
        try:
            # Get last 7 days of data
            from datetime import timedelta

            end_date = datetime.now()
            start_date = end_date - timedelta(days=7)

            response = (
                self.client.table("trips")
                .select("*")
                .eq("user_id", user_id)
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )

            trips = response.data or []

            # Calculate summary statistics
            total_trips = len(trips)
            total_distance = sum(trip.get("distance_km", 0) for trip in trips)
            total_duration = sum(trip.get("duration_min", 0) for trip in trips)

            # Most common mode
            mode_counts = {}
            for trip in trips:
                mode = trip.get("mode", "unknown")
                mode_counts[mode] = mode_counts.get(mode, 0) + 1

            most_common_mode = (
                max(mode_counts, key=mode_counts.get) if mode_counts else "none"
            )

            return {
                "period": "last_7_days",
                "total_trips": total_trips,
                "total_distance_km": round(total_distance, 2),
                "total_duration_hours": round(total_duration / 60, 2),
                "avg_trip_distance": round(total_distance / total_trips, 2)
                if total_trips > 0
                else 0,
                "most_common_mode": most_common_mode,
                "mode_distribution": mode_counts,
            }
        except Exception as e:
            logger.error(f"Error generating weekly summary: {e}")
            return {"error": str(e)}
