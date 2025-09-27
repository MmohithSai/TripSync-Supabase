# Location Tracker App

A privacy-aware mobility tracking and trip journaling app built with Flutter. It captures adaptive location data, detects meaningful trips automatically, supports manual trip details (regions, mode, purpose, passengers), and provides environmental (CO₂) and cost insights. Data is synced to Firebase Firestore with local encrypted buffering for offline resilience.

## Features
- Live Google Map with locate-and-follow
- Manual Start/Stop with optional trip details
  - Origin/Destination regions (not exact coordinates)
  - Mode, Purpose (optional)
  - Trip number, Chain ID
  - Passenger counts (adults, children, seniors) and relationship
- Auto trip detection
  - Start when moving ≥ 90s at ≥ 1.2 m/s
  - Stop when within ~100 m radius for ≥ 5 minutes
  - Discard trips < 500 m or < 5 minutes
- Adaptive background location tracking
  - Slower cadence when still, ~5s/25m when moving
  - Meaningful movement filtering to reduce noise
- History and insights
  - Recent trip list with CO₂ saved and cost preview
  - Trip edit dialog with environmental impact card
- Saved places via long-press on map
- Privacy by design: regions instead of exact endpoints; encrypted local queue

## Architecture
- Flutter + Riverpod state management
- Firebase Firestore for cloud persistence
- Encrypted SQLite queue (`sqflite_sqlcipher`) for offline buffering
- Geolocator for cross-platform location
- Google Maps SDK for map rendering

### Key Directories
- `lib/features/map/` — Map screen and saved places
- `lib/features/location/` — Location controller and local queue
- `lib/features/trips/` — Trip models, repository, controller, calculator
- `lib/features/history/` — History list and edit dialog
- `lib/features/settings/` — Settings (placeholder)

### Important Files
- `lib/features/map/presentation/map_screen.dart` — Live map, Start/Stop, manual form
- `lib/features/location/service/location_controller.dart` — Permissions, adaptive location stream, local sync
- `lib/features/location/data/local_location_queue.dart` — Encrypted queue with trimming
- `lib/features/trips/service/trip_controller.dart` — Auto-detection, buffering, short-trip discard
- `lib/features/trips/data/trip_repository.dart` — Firestore access for trips/points
- `lib/features/trips/domain/trip_models.dart` — TripSummary, TripPoint, enums
- `lib/features/trips/service/trip_calculator.dart` — CO₂ savings and cost estimation
- `lib/features/history/presentation/history_screen.dart` — Trip list and edit UI

## Data Model (Firestore)
- `users/{uid}/trips/{tripId}`: TripSummary
  - `startedAt`, `endedAt`, `distanceMeters`
  - `mode`, `purpose`
  - `companions` (adults, children, seniors, relationship)
  - `originRegion`, `destinationRegion`
  - `tripNumber`, `chainId`, `isRecurring`
  - Subcollection `points`: `latitude`, `longitude`, `timestamp` (optional for active trips)
- `users/{uid}/locations`: background location samples (throttled/filtered)

## Trip Detection & Filtering
- Start: moving ≥ 90s at ≥ 1.2 m/s
- Stop: within ~100 m for ≥ 5 minutes
- Keep only trips ≥ 500 m AND ≥ 5 minutes
- Manual Start/Stop overrides are supported; short trips are deleted on stop

## Adaptive Location Strategy
- Android: `AndroidSettings` high accuracy, `distanceFilter: ~25m`, `interval: ~5s`, foreground notification where applicable
- iOS: `AppleSettings` similar tuning with background indicators
- Meaningful movement check prevents storing trivial movements or poor accuracy fixes

## Privacy
- Regions over exact coordinates for endpoints
- Encrypted local queue (`sqflite_sqlcipher`) with cap (~2000 rows)
- Batched sync to reduce volume and cost

## Environmental & Cost Calculations
- CO₂ factors per mode (kg CO₂/km/person), savings computed against car baseline
- Cost model:
  - Car: distance × (L/100km) × current fuel price (API with fallback)
  - Bus/train/metro: per-km fare (API/fallback)
  - Walk/bicycle/scooter: zero
- Replace placeholder API endpoints/keys in `trip_calculator.dart` for production

## Setup
1. Prerequisites
   - Flutter SDK, Android Studio/Xcode, Firebase project
2. Firebase
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Enable Firestore and Auth (email/password or your chosen provider)
3. Android
   - Verify permissions in `android/app/src/main/AndroidManifest.xml` (location, foreground service)
4. iOS
   - Configure background modes and location permissions in `Info.plist` and entitlements
5. Dependencies
   - `flutter pub get`

## Run
- `flutter run`
- For Android background tracking, ensure foreground service notification is permitted

## Configuration
- Thresholds (tuning): `TripController` and `LocationController`
  - Movement duration/speed, stop radius/duration, min distance/duration
  - Sampling intervals and distance filters
- API keys
  - Fuel price and fares in `trip_calculator.dart`

## Roadmap / Future Work
- Integrate Activity Recognition (Android) & Core Motion (iOS)
- Add Wi‑Fi/cell location fusion for indoor/low‑GPS contexts
- Optional clustering (DBSCAN-like) for stop detection & OD derivation from raw points
- Export and analytics dashboards for planners

## Troubleshooting
- Start/Stop not responding: check location permissions & background service status
- High battery usage: increase `distanceFilter` or interval in `LocationController`
- Firestore costs: increase batching thresholds; ensure short trips are filtered

## License
Internal project — update with your license or usage policy.
