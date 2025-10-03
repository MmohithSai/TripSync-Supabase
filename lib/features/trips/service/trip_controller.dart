import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../location/service/location_controller.dart';
import '../../location/service/remote_config_service.dart';
import '../../location/service/accelerometer_service.dart';
import '../../location/service/region_service.dart';
import '../domain/trip_models.dart';
import '../service/trip_service.dart';
import 'trip_sync_service.dart';
import '../../../services/backend_service.dart';

class TripData {
  final DateTime? startedAt;
  final Map<String, double>? startLocation;
  final Position? endLocation;
  final double distanceMeters;
  final List<TripPoint> allPoints;
  final String? destinationRegion;

  TripData({
    required this.startedAt,
    required this.startLocation,
    required this.endLocation,
    required this.distanceMeters,
    required this.allPoints,
    required this.destinationRegion,
  });
}

class TripState {
  final String? activeTripId;
  final List<TripPoint> bufferedPoints;
  final double distanceMeters;
  final bool autoDetectEnabled;
  final bool manuallyActive;
  final DateTime? startedAt;
  final Map<String, double>? startLocation;

  const TripState({
    required this.activeTripId,
    required this.bufferedPoints,
    required this.distanceMeters,
    required this.autoDetectEnabled,
    required this.manuallyActive,
    required this.startedAt,
    required this.startLocation,
  });

  TripState copyWith({
    String? activeTripId,
    List<TripPoint>? bufferedPoints,
    double? distanceMeters,
    bool? autoDetectEnabled,
    bool? manuallyActive,
    DateTime? startedAt,
    Map<String, double>? startLocation,
    bool clearActiveTripId = false,
    bool clearStartedAt = false,
    bool clearStartLocation = false,
  }) {
    return TripState(
      activeTripId: clearActiveTripId
          ? null
          : (activeTripId ?? this.activeTripId),
      bufferedPoints: bufferedPoints ?? this.bufferedPoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      autoDetectEnabled: autoDetectEnabled ?? this.autoDetectEnabled,
      manuallyActive: manuallyActive ?? this.manuallyActive,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      startLocation: clearStartLocation
          ? null
          : (startLocation ?? this.startLocation),
    );
  }
}

class TripController extends Notifier<TripState> {
  StreamSubscription<Position>? _sub;
  final BackendService _backendService = BackendService();

  @override
  TripState build() {
    _maybeAttach();
    return const TripState(
      activeTripId: null,
      bufferedPoints: [],
      distanceMeters: 0,
      autoDetectEnabled: true,
      manuallyActive: false,
      startedAt: null,
      startLocation: null,
    );
  }

  void _maybeAttach() {
    _sub?.cancel();
    _sub = ref.read(locationControllerProvider.notifier).positionStream.listen((
      pos,
    ) async {
      await _onPosition(pos);
    });
    ref.onDispose(() {
      _sub?.cancel();
    });
  }

  Future<void> startManual({
    TripMode mode = TripMode.unknown,
    TripPurpose purpose = TripPurpose.unknown,
    // Enhanced destination information
    String? destinationName,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationPlaceId,
  }) async {
    if (state.activeTripId != null) return;

    // 🚀 CRITICAL: Start trip in backend first
    try {
      print('🌐 Starting trip in backend...');
      final backendResult = await _backendService.startTrip();
      if (backendResult == null || backendResult['success'] == false) {
        print('❌ Backend trip start failed: ${backendResult?['error']}');
        // Continue with local trip start as fallback
      } else {
        print('✅ Backend trip started successfully');
      }
    } catch (e) {
      print('❌ Backend trip start error: $e');
      // Continue with local trip start as fallback
    }

    // Get current location to determine origin region and details
    final currentPosition = ref
        .read(locationControllerProvider)
        .currentPosition;

    // Generate a temporary trip ID for tracking
    final tripId = DateTime.now().millisecondsSinceEpoch.toString();

    state = state.copyWith(
      activeTripId: tripId,
      manuallyActive: true,
      distanceMeters: 0,
      bufferedPoints: [],
      startedAt: DateTime.now(),
      startLocation: currentPosition != null
          ? {'lat': currentPosition.latitude, 'lng': currentPosition.longitude}
          : null,
    );
  }

