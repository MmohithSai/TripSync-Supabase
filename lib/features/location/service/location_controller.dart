import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../common/providers.dart';
import '../data/local_location_queue.dart';

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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Position? _lastPersistedPosition;
  DateTime? _lastPersistedTime;
  final LocalLocationQueue _localQueue = LocalLocationQueue();

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

  Stream<Position> get positionStream => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      );

  Future<void> _init() async {
    await _ensurePermissions();
    if (state.permissionsGranted) {
      await _start();
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
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
      permissionsGranted: permission == LocationPermission.always || permission == LocationPermission.whileInUse,
      serviceEnabled: serviceEnabled,
    );
  }

  Future<void> _start() async {
    await _subscription?.cancel();

    final LocationSettings baseSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    // Platform-specific tuning (foreground service notification only on Android when supported)
    final Stream<Position> stream;
    if (defaultTargetPlatform == TargetPlatform.android) {
      stream = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          // Faster updates while in foreground (battery trade-off)
          intervalDuration: const Duration(milliseconds: 800),
          forceLocationManager: true,
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationText: 'Tracking location in background',
            notificationTitle: 'TripSync',
            enableWakeLock: true,
          ),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      stream = Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically: false,
        ),
      );
    } else {
      stream = Geolocator.getPositionStream(locationSettings: baseSettings);
    }

    _subscription = stream.listen(
      (position) {
        state = state.copyWith(currentPosition: position);
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
    // Require at least 50 meters movement or 20 seconds elapsed and >30m HDOP approximation
    const double minDistanceMeters = 50.0;
    const int minSecondsBetween = 20;
    const double minAccuracyMeters = 30.0;

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

    final bool accuracyGood = (current.accuracy.isFinite && current.accuracy <= minAccuracyMeters);

    // Save if moved enough with decent accuracy, or if a lot of time passed and moved some
    if (accuracyGood && distance >= minDistanceMeters) return true;
    if (secondsSince >= minSecondsBetween && distance >= (minDistanceMeters / 2)) return true;
    return false;
  }

  Future<void> _conditionallyPersistPosition(Position p) async {
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

  Future<void> _flushToCloud({
    required double latitude,
    required double longitude,
    double? accuracy,
    required int timestampMs,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final fs = ref.read(firestoreProvider);
    final doc = fs.collection('users').doc(user.uid).collection('locations').doc();
    await doc.set({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': FieldValue.serverTimestamp(),
      'clientTimestampMs': timestampMs,
    }, SetOptions(merge: false));
    _lastPersistedPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      accuracy: accuracy ?? 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    _lastPersistedTime = DateTime.now();
  }

  Future<void> _syncLocalQueue() async {
    final results = await Connectivity().checkConnectivity();
    if (!results.any((r) => r != ConnectivityResult.none)) return;
    final pending = await _localQueue.peekAll();
    if (pending.isEmpty) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final fs = ref.read(firestoreProvider);
    final batch = fs.batch();
    final List<int> flushedIds = [];
    for (final row in pending.take(300)) { // cap batch size
      final doc = fs.collection('users').doc(user.uid).collection('locations').doc();
      batch.set(doc, {
        'latitude': (row['latitude'] as num).toDouble(),
        'longitude': (row['longitude'] as num).toDouble(),
        'accuracy': (row['accuracy'] as num?)?.toDouble(),
        'timestamp': FieldValue.serverTimestamp(),
        'clientTimestampMs': row['timestamp_ms'] as int,
      });
      flushedIds.add(row['id'] as int);
    }
    try {
      await batch.commit();
      await _localQueue.deleteByIds(flushedIds);
    } catch (_) {
      // if batch fails, fallback to incremental next time
    }
  }

  Future<void> syncNow() async {
    await _syncLocalQueue();
  }
}

final locationControllerProvider = NotifierProvider<LocationController, LocationState>(() {
  return LocationController();
});



