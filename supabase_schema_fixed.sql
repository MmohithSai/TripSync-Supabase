-- FIXED Supabase Database Schema for Location Tracker App
-- This fixes the schema mismatches that prevent data storage
-- Run this SQL in your Supabase SQL editor to update the schema

-- First, add missing columns to existing tables
-- Add end_time to trips table
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS end_time TIMESTAMP WITH TIME ZONE;

-- Add missing fields to locations table for GPS points
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS trip_id UUID;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS altitude DOUBLE PRECISION;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS speed DOUBLE PRECISION;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS timestamp TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS timezone_offset_minutes INTEGER DEFAULT 0;

-- Update locations table to match backend expectations
-- Rename client_timestamp_ms to be more flexible
ALTER TABLE public.locations ADD COLUMN IF NOT EXISTS timestamp_ms BIGINT;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_timestamp ON public.trips(timestamp);
CREATE INDEX IF NOT EXISTS idx_trips_end_time ON public.trips(end_time);
CREATE INDEX IF NOT EXISTS idx_locations_user_id ON public.locations(user_id);
CREATE INDEX IF NOT EXISTS idx_locations_trip_id ON public.locations(trip_id);
CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON public.locations(timestamp);

-- Add RLS policies for new fields (if needed)
-- The existing policies should cover the new columns

-- Create a function to automatically create user records
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

-- Create trigger to automatically create user records
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Verify the schema by showing table structures
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('trips', 'locations', 'users')
ORDER BY table_name, ordinal_position;

