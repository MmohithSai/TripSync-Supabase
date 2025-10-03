#!/usr/bin/env python3
"""
Simple Backend Test - Tests basic FastAPI + Supabase connectivity
"""

import asyncio
import sys
import os
from datetime import datetime

# Add the backend directory to Python path
sys.path.append("backend")

from backend.app.database import initialize_supabase
from backend.app.config import settings


async def test_backend_connection():
    """Test basic backend connectivity"""
    print("🚀 Testing FastAPI + Supabase Backend Connection")
    print("=" * 50)

    # Test 1: Check configuration
    print(f"📍 Supabase URL: {settings.SUPABASE_URL}")
    print(
        f"🔑 Service Role Key: {'✅ Set' if settings.SUPABASE_SERVICE_ROLE_KEY and settings.SUPABASE_SERVICE_ROLE_KEY != 'YOUR_ACTUAL_SERVICE_ROLE_KEY_HERE' else '❌ Missing/Placeholder'}"
    )

    # Test 2: Initialize Supabase client
    print("\n🔧 Initializing Supabase client...")
    client = initialize_supabase()
    if not client:
        print("❌ Failed to initialize Supabase client")
        print(
            "💡 Make sure you've set the correct SUPABASE_SERVICE_ROLE_KEY in backend/.env"
        )
        return False

    print("✅ Supabase client initialized successfully")

    # Test 3: Test database connection
    print("\n🔍 Testing database connection...")
    try:
        # Try to get users count
        response = client.table("users").select("id").limit(1).execute()
        print("✅ Database connection successful")
        print(f"📊 Users table accessible (found {len(response.data)} users)")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

    # Test 4: Test trips table
    print("\n🔍 Testing trips table...")
    try:
        response = client.table("trips").select("id").limit(1).execute()
        print("✅ Trips table accessible")
    except Exception as e:
        print(f"❌ Trips table error: {e}")
        return False

    # Test 5: Test locations table
    print("\n🔍 Testing locations table...")
    try:
        response = client.table("locations").select("id").limit(1).execute()
        print("✅ Locations table accessible")
    except Exception as e:
        print(f"❌ Locations table error: {e}")
        return False

    print("\n🎉 ALL TESTS PASSED!")
    print("✅ Your FastAPI + Supabase backend is working correctly!")
    print("\n📝 Next steps:")
    print("1. Start your FastAPI server: cd backend && python main.py")
    print("2. Test your Flutter app - it should now be able to save data")
    print("3. Check your Supabase dashboard for new data")

    return True


if __name__ == "__main__":
    asyncio.run(test_backend_connection())
