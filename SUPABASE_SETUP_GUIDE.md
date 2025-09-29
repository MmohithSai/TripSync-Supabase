# Supabase Setup Guide

Your Supabase project is now configured! Here's how to complete the setup:

## ✅ Configuration Complete

Your app is now configured with:

- **Project URL**: `https://ixlgntiqgfmsvuqahbnd.supabase.co`
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGdudGlxZ2Ztc3Z1cWFoYm5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5ODczNDAsImV4cCI6MjA3NDU2MzM0MH0.XXdvZaGmSNQkoy8qrEpluVv8FwDpStkGktPvdnFR6MA`

## 🗄️ Database Setup

### 1. Create Tables

Go to your Supabase project dashboard → SQL Editor and run this SQL:

```sql
-- Create users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create locations table for background location tracking
CREATE TABLE IF NOT EXISTS public.locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  client_timestamp_ms BIGINT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create trips table with your data format
CREATE TABLE IF NOT EXISTS public.trips (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  start_location JSONB NOT NULL, -- {"lat": 17.3850, "lng": 78.4867}
  end_location JSONB NOT NULL,   -- {"lat": 17.4474, "lng": 78.3569}
  distance_km DOUBLE PRECISION NOT NULL,
  duration_min INTEGER NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Additional optional fields
  mode TEXT DEFAULT 'unknown',
  purpose TEXT DEFAULT 'unknown',
  companions JSONB DEFAULT '{"adults": 0, "children": 0, "seniors": 0}',
  is_recurring BOOLEAN DEFAULT FALSE,
  destination_region TEXT,
  origin_region TEXT,
  trip_number TEXT,
  chain_id TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_locations_user_id ON public.locations(user_id);
CREATE INDEX IF NOT EXISTS idx_locations_created_at ON public.locations(created_at);
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_timestamp ON public.trips(timestamp);

-- Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can only access their own data
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Locations policies
CREATE POLICY "Users can view own locations" ON public.locations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own locations" ON public.locations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own locations" ON public.locations
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own locations" ON public.locations
  FOR DELETE USING (auth.uid() = user_id);

-- Trips policies
CREATE POLICY "Users can view own trips" ON public.trips
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own trips" ON public.trips
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own trips" ON public.trips
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own trips" ON public.trips
  FOR DELETE USING (auth.uid() = user_id);
```

### 2. Enable Authentication

1. Go to Authentication → Settings in your Supabase dashboard
2. Enable "Enable email confirmations" if desired
3. Configure email templates if needed

## 🚀 Running the App

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run the App

```bash
flutter run
```

### 3. Test the Integration

1. Create a new account or login
2. Navigate to the Trip Example screen
3. Tap "Save Example Trip" to test data storage
4. Check your Supabase dashboard → Table Editor → trips table to see the data

## 📊 Data Format

Your trip data will be stored in this format:

```json
{
  "id": "uuid",
  "user_id": "user-uuid",
  "start_location": { "lat": 17.385, "lng": 78.4867 },
  "end_location": { "lat": 17.4474, "lng": 78.3569 },
  "distance_km": 12.4,
  "duration_min": 25,
  "timestamp": "2024-01-27T10:30:00Z",
  "mode": "car",
  "purpose": "work",
  "companions": { "adults": 1, "children": 0, "seniors": 0 },
  "notes": "Daily commute to office"
}
```

## 🔧 Usage Examples

### Save a Trip

```dart
final tripService = ref.read(tripServiceProvider);
await tripService.saveTrip(
  startLocation: {"lat": 17.3850, "lng": 78.4867},
  endLocation: {"lat": 17.4474, "lng": 78.3569},
  distanceKm: 12.4,
  durationMin: 25,
  mode: 'car',
  purpose: 'work',
);
```

### Get User Trips

```dart
final trips = await tripService.getUserTrips();
```

### Get Trip Statistics

```dart
final stats = await tripService.getTripStats();
print('Total trips: ${stats['total_trips']}');
print('Total distance: ${stats['total_distance_km']} km');
```

## 🎉 You're All Set!

Your Location Tracker App is now connected to Supabase and ready to store trip data in your specified format. The app includes:

- ✅ Supabase authentication
- ✅ Trip data storage in your format
- ✅ Real-time data synchronization
- ✅ Row-level security
- ✅ Example screens for testing

Check the `TripExampleScreen` to see how to use the trip service, and modify it according to your needs!



