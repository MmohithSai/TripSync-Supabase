#!/usr/bin/env python3
"""
Check Existing Data - See if there's any data in the database
"""

import os
from supabase import create_client, Client
from datetime import datetime, timedelta

# Set environment variables
os.environ["SUPABASE_URL"] = "https://ixlgntiqgfmsvuqahbnd.supabase.co"
os.environ["SUPABASE_ANON_KEY"] = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGdudGlxZ2Ztc3Z1cWFoYm5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5ODczNDAsImV4cCI6MjA3NDU2MzM0MH0.XXdvZaGmSNQkoy8qrEpluVv8FwDpStkGktPvdnFR6MA"
)


def check_data():
    """Check what data exists in the database"""
    print("🔍 Checking Existing Data in Database...")

    try:
        supabase: Client = create_client(
            os.environ["SUPABASE_URL"], os.environ["SUPABASE_ANON_KEY"]
        )

        # Check users
        print("\n👥 Checking users...")
        users_response = supabase.table("users").select("*").execute()
        users_count = len(users_response.data) if users_response.data else 0
        print(f"📊 Found {users_count} users")

        if users_count > 0:
            print("👤 Users:")
            for user in users_response.data[:5]:  # Show first 5 users
                print(f"   - ID: {user['id'][:8]}... Email: {user.get('email', 'N/A')}")

        # Check trips
        print("\n🚗 Checking trips...")
        trips_response = (
            supabase.table("trips")
            .select("*")
            .order("created_at", desc=True)
            .limit(10)
            .execute()
        )
        trips_count = len(trips_response.data) if trips_response.data else 0
        print(f"📊 Found {trips_count} trips")

        if trips_count > 0:
            print("🚗 Recent trips:")
            for trip in trips_response.data:
                created = trip.get("created_at", "Unknown")
                distance = trip.get("distance_km", 0)
                mode = trip.get("mode", "unknown")
                print(f"   - {created[:19]} | {distance:.1f}km | {mode}")
        else:
            print("❌ No trips found! This confirms the data storage issue.")

        # Check locations
        print("\n📍 Checking locations...")
        locations_response = (
            supabase.table("locations")
            .select("*")
            .order("created_at", desc=True)
            .limit(10)
            .execute()
        )
        locations_count = len(locations_response.data) if locations_response.data else 0
        print(f"📊 Found {locations_count} location points")

        if locations_count > 0:
            print("📍 Recent locations:")
            for loc in locations_response.data[:5]:
                created = loc.get("created_at", "Unknown")
                lat = loc.get("latitude", 0)
                lng = loc.get("longitude", 0)
                print(f"   - {created[:19]} | {lat:.4f}, {lng:.4f}")
        else:
            print("❌ No location points found!")

        # Check for recent data (last 2 days)
        print("\n📅 Checking for data from last 2 days...")
        two_days_ago = (datetime.now() - timedelta(days=2)).isoformat()

        recent_trips = (
            supabase.table("trips")
            .select("*")
            .gte("created_at", two_days_ago)
            .execute()
        )
        recent_locations = (
            supabase.table("locations")
            .select("*")
            .gte("created_at", two_days_ago)
            .execute()
        )

        recent_trips_count = len(recent_trips.data) if recent_trips.data else 0
        recent_locations_count = (
            len(recent_locations.data) if recent_locations.data else 0
        )

        print(
            f"📊 Last 2 days: {recent_trips_count} trips, {recent_locations_count} locations"
        )

        if recent_trips_count == 0 and recent_locations_count == 0:
            print("❌ CONFIRMED: No data from your 2 days of testing!")
            print("🔧 This confirms there's a data flow issue preventing storage.")
        else:
            print("✅ Found recent data! The issue might be elsewhere.")

        return {
            "users": users_count,
            "trips": trips_count,
            "locations": locations_count,
            "recent_trips": recent_trips_count,
            "recent_locations": recent_locations_count,
        }

    except Exception as e:
        print(f"❌ Error checking data: {e}")
        return None


if __name__ == "__main__":
    print("🚀 Checking Existing Database Data\n")

    data = check_data()

    if data:
        print(f"\n📈 SUMMARY:")
        print(f"   Users: {data['users']}")
        print(f"   Total Trips: {data['trips']}")
        print(f"   Total Locations: {data['locations']}")
        print(f"   Recent Trips (2 days): {data['recent_trips']}")
        print(f"   Recent Locations (2 days): {data['recent_locations']}")

        if data["recent_trips"] == 0 and data["recent_locations"] == 0:
            print("\n🎯 DIAGNOSIS: Data is NOT reaching the database")
            print("📝 Possible causes:")
            print("   1. Flutter app not sending data to backend")
            print("   2. Backend authentication failing")
            print("   3. Backend not saving to database")
            print("   4. RLS policies blocking inserts")
            print("\n📖 Next steps:")
            print("   1. Check Flutter app logs for backend communication errors")
            print("   2. Check backend logs for database save attempts")
            print("   3. Test manual trip creation in Flutter app")
        else:
            print("\n✅ Data is reaching the database!")
            print("📝 Check your Flutter app's history tab - data should be visible")
    else:
        print("\n❌ Could not check database data")
        print("📖 Make sure your Supabase project is accessible")

