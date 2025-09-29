import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../location/service/location_controller.dart';
import '../../location/service/remote_config_service.dart';
import '../../location/service/accelerometer_service.dart';
import '../../location/service/region_service.dart';
import '../data/trip_repository.dart';
import '../domain/trip_models.dart';
import '../service/trip_service.dart';
import '../../../common/consent_service.dart';
import 'trip_sync_service.dart';

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
  }) {
    return TripState(
      activeTripId: activeTripId ?? this.activeTripId,
      bufferedPoints: bufferedPoints ?? this.bufferedPoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      autoDetectEnabled: autoDetectEnabled ?? this.autoDetectEnabled,
      manuallyActive: manuallyActive ?? this.manuallyActive,
      startedAt: startedAt ?? this.startedAt,
      startLocation: startLocation ?? this.startLocation,
    );
  }
}

class TripController extends Notifier<TripState> {
  StreamSubscription<Position>? _sub;

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
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('User not authenticated');
    
    if (state.activeTripId != null) return;

    // Get current location to determine origin region and details
    final currentPosition = ref
        .read(locationControllerProvider)
        .currentPosition;
    final originRegion = currentPosition != null
        ? RegionService.getRegionForLocation(
            currentPosition.latitude,
            currentPosition.longitude,
          )
        : null;

    final repo = ref.read(tripRepositoryProvider);
    final id = await repo.startTrip(
      uid: user.id,
      mode: mode,
      purpose: purpose,
      originRegion: originRegion,
      destinationName: destinationName,
      destinationAddress: destinationAddress,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      destinationPlaceId: destinationPlaceId,
    );
    state = state.copyWith(
      activeTripId: id,
      manuallyActive: true,
      distanceMeters: 0,
      bufferedPoints: [],
      startedAt: DateTime.now(),
      startLocation: currentPosition != null
          ? {'lat': currentPosition.latitude, 'lng': currentPosition.longitude}
          : null,
    );
  }

  Future<void> stopManual() async {
    if (state.activeTripId == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('User not authenticated');

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

    final repo = ref.read(tripRepositoryProvider);
    await _flushBuffer();
    await repo.updateSummary(
      uid: user.id,
      tripId: state.activeTripId!,
      endedAt: DateTime.now(),
      distanceMeters: state.distanceMeters,
      destinationRegion: destinationRegion,
    );

    // Save summarized trip to Supabase if consent is given and data is ready
    try {
      final consent = await ref.read(consentServiceProvider).hasConsented();
      final startedAt = state.startedAt;
      final startLoc = state.startLocation;
      final endPos = currentPosition;
      if (consent && startedAt != null && startLoc != null && endPos != null) {
        final durationMin = DateTime.now().difference(startedAt).inMinutes;
        final distanceKm = state.distanceMeters / 1000.0;
        final tripService = ref.read(tripServiceProvider);
        await tripService.saveTrip(
          startLocation: startLoc,
          endLocation: {'lat': endPos.latitude, 'lng': endPos.longitude},
          distanceKm: distanceKm,
          durationMin: durationMin,
          mode: mode.name,
          purpose: purpose.name,
          originRegion: null,
          destinationRegion: destinationRegion,
        );
      } else if (startedAt != null && startLoc != null && endPos != null) {
        // Enqueue if consent not given or immediate upload is not allowed
        final durationMin = DateTime.now().difference(startedAt).inMinutes;
        final distanceKm = state.distanceMeters / 1000.0;
        final queue = ref.read(pendingTripQueueProvider);
        await queue.enqueue({
          'start_location': startLoc,
          'end_location': {'lat': endPos.latitude, 'lng': endPos.longitude},
          'distance_km': distanceKm,
          'duration_min': durationMin,
          'mode': 'unknown',
          'purpose': 'unknown',
          'companions': {'adults': 0, 'children': 0, 'seniors': 0},
          if (destinationRegion != null)
            'destination_region': destinationRegion,
        });
      }
    } catch (_) {
      // Ignore cloud sync errors to avoid blocking UI; they can be retried later
    }
    state = state.copyWith(
      activeTripId: null,
      manuallyActive: false,
      distanceMeters: 0,
      bufferedPoints: [],
      startedAt: null,
      startLocation: null,
    );
  }

  Future<void> _onPosition(Position p) async {
    final config = ref.read(currentTripDetectionConfigProvider);
    // Touch accelerometer provider to ensure it's initialized
    ref.read(accelerometerServiceProvider);
    final now = DateTime.now();
    final point = TripPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: now,
      timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
    );

    if (state.activeTripId == null &&
        state.autoDetectEnabled &&
        p.speed.isFinite &&
        p.speed > config.autoStartSpeedThreshold) {
      // Check if we've been moving for the required time threshold
      // This is a simplified implementation - in practice you'd track movement over time
      await startManual();
    }

    if (state.activeTripId == null) return;

    final List<TripPoint> buf = List.of(state.bufferedPoints)..add(point);
    double distance = state.distanceMeters;
    if (buf.length >= 2) {
      final a = buf[buf.length - 2];
      final b = buf[buf.length - 1];
      distance += Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
    }
    // buffer points and flush in larger batches for better efficiency
    if (buf.length >= 50) {
      // Increased batch size for better battery efficiency
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
    if (state.activeTripId == null || points.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    
    final repo = ref.read(tripRepositoryProvider);
    await repo.appendPoints(
      uid: user.id,
      tripId: state.activeTripId!,
      points: List.of(points),
    );
  }

  Future<void> _flushBuffer() async {
    await _flushPoints(state.bufferedPoints);
  }
}

final tripControllerProvider = NotifierProvider<TripController, TripState>(
  () => TripController(),
);
