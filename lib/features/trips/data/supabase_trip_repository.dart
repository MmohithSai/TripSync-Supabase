import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../domain/trip_models.dart';

class SupabaseTripRepository {
  final Ref ref;
  SupabaseTripRepository(this.ref);

  /// Create a trip row at start and return its id
  Future<String> createTripStart({
    required String userId,
    required Map<String, double> startLocation,
    String? originRegion,
    String mode = 'unknown',
    String purpose = 'unknown',
    String? tripNumber,
    String? chainId,
    String? notes,
  }) async {
    final supabase = ref.read(supabaseProvider);
    final data = {
      'user_id': userId,
      'start_location': startLocation,
      'end_location': startLocation,
      'distance_km': 0.0,
      'duration_min': 0,
      'timestamp': DateTime.now().toIso8601String(),
      'mode': mode,
      'purpose': purpose,
      if (originRegion != null) 'origin_region': originRegion,
      if (tripNumber != null) 'trip_number': tripNumber,
      if (chainId != null) 'chain_id': chainId,
      if (notes != null) 'notes': notes,
    };
    final response = await supabase
        .from('trips')
        .insert(data)
        .select()
        .single();
    return response['id'] as String;
  }

  /// Save a trip to Supabase in your specified format
  Future<String> saveTrip({
    required String userId,
    required Map<String, double>
    startLocation, // {"lat": 17.3850, "lng": 78.4867}
    required Map<String, double>
    endLocation, // {"lat": 17.4474, "lng": 78.3569}
    required double distanceKm,
    required int durationMin,
    String mode = 'unknown',
    String purpose = 'unknown',
    Map<String, dynamic>? companions,
    String? notes,
    String? tripNumber,
    String? chainId,
    String? originRegion,
    String? destinationRegion,
    bool isRecurring = false,
    List<TripPoint>? tripPoints, // Complete route data
  }) async {
    final supabase = ref.read(supabaseProvider);

    final tripData = {
      'user_id': userId,
      'start_location': startLocation,
      'end_location': endLocation,
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'timestamp': DateTime.now().toIso8601String(),
      'mode': mode,
      'purpose': purpose,
      'companions': companions ?? {'adults': 0, 'children': 0, 'seniors': 0},
      'is_recurring': isRecurring,
      if (originRegion != null) 'origin_region': originRegion,
      if (destinationRegion != null) 'destination_region': destinationRegion,
      if (tripNumber != null) 'trip_number': tripNumber,
      if (chainId != null) 'chain_id': chainId,
      if (notes != null) 'notes': notes,
    };

    final response = await supabase
        .from('trips')
        .insert(tripData)
        .select()
        .single();

    final tripId = response['id'] as String;

    // Save trip points if provided
    if (tripPoints != null && tripPoints.isNotEmpty) {
      await saveTripPoints(tripId, userId, tripPoints);
    }

    return tripId;
  }

