# Database Synchronization Fix Guide

## Issues Identified

1. **Users table is empty** - No automatic user profile creation when auth users sign up
2. **Trip_points table is empty** - Either no meaningful trips have been saved, or trips are queued locally

## ✅ Changes Made

### 1. Trip Saving Flow Fixed

**Updated Files:**

- `lib/features/trips/service/trip_controller.dart`

  - Added `TripData` class to temporarily hold trip information
  - Modified `stopManual()` to return `TripData` instead of saving immediately
  - Added `saveTripWithDetails()` method to save trip with user-provided details
  - Added `_isMeaningfulTrip()` validation to filter out noise and short trips
  - Added `_isValidPosition()` to filter out inaccurate GPS readings

- `lib/features/map/presentation/map_screen.dart`
  - Updated trip stop logic to collect details from user via modal
  - Integrated `saveTripWithDetails()` call after collecting trip information
  - Added blue polyline and markers to visualize the tracked route on the map

### 2. Trip Validation Criteria

**A trip must meet ALL these criteria to be saved:**

- **Minimum Distance:** 50 meters (filters out GPS drift/noise)
- **Minimum Duration:** 60 seconds (filters out very short movements)
- **Speed Range:** 0.5 - 200 km/h (filters out unrealistic speeds)
- **GPS Accuracy:** Position accuracy must be < 100 meters
- **Segment Filtering:** Ignores movements < 2 meters (GPS noise)

### 3. Route Visualization Added

- **Blue Polyline:** Shows the complete path taken during the trip
- **Blue Markers:** Mark individual GPS points along the route
- **Real-time Updates:** Route updates as you move during an active trip

## 🔧 Required Setup Steps

### Step 1: Fix Users Table Sync

The `users` table is empty because Supabase doesn't automatically create user profiles when someone signs up. You need to set up a database trigger.

**Action Required:**

1. Open your Supabase project dashboard
2. Go to **SQL Editor**
3. Copy and paste the contents of `supabase_user_trigger.sql`
4. Click **Run** to execute the SQL
5. This will:
   - Create a trigger that automatically adds users to the `users` table when they sign up
   - Backfill any existing auth users who don't have profiles yet

### Step 2: Test Trip Saving

**To verify trip_points are being saved:**

1. **Start a new trip:**

   - Open the app
   - Tap the "Start" button
   - Move at least 50 meters
   - Wait at least 60 seconds
   - Tap "Stop"

2. **Fill in trip details:**

   - Select mode of transport
   - Select purpose
   - (Optional) Add companions, frequency, cost
   - Tap "Save" or "Skip"

3. **Check the database:**
   - Go to Supabase dashboard → Table Editor
   - Check the `trips` table - you should see your trip
   - Check the `trip_points` table - you should see the GPS points for your trip

### Step 3: Verify Local Queue Sync

If trips are being saved locally but not syncing to Supabase:

1. **Check internet connection** - Trips are queued locally when offline
2. **Check authentication** - Make sure you're logged in
3. **Check Supabase RLS policies** - Ensure your user has permission to insert trips

**Manual Sync:**

- The app should automatically sync queued trips when you regain internet connection
- You can also restart the app to trigger a sync

## 📊 How the System Works Now

### Trip Recording Flow:

1. **User starts trip** → Trip controller begins buffering GPS points
2. **Location updates** → GPS points are validated and filtered:
   - Invalid positions (accuracy > 100m) are rejected
   - Very small movements (< 2m) are ignored as GPS noise
   - Points are buffered and distance is calculated cumulatively
3. **User stops trip** → Trip controller returns trip data without saving
4. **User enters details** → Modal collects mode, purpose, companions, etc.
5. **Trip validation** → System checks if trip meets minimum criteria:
   - Distance >= 50m
   - Duration >= 60s
   - Speed within realistic range (0.5 - 200 km/h)
