import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip_models.dart';

class TripRepository {
  final Ref ref;
  TripRepository(this.ref);

  // Local storage for trips (will be replaced with your chosen database)
  final List<TripSummary> _trips = [];
  final Map<String, List<TripPoint>> _tripPoints = {};

  Future<String> startTrip({
    required String uid,
    TripMode mode = TripMode.unknown,
    TripPurpose purpose = TripPurpose.unknown,
    Companions companions = const Companions(),
    String? destinationRegion,
    String? originRegion,
    String? tripNumber,
    String? chainId,
    // Enhanced destination information
    String? destinationName,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationPlaceId,
    String? originName,
    String? originAddress,
    double? originLatitude,
    double? originLongitude,
    String? originPlaceId,
  }) async {
    final now = DateTime.now();
    final tripId = DateTime.now().millisecondsSinceEpoch.toString();

    final trip = TripSummary(
      id: tripId,
      startedAt: now,
      endedAt: null,
      distanceMeters: 0,
      mode: mode,
      purpose: purpose,
      companions: companions,
      timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      destinationRegion: destinationRegion,
      originRegion: originRegion,
      tripNumber: tripNumber,
      chainId: chainId,
      destinationName: destinationName,
      destinationAddress: destinationAddress,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      destinationPlaceId: destinationPlaceId,
      originName: originName,
      originAddress: originAddress,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      originPlaceId: originPlaceId,
    );

    _trips.add(trip);
    _tripPoints[tripId] = [];
    return tripId;
  }

  Future<void> appendPoints({
    required String uid,
    required String tripId,
    required List<TripPoint> points,
  }) async {
    if (points.isEmpty) return;
    _tripPoints[tripId]?.addAll(points);
  }

  Future<void> updateSummary({
    required String uid,
    required String tripId,
    double? distanceMeters,
    DateTime? endedAt,
    TripMode? mode,
    TripPurpose? purpose,
    Companions? companions,
    bool? isRecurring,
    String? destinationRegion,
    String? originRegion,
    String? tripNumber,
    String? chainId,
    // Enhanced destination information
    String? destinationName,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationPlaceId,
    String? originName,
    String? originAddress,
    double? originLatitude,
    double? originLongitude,
    String? originPlaceId,
    // Additional detailed trip information
    double? averageSpeed,
    double? maxSpeed,
    double? minSpeed,
    int? totalPoints,
    double? totalElevationGain,
    double? totalElevationLoss,
    double? averageAccuracy,
    String? weatherCondition,
    double? temperature,
    String? notes,
    List<String>? tags,
    String? routeName,
    String? routeType,
    int? stopsCount,
    double? fuelConsumption,
    double? co2Emissions,
    String? deviceInfo,
    String? appVersion,
    Map<String, dynamic>? customData,
  }) async {
    final tripIndex = _trips.indexWhere((trip) => trip.id == tripId);
    if (tripIndex == -1) return;

    final existingTrip = _trips[tripIndex];
    _trips[tripIndex] = TripSummary(
      id: existingTrip.id,
      startedAt: existingTrip.startedAt,
      timezoneOffsetMinutes: existingTrip.timezoneOffsetMinutes,
      distanceMeters: distanceMeters ?? existingTrip.distanceMeters,
      endedAt: endedAt ?? existingTrip.endedAt,
      mode: mode ?? existingTrip.mode,
      purpose: purpose ?? existingTrip.purpose,
      companions: companions ?? existingTrip.companions,
      isRecurring: isRecurring ?? existingTrip.isRecurring,
      destinationRegion: destinationRegion ?? existingTrip.destinationRegion,
      originRegion: originRegion ?? existingTrip.originRegion,
      tripNumber: tripNumber ?? existingTrip.tripNumber,
      chainId: chainId ?? existingTrip.chainId,
      destinationName: destinationName ?? existingTrip.destinationName,
      destinationAddress: destinationAddress ?? existingTrip.destinationAddress,
      destinationLatitude:
          destinationLatitude ?? existingTrip.destinationLatitude,
      destinationLongitude:
          destinationLongitude ?? existingTrip.destinationLongitude,
      destinationPlaceId: destinationPlaceId ?? existingTrip.destinationPlaceId,
      originName: originName ?? existingTrip.originName,
      originAddress: originAddress ?? existingTrip.originAddress,
      originLatitude: originLatitude ?? existingTrip.originLatitude,
      originLongitude: originLongitude ?? existingTrip.originLongitude,
      originPlaceId: originPlaceId ?? existingTrip.originPlaceId,
      averageSpeed: averageSpeed ?? existingTrip.averageSpeed,
      maxSpeed: maxSpeed ?? existingTrip.maxSpeed,
      minSpeed: minSpeed ?? existingTrip.minSpeed,
      totalPoints: totalPoints ?? existingTrip.totalPoints,
      totalElevationGain: totalElevationGain ?? existingTrip.totalElevationGain,
      totalElevationLoss: totalElevationLoss ?? existingTrip.totalElevationLoss,
      averageAccuracy: averageAccuracy ?? existingTrip.averageAccuracy,
      weatherCondition: weatherCondition ?? existingTrip.weatherCondition,
      temperature: temperature ?? existingTrip.temperature,
      notes: notes ?? existingTrip.notes,
      tags: tags ?? existingTrip.tags,
      routeName: routeName ?? existingTrip.routeName,
      routeType: routeType ?? existingTrip.routeType,
      stopsCount: stopsCount ?? existingTrip.stopsCount,
      fuelConsumption: fuelConsumption ?? existingTrip.fuelConsumption,
      co2Emissions: co2Emissions ?? existingTrip.co2Emissions,
      deviceInfo: deviceInfo ?? existingTrip.deviceInfo,
      appVersion: appVersion ?? existingTrip.appVersion,
      customData: customData ?? existingTrip.customData,
    );
  }

  Future<void> deleteTrip({required String uid, required String tripId}) async {
    _trips.removeWhere((trip) => trip.id == tripId);
    _tripPoints.remove(tripId);
  }

  Stream<List<TripSummary>> getTrips({
    required String uid,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    // Return a stream that emits the current list of trips
    return Stream.value(_trips.take(limit).toList());
  }

  Future<List<TripPoint>> getTripPoints({
    required String uid,
    required String tripId,
  }) async {
    return _tripPoints[tripId] ?? [];
  }

  Stream<List<TripSummary>> watchRecentTrips(String uid, {int limit = 50}) {
    return getTrips(uid: uid, limit: limit);
  }

  Future<void> batchUpdateTrips({
    required String uid,
    required List<String> tripIds,
    TripMode? mode,
    TripPurpose? purpose,
    Companions? companions,
    String? destinationRegion,
    String? originRegion,
    String? tripNumber,
    String? chainId,
  }) async {
    for (final tripId in tripIds) {
      await updateSummary(
        uid: uid,
        tripId: tripId,
        mode: mode,
        purpose: purpose,
        companions: companions,
        destinationRegion: destinationRegion,
        originRegion: originRegion,
        tripNumber: tripNumber,
        chainId: chainId,
      );
    }
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref);
});
