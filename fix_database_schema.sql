-- Fix database schema to match backend expectations
-- Run this in your Supabase SQL Editor

-- Add missing columns to trips table
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS end_time TIMESTAMP WITH TIME ZONE;

-- Add missing columns to locations table
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS trip_id UUID;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS altitude DOUBLE PRECISION;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS speed DOUBLE PRECISION;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS timestamp TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS timezone_offset_minutes INTEGER DEFAULT 0;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS timestamp_ms BIGINT;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_timestamp ON public.trips(timestamp);
CREATE INDEX IF NOT EXISTS idx_trips_end_time ON public.trips(end_time);
CREATE INDEX IF NOT EXISTS idx_locations_user_id ON public.locations(user_id);
CREATE INDEX IF NOT EXISTS idx_locations_trip_id ON public.locations(trip_id);
CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON public.locations(timestamp);

-- Fix user creation trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO UPDATE SET
    email = NEW.email,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Test the trigger by checking if users exist
SELECT 'Users in auth.users:' as info, count(*) as count FROM auth.users;
SELECT 'Users in public.users:' as info, count(*) as count FROM public.users;

-- If you see users in auth.users but not in public.users, run:
INSERT INTO public.users (id, email)
SELECT id, email FROM auth.users
ON CONFLICT (id) DO NOTHING;
