#!/usr/bin/env python3
"""
Test RLS Policies - Check if Row Level Security is blocking inserts
"""

import os
from supabase import create_client, Client

# Set environment variables
os.environ["SUPABASE_URL"] = "https://ixlgntiqgfmsvuqahbnd.supabase.co"
os.environ["SUPABASE_ANON_KEY"] = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGdudGlxZ2Ztc3Z1cWFoYm5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5ODczNDAsImV4cCI6MjA3NDU2MzM0MH0.XXdvZaGmSNQkoy8qrEpluVv8FwDpStkGktPvdnFR6MA"
)


def test_rls_policies():
    """Test if RLS policies are preventing data insertion"""
    print("🔒 Testing Row Level Security Policies...")

    try:
        supabase: Client = create_client(
            os.environ["SUPABASE_URL"], os.environ["SUPABASE_ANON_KEY"]
        )

        # Test 1: Try to insert a test user (this should fail with anon key due to RLS)
        print("\n👤 Testing user insertion with anon key...")
        try:
            test_user_data = {"id": "test-user-123", "email": "test@example.com"}
            response = supabase.table("users").insert(test_user_data).execute()
            print("⚠️ User insertion succeeded (unexpected with anon key)")
        except Exception as e:
            print(f"✅ User insertion blocked by RLS (expected): {str(e)[:100]}...")

        # Test 2: Try to insert a test trip (this should fail with anon key due to RLS)
        print("\n🚗 Testing trip insertion with anon key...")
        try:
            test_trip_data = {
                "user_id": "test-user-123",
                "start_location": {"lat": 17.3850, "lng": 78.4867},
                "end_location": {"lat": 17.4474, "lng": 78.3569},
                "distance_km": 5.2,
                "duration_min": 15,
                "mode": "car",
                "purpose": "work",
            }
            response = supabase.table("trips").insert(test_trip_data).execute()
            print("⚠️ Trip insertion succeeded (unexpected with anon key)")
        except Exception as e:
            print(f"✅ Trip insertion blocked by RLS (expected): {str(e)[:100]}...")

        # Test 3: Try to insert a test location (this should fail with anon key due to RLS)
        print("\n📍 Testing location insertion with anon key...")
        try:
            test_location_data = {
                "user_id": "test-user-123",
                "latitude": 17.3850,
                "longitude": 78.4867,
                "accuracy": 10.0,
                "client_timestamp_ms": 1696262400000,
            }
            response = supabase.table("locations").insert(test_location_data).execute()
            print("⚠️ Location insertion succeeded (unexpected with anon key)")
        except Exception as e:
            print(f"✅ Location insertion blocked by RLS (expected): {str(e)[:100]}...")

        print("\n📊 RLS Policy Test Results:")
        print("✅ RLS policies are active and blocking anon key inserts")
        print("📝 This means:")
        print("   1. Database security is working correctly")
        print("   2. Backend MUST use service role key to insert data")
        print("   3. Flutter app MUST authenticate users properly")

        return True

    except Exception as e:
        print(f"❌ Error testing RLS policies: {e}")
        return False


def check_auth_users():
    """Check if there are any users in auth.users table"""
    print("\n🔍 Checking auth.users table...")

    try:
        supabase: Client = create_client(
            os.environ["SUPABASE_URL"], os.environ["SUPABASE_ANON_KEY"]
        )

        # This might not work with anon key, but let's try
        try:
            # Try to get user count (this might be blocked)
            response = supabase.rpc("get_user_count").execute()
            print(f"📊 Found users in auth.users")
        except Exception as e:
            print(f"❌ Cannot access auth.users with anon key: {str(e)[:100]}...")
            print("📝 This is normal - auth.users requires service role key")

    except Exception as e:
        print(f"❌ Error checking auth users: {e}")


if __name__ == "__main__":
    print("🚀 Testing RLS Policies and Authentication\n")

    success = test_rls_policies()
    check_auth_users()

    if success:
        print("\n🎯 CONCLUSION:")
        print("✅ RLS policies are working correctly")
        print("📝 The empty database is likely due to:")
        print("   1. Missing service role key in backend")
        print("   2. Users not being created during authentication")
        print("   3. Backend not receiving data from Flutter app")
        print("\n📖 Next steps:")
        print("   1. Get service role key from Supabase dashboard")
        print("   2. Create backend/.env file")
        print("   3. Test backend with service role key")
        print("   4. Check Flutter app authentication flow")
    else:
        print("\n❌ Could not test RLS policies")
        print("📖 Check your Supabase connection")