  /// Get trips for a user
  Future<List<Map<String, dynamic>>> getUserTrips(String userId) async {
    final supabase = ref.read(supabaseProvider);

    final response = await supabase
        .from('trips')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get trips stream for real-time updates
  Stream<List<Map<String, dynamic>>> getUserTripsStream(String userId) {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('timestamp', ascending: false);
  }

  /// Update a trip
  Future<void> updateTrip({
    required String tripId,
    required String userId,
    Map<String, double>? startLocation,
    Map<String, double>? endLocation,
    double? distanceKm,
    int? durationMin,
    String? mode,
    String? purpose,
    Map<String, dynamic>? companions,
    String? notes,
  }) async {
    final supabase = ref.read(supabaseProvider);

    final updateData = <String, dynamic>{};
    if (startLocation != null) updateData['start_location'] = startLocation;
    if (endLocation != null) updateData['end_location'] = endLocation;
    if (distanceKm != null) updateData['distance_km'] = distanceKm;
    if (durationMin != null) updateData['duration_min'] = durationMin;
    if (mode != null) updateData['mode'] = mode;
    if (purpose != null) updateData['purpose'] = purpose;
    if (companions != null) updateData['companions'] = companions;
    if (notes != null) updateData['notes'] = notes;

    if (updateData.isNotEmpty) {
      await supabase
          .from('trips')
          .update(updateData)
          .eq('id', tripId)
          .eq('user_id', userId);
    }
  }

  /// Finalize a trip after stopping
  Future<void> finalizeTrip({
    required String tripId,
    required String userId,
    required Map<String, double> endLocation,
    required double distanceKm,
    required int durationMin,
    String? destinationRegion,
  }) async {
    final supabase = ref.read(supabaseProvider);
    final updateData = <String, dynamic>{
      'end_location': endLocation,
      'distance_km': distanceKm,
      'duration_min': durationMin,
    };
    if (destinationRegion != null) {
      updateData['destination_region'] = destinationRegion;
    }
    await supabase
        .from('trips')
        .update(updateData)
        .eq('id', tripId)
        .eq('user_id', userId);
  }

  /// Delete a trip
  Future<void> deleteTrip({
    required String tripId,
    required String userId,
  }) async {
    final supabase = ref.read(supabaseProvider);

    await supabase
        .from('trips')
        .delete()
        .eq('id', tripId)
        .eq('user_id', userId);
  }

  /// Save trip points for a trip
  Future<void> saveTripPoints(
    String tripId,
    String userId,
    List<TripPoint> tripPoints,
  ) async {
    final supabase = ref.read(supabaseProvider);

    if (tripPoints.isEmpty) return;

    // Convert trip points to database format
    final pointsData = tripPoints
        .map(
          (point) => {
            'trip_id': tripId,
            'user_id': userId,
            'latitude': point.latitude,
            'longitude': point.longitude,
            'timestamp': point.timestamp.toIso8601String(),
            'timezone_offset_minutes': point.timezoneOffsetMinutes,
            if (point.accuracy != null) 'accuracy': point.accuracy,
            if (point.altitude != null) 'altitude': point.altitude,
            if (point.speed != null) 'speed': point.speed,
            if (point.heading != null) 'heading': point.heading,
            if (point.speedAccuracy != null)
              'speed_accuracy': point.speedAccuracy,
            if (point.headingAccuracy != null)
              'heading_accuracy': point.headingAccuracy,
            if (point.address != null) 'address': point.address,
            if (point.placeName != null) 'place_name': point.placeName,
            if (point.placeId != null) 'place_id': point.placeId,
            if (point.roadName != null) 'road_name': point.roadName,
            if (point.city != null) 'city': point.city,
            if (point.country != null) 'country': point.country,
            if (point.postalCode != null) 'postal_code': point.postalCode,
            if (point.metadata != null) 'metadata': point.metadata,
          },
        )
        .toList();

    // Insert in batches to avoid database limits
    const batchSize = 100;
    for (int i = 0; i < pointsData.length; i += batchSize) {
      final batch = pointsData.skip(i).take(batchSize).toList();
      await supabase.from('trip_points').insert(batch);
    }
  }

  /// Get trip points for a specific trip
  Future<List<TripPoint>> getTripPoints(String tripId, String userId) async {
    final supabase = ref.read(supabaseProvider);

    final response = await supabase
        .from('trip_points')
        .select()
        .eq('trip_id', tripId)
        .eq('user_id', userId)
        .order('timestamp', ascending: true);

    return response.map((data) => TripPoint.fromMap(data)).toList();
  }

  /// Get trip with complete route data
  Future<Map<String, dynamic>?> getTripWithRoute(
    String tripId,
    String userId,
  ) async {
    final supabase = ref.read(supabaseProvider);

    // Get trip data
    final tripResponse = await supabase
        .from('trips')
        .select()
        .eq('id', tripId)
        .eq('user_id', userId)
        .single();

    // tripResponse will never be null due to .single() call

    // Get trip points
    final pointsResponse = await supabase
        .from('trip_points')
        .select()
        .eq('trip_id', tripId)
        .eq('user_id', userId)
        .order('timestamp', ascending: true);

    final tripPoints = pointsResponse
        .map((data) => TripPoint.fromMap(data))
        .toList();

    return {
      'trip': tripResponse,
      'points': tripPoints.map((point) => point.toMap()).toList(),
    };
  }

  /// Get trips with route data for a user
  Future<List<Map<String, dynamic>>> getUserTripsWithRoutes(
    String userId,
  ) async {
    final supabase = ref.read(supabaseProvider);

    final trips = await getUserTrips(userId);
    final tripsWithRoutes = <Map<String, dynamic>>[];

    for (final trip in trips) {
      final tripId = trip['id'] as String;
      final pointsResponse = await supabase
          .from('trip_points')
          .select()
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .order('timestamp', ascending: true);

      final tripPoints = pointsResponse
          .map((data) => TripPoint.fromMap(data))
          .toList();

      tripsWithRoutes.add({
        'trip': trip,
        'points': tripPoints.map((point) => point.toMap()).toList(),
      });
    }

    return tripsWithRoutes;
  }

  /// Update trip points for an existing trip
  Future<void> updateTripPoints(
    String tripId,
    String userId,
    List<TripPoint> tripPoints,
  ) async {
    final supabase = ref.read(supabaseProvider);

    // Delete existing points
    await supabase
        .from('trip_points')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', userId);

    // Insert new points
    if (tripPoints.isNotEmpty) {
      await saveTripPoints(tripId, userId, tripPoints);
    }
  }

  /// Get trip statistics
  Future<Map<String, dynamic>> getTripStats(String userId) async {
    final supabase = ref.read(supabaseProvider);

    final response = await supabase
        .from('trips')
        .select('distance_km, duration_min, mode')
        .eq('user_id', userId);

    if (response.isEmpty) {
      return {
        'total_trips': 0,
        'total_distance_km': 0.0,
        'total_duration_min': 0,
        'average_distance_km': 0.0,
        'average_duration_min': 0.0,
        'mode_distribution': <String, int>{},
      };
    }

    final totalTrips = response.length;
    final totalDistance = response.fold<double>(
      0.0,
      (sum, trip) => sum + (trip['distance_km'] as num).toDouble(),
    );
    final totalDuration = response.fold<int>(
      0,
      (sum, trip) => sum + (trip['duration_min'] as num).toInt(),
    );

    final modeDistribution = <String, int>{};
    for (final trip in response) {
      final mode = trip['mode'] as String;
      modeDistribution[mode] = (modeDistribution[mode] ?? 0) + 1;
    }

    return {
      'total_trips': totalTrips,
      'total_distance_km': totalDistance,
      'total_duration_min': totalDuration,
      'average_distance_km': totalDistance / totalTrips,
      'average_duration_min': totalDuration / totalTrips,
      'mode_distribution': modeDistribution,
    };
  }
}

final supabaseTripRepositoryProvider = Provider<SupabaseTripRepository>(
  (ref) => SupabaseTripRepository(ref),
);