  Future<TripData?> stopManual() async {
    if (state.activeTripId == null) return null;

    // Store current trip data before resetting state
    final startedAt = state.startedAt;
    final startLocation = state.startLocation;
    final distanceMeters = state.distanceMeters;
    final allPoints = List<TripPoint>.from(state.bufferedPoints);

    // 🚀 IMMEDIATE: Reset UI state first for responsive UI
    print('🔄 Resetting UI state immediately...');
    print('🔄 Before reset - activeTripId: ${state.activeTripId}');

    // Create a completely new state to ensure null values are properly set
    state = TripState(
      activeTripId: null,
      bufferedPoints: [],
      distanceMeters: 0,
      autoDetectEnabled: state.autoDetectEnabled,
      manuallyActive: false,
      startedAt: null,
      startLocation: null,
    );
    print('🔄 After reset - activeTripId: ${state.activeTripId}');

    // 🛑 CRITICAL: Stop trip in backend (async, doesn't block UI)
    try {
      print('🌐 Stopping trip in backend...');
      final backendResult = await _backendService.stopTrip();
      if (backendResult == null || backendResult['success'] == false) {
        print('❌ Backend trip stop failed');
        // Continue with local trip stop as fallback
      } else {
        print('✅ Backend trip stopped successfully');
      }
    } catch (e) {
      print('❌ Backend trip stop error: $e');
      // Continue with local trip stop as fallback
    }

    // Get current location to determine destination region
    final currentPosition = ref
        .read(locationControllerProvider)
        .currentPosition;
    final destinationRegion = currentPosition != null
        ? RegionService.getRegionForLocation(
            currentPosition.latitude,
            currentPosition.longitude,
          )
        : null;

    // Use stored trip data (state was already reset above)
    final endPos = currentPosition;

    // Return trip data for the UI to collect details and save
    return TripData(
      startedAt: startedAt,
      startLocation: startLocation,
      endLocation: endPos,
      distanceMeters: distanceMeters,
      allPoints: allPoints,
      destinationRegion: destinationRegion,
    );
  }

  Future<void> saveTripWithDetails({
    required DateTime? startedAt,
    required Map<String, double>? startLocation,
    required Position? endLocation,
    required double distanceMeters,
    required List<TripPoint> allPoints,
    required String? destinationRegion,
    String? mode,
    String? purpose,
    Map<String, dynamic>? companions,
    String? notes,
  }) async {
    if (startedAt == null || startLocation == null || endLocation == null)
      return;

    final durationSeconds = DateTime.now().difference(startedAt).inSeconds;

    // Only save meaningful trips that pass validation
    if (_isMeaningfulTrip(distanceMeters, durationSeconds)) {
      final durationMin = durationSeconds ~/ 60;
      final distanceKm = distanceMeters / 1000.0;
      final tripService = ref.read(tripServiceProvider);

      try {
        await tripService.saveTrip(
          startLocation: startLocation,
          endLocation: {
            'lat': endLocation.latitude,
            'lng': endLocation.longitude,
          },
          distanceKm: distanceKm,
          durationMin: durationMin,
          mode: mode ?? 'unknown',
          purpose: purpose ?? 'unknown',
          companions: companions ?? {'adults': 0, 'children': 0, 'seniors': 0},
          notes: notes,
          originRegion: null,
          destinationRegion: destinationRegion,
          tripPoints: allPoints, // Include complete route data
        );
      } catch (e) {
        // Fallback to local queue if Supabase fails
        final queue = ref.read(pendingTripQueueProvider);
        await queue.enqueue({
          'start_location': startLocation,
          'end_location': {
            'lat': endLocation.latitude,
            'lng': endLocation.longitude,
          },
          'distance_km': distanceKm,
          'duration_min': durationMin,
          'mode': mode ?? 'unknown',
          'purpose': purpose ?? 'unknown',
          'companions':
              companions ?? {'adults': 0, 'children': 0, 'seniors': 0},
          'notes': notes,
          if (destinationRegion != null)
            'destination_region': destinationRegion,
        });
      }
    }
  }

  Future<void> _onPosition(Position p) async {
    final config = ref.read(currentTripDetectionConfigProvider);
    // Touch accelerometer provider to ensure it's initialized
    ref.read(accelerometerServiceProvider);
    final now = DateTime.now();

    // Filter out noisy/inaccurate GPS readings
    if (!_isValidPosition(p)) return;

    final point = TripPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: now,
      timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
    );

