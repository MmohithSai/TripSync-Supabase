import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../common/providers.dart';
import '../../location/service/location_controller.dart';
import '../../location/service/remote_config_service.dart';
import '../../location/service/accelerometer_service.dart';
import '../../location/service/region_service.dart';
import '../data/trip_repository.dart';
import '../domain/trip_models.dart';

class TripState {
  final String? activeTripId;
  final List<TripPoint> bufferedPoints;
  final double distanceMeters;
  final bool autoDetectEnabled;
  final bool manuallyActive;

  const TripState({
    required this.activeTripId,
    required this.bufferedPoints,
    required this.distanceMeters,
    required this.autoDetectEnabled,
    required this.manuallyActive,
  });

  TripState copyWith({
    String? activeTripId,
    List<TripPoint>? bufferedPoints,
    double? distanceMeters,
    bool? autoDetectEnabled,
    bool? manuallyActive,
  }) {
    return TripState(
      activeTripId: activeTripId ?? this.activeTripId,
      bufferedPoints: bufferedPoints ?? this.bufferedPoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      autoDetectEnabled: autoDetectEnabled ?? this.autoDetectEnabled,
      manuallyActive: manuallyActive ?? this.manuallyActive,
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
    );
  }

  void _maybeAttach() {
    _sub?.cancel();
    _sub = ref.read(locationControllerProvider.notifier).positionStream.listen((pos) async {
      await _onPosition(pos);
    });
    ref.onDispose(() {
      _sub?.cancel();
    });
  }

  Future<void> startManual({TripMode mode = TripMode.unknown, TripPurpose purpose = TripPurpose.unknown}) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    if (state.activeTripId != null) return;
    
    // Get current location to determine origin region
    final currentPosition = ref.read(locationControllerProvider).currentPosition;
    final originRegion = currentPosition != null 
        ? RegionService.getRegionForLocation(currentPosition.latitude, currentPosition.longitude)
        : null;
    
    final repo = ref.read(tripRepositoryProvider);
    final id = await repo.startTrip(
      uid: user.uid, 
      mode: mode, 
      purpose: purpose,
      originRegion: originRegion,
    );
    state = state.copyWith(activeTripId: id, manuallyActive: true, distanceMeters: 0, bufferedPoints: []);
  }

  Future<void> stopManual() async {
    if (state.activeTripId == null) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    
    // Get current location to determine destination region
    final currentPosition = ref.read(locationControllerProvider).currentPosition;
    final destinationRegion = currentPosition != null 
        ? RegionService.getRegionForLocation(currentPosition.latitude, currentPosition.longitude)
        : null;
    
    final repo = ref.read(tripRepositoryProvider);
    await _flushBuffer();
    await repo.updateSummary(
      uid: user.uid, 
      tripId: state.activeTripId!, 
      endedAt: DateTime.now(), 
      distanceMeters: state.distanceMeters,
      destinationRegion: destinationRegion,
    );
    state = state.copyWith(activeTripId: null, manuallyActive: false, distanceMeters: 0, bufferedPoints: []);
  }

  Future<void> _onPosition(Position p) async {
    final config = ref.read(currentTripDetectionConfigProvider);
    final accelerometerData = ref.read(accelerometerServiceProvider);
    final now = DateTime.now();
    final point = TripPoint(
      latitude: p.latitude, 
      longitude: p.longitude, 
      timestamp: now,
      timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
    );

    if (state.activeTripId == null && state.autoDetectEnabled && 
        p.speed.isFinite && p.speed > config.autoStartSpeedThreshold) {
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
      distance += Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    // buffer points and flush in larger batches for better efficiency
    if (buf.length >= 50) { // Increased batch size for better battery efficiency
      await _flushPoints(buf);
      buf.clear();
    }
    state = state.copyWith(bufferedPoints: buf, distanceMeters: distance);

    // Enhanced stop detection using both GPS and accelerometer
    final accelerometerState = ref.read(accelerometerServiceProvider).getCurrentMovementState();
    if (state.autoDetectEnabled && _shouldStopTrip(p, accelerometerState, config, distance)) {
      await stopManual();
    }
  }

  bool _shouldStopTrip(Position position, MovementState movementState, 
                      TripDetectionConfig config, double distance) {
    // Basic GPS-based stop detection
    final gpsStopped = position.speed.isFinite && 
                      position.speed < 0.5 && 
                      distance > config.minDistanceThreshold;
    
    // Accelerometer-based stillness detection
    final accelerometerStopped = !movementState.isMoving &&
                                movementState.confidence > 0.7;
    
    // Stop if both GPS and accelerometer indicate stillness
    // OR if GPS indicates stop and we have sufficient distance
    return (gpsStopped && accelerometerStopped) || 
           (gpsStopped && movementState.sampleCount == 0); // Fallback if no accelerometer data
  }

  Future<void> _flushPoints(List<TripPoint> points) async {
    if (state.activeTripId == null || points.isEmpty) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final repo = ref.read(tripRepositoryProvider);
    await repo.appendPoints(uid: user.uid, tripId: state.activeTripId!, points: List.of(points));
  }

  Future<void> _flushBuffer() async {
    await _flushPoints(state.bufferedPoints);
  }
}

final tripControllerProvider = NotifierProvider<TripController, TripState>(() => TripController());





