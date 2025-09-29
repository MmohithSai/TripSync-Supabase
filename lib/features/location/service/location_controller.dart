import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../common/providers.dart';
import '../data/local_location_queue.dart';
import 'remote_config_service.dart';

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
  DateTime? _lastMovementTime;

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

  Future<void> _ensurePermissions({bool forceRequest = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    // Only trigger OS dialog when explicitly requested
    if (forceRequest) {
      permission = await Geolocator.requestPermission();
    }

    state = state.copyWith(
      permissionsGranted:
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse,
      serviceEnabled: serviceEnabled,
    );
  }

  Future<void> _start() async {
    await _subscription?.cancel();

    // Optimized location settings for battery efficiency
    final Stream<Position> stream;
    if (defaultTargetPlatform == TargetPlatform.android) {
      stream = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.low, // Further reduced for battery savings
          distanceFilter: 100, // Increased to reduce frequency
          intervalDuration: const Duration(seconds: 30), // Increased interval
          forceLocationManager:
              false, // Use FusedLocationProvider for better battery
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationText: 'Tracking location efficiently',
            notificationTitle: 'TripSync',
            enableWakeLock: false, // Disable wake lock for battery savings
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
          accuracy: LocationAccuracy.low, // Further reduced for battery savings
          distanceFilter: 100, // Increased to reduce frequency
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically:
              true, // Enable auto-pause for battery
          activityType: ActivityType.otherNavigation, // Optimize for navigation
        ),
      );
    } else {
      stream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
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
    final config = ref.read(currentTripDetectionConfigProvider);
    final double minDistanceMeters = config.distanceFilter;
    const int minSecondsBetween = 30;
    const double minAccuracyMeters = 25.0;

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

    // Save if moved enough with decent accuracy, or if a lot of time passed and moved some
    if (accuracyGood && distance >= minDistanceMeters) return true;
    if (secondsSince >= minSecondsBetween &&
        distance >= (minDistanceMeters / 2))
      return true;
    return false;
  }

  void _updateMovementState(Position position) {
    final now = DateTime.now();
    final speed = position.speed;

    // Consider moving if speed > 1 m/s (3.6 km/h) or significant movement
    final isCurrentlyMoving =
        speed > 1.0 ||
        (_lastPersistedPosition != null &&
            Geolocator.distanceBetween(
                  _lastPersistedPosition!.latitude,
                  _lastPersistedPosition!.longitude,
                  position.latitude,
                  position.longitude,
                ) >
                20); // 20 meters movement

    if (isCurrentlyMoving) {
      _lastMovementTime = now;
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
    // attempt background sync
    unawaited(_syncLocalQueue());
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