    // 🚀 CRITICAL: Send GPS data to backend for active trips
    if (state.activeTripId != null) {
      try {
        final result = await _backendService.sendSensorData(
          latitude: p.latitude,
          longitude: p.longitude,
          accuracy: p.accuracy,
          speedMps: p.speed,
          altitude: p.altitude,
          bearing: p.heading,
          deviceId: 'flutter-app',
          platform: 'flutter',
        );
        if (kDebugMode && result.success) {
          print('📡 Sent GPS data to backend: ${p.latitude}, ${p.longitude}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to send GPS data to backend: $e');
        }
      }
    }

    if (state.activeTripId == null &&
        state.autoDetectEnabled &&
        p.speed.isFinite &&
        p.speed > config.autoStartSpeedThreshold) {
      // Start trip automatically when movement is detected
      // This provides continuous tracking without manual intervention
      await startManual();
    }

    if (state.activeTripId == null) return;

    final List<TripPoint> buf = List.of(state.bufferedPoints)..add(point);
    double distance = state.distanceMeters;
    if (buf.length >= 2) {
      final a = buf[buf.length - 2];
      final b = buf[buf.length - 1];
      final segmentDistance = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );

      // Filter out noise: ignore very small movements that are likely GPS noise
      if (segmentDistance >= 2.0) {
        // Minimum 2 meters to count as movement
        distance += segmentDistance;
      }
    }
    // buffer points and flush in smaller batches for more frequent route updates
    if (buf.length >= 20) {
      // Reduced batch size for more frequent route tracking
      await _flushPoints(buf);
      buf.clear();
    }
    state = state.copyWith(bufferedPoints: buf, distanceMeters: distance);

    // Enhanced stop detection using both GPS and accelerometer
    final accelerometerState = ref
        .read(accelerometerServiceProvider)
        .getCurrentMovementState();
    if (state.autoDetectEnabled &&
        _shouldStopTrip(p, accelerometerState, config, distance)) {
      await stopManual();
    }
  }

  /// Validates GPS position to filter out noise and inaccurate readings
  bool _isValidPosition(Position position) {
    // Filter out positions with poor accuracy
    if (position.accuracy > 100.0) return false; // Accuracy worse than 100m

    // Filter out positions with invalid coordinates
    if (!position.latitude.isFinite || !position.longitude.isFinite)
      return false;

    // Filter out positions that are clearly invalid (outside Earth's bounds)
    if (position.latitude.abs() > 90 || position.longitude.abs() > 180)
      return false;

    return true;
  }

  /// Validates if a trip is meaningful enough to be saved
  bool _isMeaningfulTrip(double distance, int durationSeconds) {
    // Minimum distance threshold (50 meters)
    if (distance < 50.0) return false;

    // Minimum duration threshold (60 seconds)
    if (durationSeconds < 60) return false;

    // Check for reasonable speed (not too fast, not too slow)
    final speedKmh = (distance / 1000.0) / (durationSeconds / 3600.0);
    if (speedKmh > 200.0) return false; // Unreasonably fast (likely GPS error)
    if (speedKmh < 0.5) return false; // Too slow to be meaningful travel

    return true;
  }

  bool _shouldStopTrip(
    Position position,
    MovementState movementState,
    TripDetectionConfig config,
    double distance,
  ) {
    // Basic GPS-based stop detection
    final gpsStopped =
        position.speed.isFinite &&
        position.speed < 0.5 &&
        distance > config.minDistanceThreshold;

    // Accelerometer-based stillness detection
    final accelerometerStopped =
        !movementState.isMoving && movementState.confidence > 0.7;

    // Stop if both GPS and accelerometer indicate stillness
    // OR if GPS indicates stop and we have sufficient distance
    return (gpsStopped && accelerometerStopped) ||
        (gpsStopped &&
            movementState.sampleCount ==
                0); // Fallback if no accelerometer data
  }

  Future<void> _flushPoints(List<TripPoint> points) async {
    // During an active trip we only buffer in memory; we save all points on stop.
    // This avoids writing points to a non-existent trip ID in the backend.
    return;
  }
}

final tripControllerProvider = NotifierProvider<TripController, TripState>(
  () => TripController(),
);
