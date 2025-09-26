# location_tracker_app

A new Flutter project.

## Setup

1) Firebase
- Install FlutterFire CLI and configure: `dart pub global activate flutterfire_cli`
- Run: `flutterfire configure --platforms=android,ios`
- This generates `lib/firebase_options.dart` and updates app IDs. If you cannot run it, provide `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.

2) Google Maps API Keys
- Android: replace `YOUR_ANDROID_MAPS_API_KEY` in `android/app/src/main/AndroidManifest.xml`.
- iOS: replace `YOUR_IOS_MAPS_API_KEY` in `ios/Runner/Info.plist` under `GMSApiKey`.

3) Permissions
- Android: FINE/COARSE/BACKGROUND location enabled in manifest.
- iOS: `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` added. Background mode `location` enabled in `Runner.entitlements`.

4) Run
```
flutter pub get
flutter run
```


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
