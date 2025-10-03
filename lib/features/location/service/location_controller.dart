import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
<<<<<<< HEAD
import 'package:permission_handler/permission_handler.dart';
// Removed unused Supabase import
=======
>>>>>>> f9701a696c21c90c70eb11d41fb69ad1780210b8

import '../../../common/providers.dart';
import '../data/local_location_queue.dart';
import '../../../services/backend_service.dart';

class LocationState {
  final Position? currentPosition;
  final bool permissionsGranted;
  final bool serviceEnabled;

  const LocationState({
    required this.currentPosition,
    required this.permissionsGranted,
    required this.serviceEnabled,
  });

  LocationState copyWith({
    Position? currentPosition,
    bool? permissionsGranted,
    bool? serviceEnabled,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
    );
  }
}

class LocationController extends Notifier<LocationState> {
  StreamSubscription<Position>? _subscription;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  Position? _lastPersistedPosition;
  DateTime? _lastPersistedTime;
  final LocalLocationQueue _localQueue = LocalLocationQueue();
  final BackendService _backendService = BackendService();

  @override
  LocationState build() {
    // Initial state
    _init();
    return const LocationState(
      currentPosition: null,
      permissionsGranted: false,
      serviceEnabled: false,
    );
  }

  Stream<Position> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    );
  }

  Future<void> _init() async {
    await _ensurePermissions();
    if (state.permissionsGranted) {
      await _start();
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      result,
    ) async {
      if (result != ConnectivityResult.none) {
        await _syncLocalQueue();
      }
    });
  }

  Future<void> requestPermissions() async {
    await _ensurePermissions(forceRequest: true);
    if (state.permissionsGranted) {
      await _start();
    }
  }

  /// Specifically request "Always" location permission for background tracking
  Future<bool> requestAlwaysPermission() async {
    try {
      if (kDebugMode) {
        print('🎯 Specifically requesting Always location permission...');
      }

      // First ensure we have basic location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // If we have basic permission, aggressively request background access
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _requestBackgroundLocationAccess();

        // Check final result
        final finalPermission = await Geolocator.checkPermission();
        final success = finalPermission == LocationPermission.always;

        if (kDebugMode) {
          print('🎯 Always permission request result: ${finalPermission.name}');
        }

        // Update state
        await _ensurePermissions();
        if (state.permissionsGranted) {
          await _start();
        }

        return success;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error requesting always permission: $e');
      }
      return false;
    }
  }

  /// Check if we have optimal permissions for background trip tracking
  Future<bool> hasBackgroundLocationAccess() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Show a warning if user doesn't have background location access
  Future<void> checkAndWarnAboutBackgroundAccess() async {
    final hasBackground = await hasBackgroundLocationAccess();
    if (!hasBackground && kDebugMode) {
      print('⚠️ WARNING: Background location access not granted.');
      print('   Trip tracking may stop when app is closed or backgrounded.');
      print('   Consider asking user to upgrade to "Always" permission.');
    }
  }

  /// Get a user-friendly description of current permission status
  Future<String> getPermissionStatusDescription() async {
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return 'Location services are disabled';
    }

    switch (permission) {
      case LocationPermission.always:
        return 'Perfect! Background tracking enabled';
      case LocationPermission.whileInUse:
        return 'Good! Tracking works while app is open';
      case LocationPermission.denied:
        return 'Location access denied';
      case LocationPermission.deniedForever:
        return 'Location access permanently denied';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine location access';
    }
  }

  Future<void> _ensurePermissions({bool forceRequest = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    // Only trigger OS dialog when explicitly requested
    if (forceRequest) {
      // Step 1: Request basic location permission first
      permission = await Geolocator.requestPermission();

      // Step 2: If we got basic permission, aggressively request background location
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _requestBackgroundLocationAccess();
        // Re-check permission after background request
        permission = await Geolocator.checkPermission();
      }
    }

    // For trip tracking, we prefer "Always" but accept "whileInUse" as minimum
    final bool hasBasicPermission =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    // Check if we have the ideal permission (Always) for background tracking
    final bool hasBackgroundPermission =
        permission == LocationPermission.always;

    state = state.copyWith(
      permissionsGranted: hasBasicPermission,
      serviceEnabled: serviceEnabled,
    );

    // Log permission status for debugging
    if (kDebugMode) {
      print('📍 Location Permission Status:');
      print('   Service Enabled: $serviceEnabled');
      print('   Permission: ${permission.name}');
      print('   Background Capable: $hasBackgroundPermission');
      print('   Basic Permission: $hasBasicPermission');
    }
  }

  /// Aggressively request background location access using multiple strategies
  Future<void> _requestBackgroundLocationAccess() async {
    try {
      if (kDebugMode) {
        print('🎯 Requesting background location access...');
      }

      // Strategy 1: Use permission_handler for more control
      if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android 10+, we need to request background location separately
        final backgroundStatus = await Permission.locationAlways.status;

        if (backgroundStatus.isDenied || backgroundStatus.isLimited) {
          if (kDebugMode) {
            print('📱 Requesting Android background location permission...');
          }

          // Request background location permission
          final result = await Permission.locationAlways.request();

          if (kDebugMode) {
            print('📱 Background location result: ${result.name}');
          }
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, request always permission directly
        final alwaysStatus = await Permission.locationAlways.status;

        if (alwaysStatus.isDenied || alwaysStatus.isLimited) {
          if (kDebugMode) {
            print('🍎 Requesting iOS always location permission...');
          }

          final result = await Permission.locationAlways.request();

          if (kDebugMode) {
            print('🍎 Always location result: ${result.name}');
          }
        }
      }

      // Strategy 2: Also try geolocator's approach as backup
      await Future.delayed(const Duration(milliseconds: 500));
      final currentPermission = await Geolocator.checkPermission();

      if (currentPermission == LocationPermission.whileInUse) {
        if (kDebugMode) {
          print('🔄 Attempting to upgrade to Always permission...');
        }

        // Try to request again - sometimes this triggers the upgrade dialog
        await Geolocator.requestPermission();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error requesting background location: $e');
      }
    }
  }

  Future<void> _start() async {
    await _subscription?.cancel();

    // Optimized location settings for accurate route tracking
    final Stream<Position> stream;
    if (defaultTargetPlatform == TargetPlatform.android) {
      stream = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy:
              LocationAccuracy.high, // High accuracy for precise route tracking
          distanceFilter:
              5, // Reduced to capture more GPS points for accurate distance
          intervalDuration: const Duration(
            seconds: 5,
          ), // More frequent updates for route tracking
          forceLocationManager:
              false, // Use FusedLocationProvider for better battery
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationText: 'Tracking your route accurately',
            notificationTitle: 'TripSync',
            enableWakeLock: true, // Enable wake lock for continuous tracking
            notificationIcon: AndroidResource(
              name: 'ic_location',
              defType: 'drawable',
            ),
          ),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      stream = Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy:
              LocationAccuracy.high, // High accuracy for precise route tracking
          distanceFilter:
              5, // Reduced to capture more GPS points for accurate distance
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically:
              false, // Disable auto-pause for continuous route tracking
          activityType: ActivityType.otherNavigation, // Optimize for navigation
        ),
      );
    } else {
      stream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );
    }

    _subscription = stream.listen(
      (position) {
        state = state.copyWith(currentPosition: position);
        _updateMovementState(position);
        _conditionallyPersistPosition(position);
      },
      onError: (Object error, StackTrace stackTrace) async {
        // Swallow permission errors and try to (re)request permissions
        try {
          await _ensurePermissions(forceRequest: true);
        } catch (_) {}
      },
      cancelOnError: false,
    );
    // Fetch an immediate high-accuracy fix to seed the UI
    try {
      final Position immediate = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      state = state.copyWith(currentPosition: immediate);
    } catch (_) {
      // ignore and rely on stream
    }
    _registerDispose();
  }

  Future<void> refreshNow() async {
    try {
      final Position p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      state = state.copyWith(currentPosition: p);
    } catch (_) {}
  }

  bool _hasMeaningfulMovement(Position current) {
    const double minDistanceMeters =
        3.0; // Reduced for more sensitive route tracking
    const int minSecondsBetween = 10; // Reduced for more frequent updates
    const double minAccuracyMeters =
        50.0; // More lenient accuracy for route tracking

    final DateTime now = DateTime.now();
    if (_lastPersistedPosition == null) return true; // first point

    final double distance = Geolocator.distanceBetween(
      _lastPersistedPosition!.latitude,
      _lastPersistedPosition!.longitude,
      current.latitude,
      current.longitude,
    );

    final int secondsSince = _lastPersistedTime == null
        ? 999999
        : now.difference(_lastPersistedTime!).inSeconds;

    final bool accuracyGood =
        (current.accuracy.isFinite && current.accuracy <= minAccuracyMeters);

    // Filter out GPS noise: ignore movements that are too small or too large
    if (distance < 1.0) return false; // Too small, likely GPS noise
    if (distance > 1000.0) return false; // Too large, likely GPS error

    // Save if moved enough with decent accuracy, or if a lot of time passed and moved some
    if (accuracyGood && distance >= minDistanceMeters) return true;
    if (secondsSince >= minSecondsBetween &&
        distance >= (minDistanceMeters / 2))
      return true;
    return false;
  }

  void _updateMovementState(Position position) {
    final speed = position.speed;

    // Consider moving if speed > 0.5 m/s (1.8 km/h) or any movement for route tracking
    final isCurrentlyMoving =
        speed > 0.5 ||
        (_lastPersistedPosition != null &&
            Geolocator.distanceBetween(
                  _lastPersistedPosition!.latitude,
                  _lastPersistedPosition!.longitude,
                  position.latitude,
                  position.longitude,
                ) >
                2); // 2 meters movement for more sensitive tracking

    if (isCurrentlyMoving) {
      // Movement detected for route tracking
    }
  }

  Future<void> _conditionallyPersistPosition(Position p) async {
    _updateMovementState(p);
    if (!_hasMeaningfulMovement(p)) return;

    // enqueue locally first
    await _localQueue.enqueue(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy.isFinite ? p.accuracy : null,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    // Send to backend Trip Recording System
    _sendToBackend(p);

    // attempt background sync
    unawaited(_syncLocalQueue());
  }

  /// Send sensor data to backend Trip Recording System
  Future<void> _sendToBackend(Position position) async {
    try {
      final result = await _backendService.sendSensorData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy.isFinite ? position.accuracy : 100.0,
        speedMps: position.speed.isFinite ? position.speed : null,
        altitude: position.altitude.isFinite ? position.altitude : null,
        bearing: position.heading.isFinite ? position.heading : null,
        platform: defaultTargetPlatform.name,
      );

      if (result.success && result.data != null) {
        // Log trip state changes
        final stateData = result.data!['state_machine'];
        if (stateData != null && stateData['state_changed'] == true) {
          print(
            '🚗 Trip state changed: ${stateData['current_state']} - ${stateData['trip_id']}',
          );
        }
      } else if (result.error != null) {
        print('Backend error: ${result.error}');
        // Handle authentication errors
        if (result.statusCode == 401) {
          print('⚠️ Authentication expired - user needs to log in again');
        }
      }
    } catch (e) {
      print('Backend sensor data error: $e');
      // Continue silently - don't break location tracking if backend is down
    }
  }

  void _registerDispose() {
    ref.onDispose(() {
      _subscription?.cancel();
      _connectivitySub?.cancel();
    });
  }

  Future<void> _syncLocalQueue() async {
    // Clean up old entries periodically to save storage
    await _localQueue.cleanupOldEntries();

    // Optimize storage every 10th sync to remove duplicates
    final stats = await _localQueue.getStorageStats();
    if (stats['rowCount']! > 1000) {
      await _localQueue.optimizeStorage();
    }

    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return;
    final pending = await _localQueue.peekAll();
    if (pending.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final supabase = ref.read(supabaseProvider);

    final List<int> flushedIds = [];
    final List<Map<String, dynamic>> locationsToInsert = [];

    for (final row in pending.take(200)) {
      // Reduced batch size for better performance
      locationsToInsert.add({
        'user_id': user.id,
        'latitude': (row['latitude'] as num).toDouble(),
        'longitude': (row['longitude'] as num).toDouble(),
        'accuracy': (row['accuracy'] as num?)?.toDouble(),
        'client_timestamp_ms': row['timestamp_ms'] as int,
        'created_at': DateTime.now().toIso8601String(),
      });
      flushedIds.add(row['id'] as int);
    }

    try {
      await supabase.from('locations').insert(locationsToInsert);
      await _localQueue.deleteByIds(flushedIds);
    } catch (_) {
      // if batch fails, fallback to incremental next time
    }
  }

  Future<void> syncNow() async {
    await _syncLocalQueue();
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(() {
      return LocationController();
    });
