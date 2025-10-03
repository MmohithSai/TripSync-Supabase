#!/usr/bin/env python3
"""
Database Operations Test Script
Tests if the backend can properly save data to Supabase
"""

import asyncio
import os
from datetime import datetime
import sys
import json

# Add the backend directory to Python path
sys.path.append("backend")

from backend.app.database import db_service, initialize_supabase
from backend.app.config import settings


async def test_database_operations():
    """Test all database operations"""
    print("🔍 Testing Database Operations...")
    print(f"📍 Supabase URL: {settings.SUPABASE_URL}")
    print(
        f"🔑 Service Role Key: {'✅ Set' if settings.SUPABASE_SERVICE_ROLE_KEY else '❌ Missing'}"
    )

    # Initialize Supabase
    client = initialize_supabase()
    if not client:
        print("❌ Failed to initialize Supabase client")
        return False

    print("✅ Supabase client initialized")

    # Test 1: Check if we can connect to database
    try:
        # Try to get users count
        response = client.table("users").select("id").limit(1).execute()
        print(f"✅ Database connection successful. Users table accessible.")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

    # Test 2: Create a test user first
    test_user_id = "550e8400-e29b-41d4-a716-446655440000"
    print("\n🧪 Creating test user...")
    user_created = await db_service.create_user_profile(
        test_user_id, "test@example.com"
    )
    if user_created:
        print("✅ Test user created successfully")
    else:
        print("❌ Failed to create test user")
        return False

    # Test 3: Test trip record saving
    test_trip_data = {
        "user_id": test_user_id,
        "start_time": datetime.now().isoformat(),
        "end_time": datetime.now().isoformat(),
        "duration_minutes": 15,
        "total_distance_km": 5.2,
        "start_latitude": 17.3850,
        "start_longitude": 78.4867,
        "end_latitude": 17.4474,
        "end_longitude": 78.3569,
        "mode": "car",
        "purpose": "work",
        "trip_number": f"TRIP-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
        "chain_id": f"CHAIN-{datetime.now().strftime('%Y%m%d-%H')}",
    }

    print("\n🧪 Testing trip record saving...")
    success = await db_service.save_trip_record(test_trip_data)

    if success:
        print("✅ Trip record saved successfully!")
    else:
        print("❌ Failed to save trip record")
        return False

    # Test 3: Test GPS points saving
    test_gps_points = [
        {
            "user_id": "test-user-123",
            "latitude": 17.3850,
            "longitude": 78.4867,
            "accuracy": 10.0,
            "altitude": 500.0,
            "speed_kmh": 25.0,
            "bearing": 45.0,
            "timestamp": datetime.now().isoformat(),
        },
        {
            "user_id": "test-user-123",
            "latitude": 17.3860,
            "longitude": 78.4877,
            "accuracy": 8.0,
            "altitude": 502.0,
            "speed_kmh": 30.0,
            "bearing": 50.0,
            "timestamp": datetime.now().isoformat(),
        },
    ]

    print("\n🧪 Testing GPS points saving...")
    success = await db_service.save_trip_points("test-trip-123", test_gps_points)

    if success:
        print("✅ GPS points saved successfully!")
    else:
        print("❌ Failed to save GPS points")
        return False

    print("\n🎉 All database operations successful!")
    return True


async def check_schema():
    """Check if the database schema has all required fields"""
    print("\n🔍 Checking Database Schema...")

    client = initialize_supabase()
    if not client:
        print("❌ Cannot check schema - Supabase client not initialized")
        return False

    # Check trips table structure
    try:
        # Try to select with all expected fields
        response = (
            client.table("trips")
            .select(
                "id, user_id, start_location, end_location, distance_km, duration_min, "
                "timestamp, end_time, mode, purpose, companions, trip_number, chain_id"
            )
            .limit(1)
            .execute()
        )
        print("✅ Trips table has all required fields")
    except Exception as e:
        print(f"❌ Trips table schema issue: {e}")
        return False

    # Check locations table structure
    try:
        response = (
            client.table("locations")
            .select(
                "id, user_id, trip_id, latitude, longitude, accuracy, altitude, "
                "speed, heading, timestamp, timezone_offset_minutes"
            )
            .limit(1)
            .execute()
        )
        print("✅ Locations table has all required fields")
    except Exception as e:
        print(f"❌ Locations table schema issue: {e}")
        return False

    return True


if __name__ == "__main__":
    print("🚀 Starting Database Operations Test\n")

    # Load environment variables
    from dotenv import load_dotenv
    import os

    # Try to load from .env file, but also set defaults for testing
    load_dotenv("backend/.env")

    # Set environment variables for testing if not already set
    if not os.getenv("SUPABASE_URL"):
        os.environ["SUPABASE_URL"] = "https://ixlgntiqgfmsvuqahbnd.supabase.co"
    if not os.getenv("SUPABASE_ANON_KEY"):
        os.environ["SUPABASE_ANON_KEY"] = (
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGdudGlxZ2Ztc3Z1cWFoYm5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5ODczNDAsImV4cCI6MjA3NDU2MzM0MH0.XXdvZaGmSNQkoy8qrEpluVv8FwDpStkGktPvdnFR6MA"
        )

    # Check if service role key is set
    if (
        not os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        == "PLACEHOLDER_REPLACE_WITH_ACTUAL_SERVICE_ROLE_KEY"
    ):
        print("⚠️  SUPABASE_SERVICE_ROLE_KEY not configured!")
        print("📖 To get your service role key:")
        print(
            "   1. Go to https://supabase.com/dashboard/project/ixlgntiqgfmsvuqahbnd/settings/api"
        )
        print("   2. Copy the 'service_role' key (NOT the anon key)")
        print("   3. Create backend/.env file with:")
        print("      SUPABASE_SERVICE_ROLE_KEY=your_actual_service_role_key_here")
        print("\n🔄 Continuing with limited testing using anon key...")
        # Use anon key as fallback for basic testing
        os.environ["SUPABASE_SERVICE_ROLE_KEY"] = os.getenv("SUPABASE_ANON_KEY")

    # Run schema check first
    schema_ok = asyncio.run(check_schema())

    if not schema_ok:
        print("\n❌ Schema check failed. Please run the schema fix SQL first.")
        print("📖 See DATABASE_STORAGE_FIX.md for instructions.")
        exit(1)

    # Run database operations test
    success = asyncio.run(test_database_operations())

    if success:
        print("\n🎉 All tests passed! Database operations are working correctly.")
        print("📝 If your app still doesn't show data, the issue is likely in:")
        print("   1. Flutter authentication flow")
        print("   2. Backend authentication middleware")
        print("   3. Data flow from Flutter to backend")
    else:
        print("\n❌ Database operations failed. Check the errors above.")
        print("📖 See DATABASE_STORAGE_FIX.md for troubleshooting steps.")
        exit(1)
