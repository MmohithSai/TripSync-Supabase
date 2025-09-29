# Firebase to Supabase Migration Guide

This guide will help you complete the migration from Firebase to Supabase for your Location Tracker App.

## ✅ Completed Migration Steps

### 1. Dependencies Updated

- ✅ Added `supabase_flutter: ^2.5.6` to `pubspec.yaml`
- ✅ Removed Firebase dependencies (they weren't in pubspec.yaml but were being imported)

### 2. Core Infrastructure Updated

- ✅ Created `lib/common/supabase_config.dart` for Supabase initialization
- ✅ Updated `lib/main.dart` to initialize Supabase
- ✅ Updated `lib/common/providers.dart` to use Supabase providers instead of Firebase

### 3. Authentication Migration

- ✅ Updated `lib/features/auth/presentation/login_screen.dart` to use Supabase Auth
- ✅ Updated `lib/features/auth/presentation/auth_gate.dart` to use Supabase auth state
- ✅ Replaced Firebase Auth methods with Supabase equivalents:
  - `signInWithEmailAndPassword` → `signInWithPassword`
  - `createUserWithEmailAndPassword` → `signUp`
  - `FirebaseAuthException` → `AuthException`

### 4. Database Migration

- ✅ Updated `lib/features/location/service/location_controller.dart` to sync to Supabase
- ✅ Updated `lib/features/history/data/history_repository.dart` to use Supabase
- ✅ Updated `lib/features/itinerary/data/itinerary_repository.dart` to use Supabase
- ✅ Updated `lib/features/trips/domain/trip_models.dart` to support Supabase format
- ✅ Created comprehensive SQL schema in `supabase_schema.sql`

## 🔧 Required Setup Steps

### 1. Supabase Project Configuration

1. **Get your Supabase credentials:**

   - Go to your Supabase project dashboard
   - Navigate to Settings → API
   - Copy your Project URL and anon/public key

2. **Update the configuration:**
   ```dart
   // In lib/common/supabase_config.dart
   static const String supabaseUrl = 'YOUR_ACTUAL_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_ACTUAL_SUPABASE_ANON_KEY';
   ```

### 2. Database Setup

1. **Run the SQL schema:**

   - Go to your Supabase project dashboard
   - Navigate to SQL Editor
   - Copy and paste the contents of `supabase_schema.sql`
   - Execute the SQL to create all tables, indexes, and RLS policies

2. **Verify tables were created:**
   - Go to Table Editor in Supabase dashboard
   - You should see these tables:
     - `users`
     - `locations`
     - `trips`
     - `trip_points`
     - `itineraries`
     - `saved_places`

### 3. Authentication Setup

1. **Enable Email Authentication:**

   - Go to Authentication → Settings in Supabase dashboard
   - Enable "Enable email confirmations" if desired
   - Configure email templates if needed

2. **Disable 2FA/MFA (Recommended for Development):**

   - Go to Authentication → Settings in Supabase dashboard
   - Disable Multi-Factor Authentication (MFA)
   - Turn off any TOTP, SMS, or other 2FA factors
   - See `DISABLE_2FA_GUIDE.md` for detailed instructions

3. **Test authentication:**
   - Run the app
   - Try creating a new account
   - Try logging in with existing credentials

## 📊 Database Schema Overview

### Tables Created:

1. **`users`** - Extends Supabase auth.users
2. **`locations`** - Background location tracking data
3. **`trips`** - Trip summaries with all metadata
4. **`trip_points`** - Individual GPS points for trips
5. **`itineraries`** - Trip itineraries and plans
6. **`saved_places`** - User's saved locations

### Key Features:

- ✅ Row Level Security (RLS) enabled on all tables
- ✅ Automatic timestamp updates with triggers
- ✅ Proper foreign key relationships
- ✅ Optimized indexes for performance
- ✅ JSONB support for complex data structures

## 🔄 Data Migration (If Needed)

If you have existing Firebase data to migrate:

1. **Export Firebase data:**

   ```bash
   # Use Firebase Admin SDK or export tools
   firebase firestore:export gs://your-bucket/backup
   ```

2. **Transform and import to Supabase:**
   - Convert Firestore documents to PostgreSQL format
   - Update field names (camelCase → snake_case)
   - Handle timestamp conversions
   - Import using Supabase dashboard or API

## 🧪 Testing the Migration

### 1. Run the App

```bash
flutter pub get
flutter run
```

### 2. Test Key Features

- [ ] User registration/login
- [ ] Location tracking and sync
- [ ] Trip creation and management
- [ ] History viewing
- [ ] Offline functionality

### 3. Check Database

- Verify data is being written to Supabase tables
- Check RLS policies are working correctly
- Monitor performance and query execution

## 🚨 Important Notes

### Breaking Changes:

1. **Field Names:** All database fields now use snake_case instead of camelCase
2. **Timestamps:** Using ISO8601 strings instead of Firestore Timestamps
3. **Auth State:** Different auth state structure in Supabase
4. **Error Handling:** Different exception types (AuthException vs FirebaseAuthException)

### Performance Considerations:

1. **Batch Operations:** Supabase supports batch inserts for better performance
2. **Real-time:** Supabase real-time subscriptions work differently than Firestore
3. **Indexing:** All tables have proper indexes for common query patterns

## 🔧 Troubleshooting

### Common Issues:

1. **Authentication not working:**

   - Check Supabase URL and anon key
   - Verify email authentication is enabled
   - Check RLS policies

2. **Database connection errors:**

   - Verify tables were created correctly
   - Check RLS policies allow your operations
   - Ensure proper foreign key relationships

3. **Data not syncing:**
   - Check network connectivity
   - Verify user is authenticated
   - Check error logs in Supabase dashboard

### Debug Steps:

1. Check Supabase dashboard logs
2. Use Flutter debug console
3. Verify RLS policies in Supabase
4. Test queries directly in Supabase SQL editor

## 📝 Next Steps

1. **Update remaining repositories** (if any were missed)
2. **Add error handling** for network issues
3. **Implement offline sync** improvements
4. **Add data validation** on the database level
5. **Set up monitoring** and alerts in Supabase
6. **Consider adding** Supabase Edge Functions for complex operations

## 🎉 Migration Complete!

Your Location Tracker App has been successfully migrated from Firebase to Supabase! The app now uses:

- ✅ Supabase Auth for authentication
- ✅ PostgreSQL for data storage
- ✅ Row Level Security for data protection
- ✅ Real-time subscriptions (when needed)
- ✅ Proper indexing and performance optimization

Remember to update your Supabase configuration with your actual project credentials before running the app.