6. **Save to database** → If validation passes:
   - Trip summary is saved to `trips` table
   - All GPS points are saved to `trip_points` table
   - If Supabase fails, trip is queued locally for later sync

### Route Visualization:

- **During trip:** Blue markers and polyline show your current route in real-time
- **Route calculation:** Distance is calculated as the sum of distances between consecutive GPS points (actual route length, not straight-line displacement)
- **Point density:** GPS points are collected every 5 seconds (adjustable)

## 🧪 Testing Checklist

- [ ] Run `supabase_user_trigger.sql` in Supabase SQL Editor
- [ ] Verify existing auth users now appear in `users` table
- [ ] Create a new account and verify user is added to `users` table automatically
- [ ] Start a trip and move at least 50 meters for 60+ seconds
- [ ] Stop the trip and enter details (or skip)
- [ ] Verify trip appears in `trips` table
- [ ] Verify GPS points appear in `trip_points` table
- [ ] Check that very short trips (< 50m or < 60s) are NOT saved
- [ ] Verify blue route line appears on map during active trip

## 🔍 Troubleshooting

### Users table still empty after signing up

**Check:**

1. Did you run `supabase_user_trigger.sql`?
2. Go to Supabase → Authentication → Users - do users appear there?
3. If yes, run the backfill query manually:
   ```sql
   INSERT INTO public.users (id, email, created_at, updated_at)
   SELECT id, email, created_at, updated_at
   FROM auth.users
   WHERE id NOT IN (SELECT id FROM public.users)
   ON CONFLICT (id) DO NOTHING;
   ```

### Trip_points table is empty

**Possible reasons:**

1. **No trips meet the validation criteria**
   - Trips must be at least 50 meters and 60 seconds
   - Try taking a longer trip
2. **Trips are queued locally but not synced**
   - Check your internet connection
   - Check Supabase dashboard → Logs for any errors
3. **Authentication issues**
   - Make sure you're logged in
   - Check that `auth.uid()` matches a user in the `users` table

### Route not showing on map

**Check:**

1. Is a trip currently active? (Button should say "Stop")
2. Have you moved enough for GPS points to be recorded?
3. Check that `tripState.bufferedPoints` has data (should update every 5 seconds)

## 📝 Summary of All Modified Files

1. **`lib/features/trips/service/trip_controller.dart`**

   - New: `TripData` class
   - Modified: `stopManual()` returns trip data
   - New: `saveTripWithDetails()` method
   - New: `_isMeaningfulTrip()` validation
   - New: `_isValidPosition()` filtering
   - Modified: Distance calculation (cumulative, not displacement)

2. **`lib/features/map/presentation/map_screen.dart`**

   - Modified: Trip stop button logic
   - New: Trip details modal after stopping
   - New: Route visualization (polylines + markers)
   - Modified: Integration with new `saveTripWithDetails()` API

3. **`lib/features/location/service/location_controller.dart`**

   - Modified: GPS settings for better accuracy
   - Modified: Movement detection thresholds
   - Modified: Noise filtering parameters

4. **`lib/features/location/service/remote_config_service.dart`**

   - Modified: Trip detection configuration defaults
   - Reduced thresholds for more sensitive tracking

5. **`supabase_user_trigger.sql`** (NEW)

   - Database trigger for automatic user profile creation
   - Backfill query for existing users

6. **`DATABASE_SYNC_FIX.md`** (THIS FILE)
   - Complete documentation of changes and fixes

## 🎯 Next Steps

1. **Immediately:** Run `supabase_user_trigger.sql` in your Supabase SQL Editor
2. **Test:** Create a new account or log in with an existing one
3. **Verify:** Check that user appears in both `auth.users` and `public.users`
4. **Test trip:** Take a trip of at least 50 meters for 60+ seconds
5. **Verify data:** Check `trips` and `trip_points` tables have data
6. **Monitor:** Check Supabase logs for any errors during testing

If you continue to have issues, please check the Supabase dashboard logs and share any error messages.

