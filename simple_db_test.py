#!/usr/bin/env python3
"""
Simple Database Test - Tests schema without service role key
"""

import os
import sys
from supabase import create_client, Client

# Set environment variables directly for testing
os.environ["SUPABASE_URL"] = "https://ixlgntiqgfmsvuqahbnd.supabase.co"
os.environ["SUPABASE_ANON_KEY"] = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGdudGlxZ2Ztc3Z1cWFoYm5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5ODczNDAsImV4cCI6MjA3NDU2MzM0MH0.XXdvZaGmSNQkoy8qrEpluVv8FwDpStkGktPvdnFR6MA"
)


def test_schema():
    """Test if the schema has all required fields"""
    print("🔍 Testing Database Schema...")

    try:
        # Create Supabase client with anon key (read-only)
        supabase: Client = create_client(
            os.environ["SUPABASE_URL"], os.environ["SUPABASE_ANON_KEY"]
        )
        print("✅ Supabase client created successfully")

        # Test trips table schema
        print("\n📊 Testing trips table schema...")
        try:
            response = (
                supabase.table("trips")
                .select(
                    "id, user_id, start_location, end_location, distance_km, duration_min, "
                    "timestamp, end_time, mode, purpose, companions, trip_number, chain_id"
                )
                .limit(1)
                .execute()
            )
            print("✅ Trips table has all required fields!")
        except Exception as e:
            print(f"❌ Trips table schema issue: {e}")
            return False

        # Test locations table schema
        print("\n📍 Testing locations table schema...")
        try:
            response = (
                supabase.table("locations")
                .select(
                    "id, user_id, trip_id, latitude, longitude, accuracy, altitude, "
                    "speed, heading, timestamp, timezone_offset_minutes"
                )
                .limit(1)
                .execute()
            )
            print("✅ Locations table has all required fields!")
        except Exception as e:
            print(f"❌ Locations table schema issue: {e}")
            return False

        # Test users table
        print("\n👤 Testing users table...")
        try:
            response = supabase.table("users").select("id, email").limit(1).execute()
            print("✅ Users table accessible!")
        except Exception as e:
            print(f"❌ Users table issue: {e}")
            return False

        print("\n🎉 All schema tests passed!")
        print("📝 Your database schema is correctly configured!")
        return True

    except Exception as e:
        print(f"❌ Failed to connect to Supabase: {e}")
        return False


if __name__ == "__main__":
    print("🚀 Simple Database Schema Test\n")

    success = test_schema()

    if success:
        print("\n✅ SCHEMA IS WORKING CORRECTLY!")
        print("📖 Next steps:")
        print("   1. Get your service role key from Supabase dashboard")
        print("   2. Create backend/.env file with the service role key")
        print("   3. Test actual data insertion")
        print("\n🔗 Get service role key here:")
        print(
            "   https://supabase.com/dashboard/project/ixlgntiqgfmsvuqahbnd/settings/api"
        )
    else:
        print("\n❌ Schema test failed!")
        print("📖 Make sure you ran the schema fix SQL in Supabase SQL Editor")

