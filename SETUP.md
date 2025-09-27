# Location Tracker App - Setup Guide

## Overview

This Flutter app provides privacy-aware mobility tracking and trip journaling with enhanced features for data quality, planner usability, privacy, and user experience.

## Features Implemented

### 1. Multilingual & Privacy
- ✅ English, Malayalam, and Hindi support
- ✅ Language picker in Settings with system locale default
- ✅ In-app Privacy Policy & Data Retention page
- ✅ Encryption and data retention explanations

### 2. Planner-Facing Outputs
- ✅ Firebase Cloud Function for nightly anonymized trip exports
- ✅ CSV and GeoJSON export formats
- ✅ Web dashboard for trip analytics
- ✅ Trip counts, mode share, and origin-destination heatmap

### 3. Trip Detection & Remote Config
- ✅ Remote-configurable thresholds
- ✅ Auto-start speed/time, stop radius/time, min distance/duration
- ✅ Firebase Remote Config integration

### 4. User Experience
- ✅ Batch editing for trips in history screen
- ✅ Weekly summary card with stats
- ✅ Battery optimization warning detection
- ✅ Enhanced trip editing with environmental impact

### 5. Data Reliability
- ✅ Accelerometer fusion for stop/start detection
- ✅ UTC timestamps with local timezone offset
- ✅ Improved trip detection accuracy

### 6. Developer & CI/CD
- ✅ Unit tests for trip detection and export functions
- ✅ GitHub Actions for automated build, test, and deployment
- ✅ Security scanning and code quality checks

## Prerequisites

- Flutter SDK 3.19.0 or later
- Dart SDK 3.9.2 or later
- Node.js 18 or later (for Cloud Functions)
- Firebase CLI
- Android Studio / Xcode (for mobile builds)
- Git

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd location_tracker_app
flutter pub get
```

### 2. Firebase Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Enable the following services:
   - Authentication (Email/Password)
   - Firestore Database
   - Cloud Functions
   - Cloud Storage
   - Remote Config
   - Hosting

3. Download configuration files:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`

4. Initialize Firebase in your project:
```bash
firebase init
```

### 3. Environment Configuration

Create a `.env` file in the root directory:
```env
FIREBASE_PROJECT_ID=your-project-id
GOOGLE_MAPS_API_KEY=your-maps-api-key
STORAGE_BUCKET=your-storage-bucket
```

### 4. Google Cloud Storage Setup

1. Create a Google Cloud Storage bucket for exports
2. Update the bucket name in `functions/index.js`:
```javascript
const BUCKET_NAME = 'your-bucket-name';
```

### 5. Deploy Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 6. Deploy Web Dashboard

```bash
flutter build web
firebase deploy --only hosting
```

### 7. Configure Remote Config

In Firebase Console → Remote Config, add the following parameters:

```json
{
  "tripDetectionConfig": {
    "autoStartSpeedThreshold": 1.2,
    "autoStartTimeThreshold": 120,
    "stopRadiusThreshold": 50.0,
    "stopTimeThreshold": 180,
    "minDistanceThreshold": 150.0,
    "minDurationThreshold": 300,
    "distanceFilter": 25.0,
    "intervalDuration": 5
  }
}
```

### 8. Firestore Security Rules

Update your Firestore rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /trips/{tripId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        
        match /points/{pointId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
      
      match /locations/{locationId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Public read access for export metadata
    match /trip_exports/{exportId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## Running the App

### Development
```bash
flutter run
```

### Build for Production

#### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### Web
```bash
flutter build web --release
```

## Testing

Run unit tests:
```bash
flutter test
```

Run integration tests:
```bash
flutter test integration_test/
```

## CI/CD Setup

1. Fork the repository
2. Set up GitHub Actions secrets:
   - `FIREBASE_TOKEN`: Firebase CLI token
   - `GOOGLE_MAPS_API_KEY`: Google Maps API key
   - `STORAGE_BUCKET`: Google Cloud Storage bucket name

3. Push to `main` branch to trigger deployment

## API Keys Required

### Google Maps API Key
1. Go to Google Cloud Console
2. Enable Maps SDK for Android/iOS
3. Create API key with restrictions
4. Add to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`

### Firebase Service Account
1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate new private key
3. Add to CI/CD secrets as `FIREBASE_SERVICE_ACCOUNT_KEY`

## Troubleshooting

### Common Issues

1. **Build fails with "Google Services not found"**
   - Ensure `google-services.json` and `GoogleService-Info.plist` are in correct locations
   - Check Firebase project configuration

2. **Location permissions not working**
   - Add location permissions to `android/app/src/main/AndroidManifest.xml`
   - Configure location usage descriptions in `ios/Runner/Info.plist`

3. **Cloud Functions deployment fails**
   - Check Firebase CLI is logged in: `firebase login`
   - Verify Node.js version: `node --version`
   - Check function dependencies: `cd functions && npm install`

4. **Web dashboard not loading data**
   - Verify CORS settings in Cloud Functions
   - Check Firebase project ID in web configuration
   - Ensure Firestore security rules allow public read access

### Debug Mode

Enable debug logging:
```dart
// In main.dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    // Enable debug logging
  }
  runApp(MyApp());
}
```

## Security Considerations

1. **API Keys**: Never commit API keys to version control
2. **Firestore Rules**: Implement proper security rules
3. **Data Encryption**: All local data is encrypted using SQLCipher
4. **Privacy**: User data is anonymized before export
5. **Access Control**: Implement proper authentication and authorization

## Performance Optimization

1. **Location Updates**: Adaptive location tracking based on movement
2. **Data Sync**: Batch operations for better performance
3. **Caching**: Local caching with secure storage
4. **Background Processing**: Efficient background location tracking

## Monitoring and Analytics

1. **Firebase Analytics**: Track app usage and performance
2. **Crashlytics**: Monitor crashes and errors
3. **Performance Monitoring**: Track app performance metrics
4. **Custom Events**: Track trip detection accuracy and user behavior

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Firebase documentation
3. Check Flutter documentation
4. Create an issue in the repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.








