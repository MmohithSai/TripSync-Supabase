import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';

class SupabaseTripRepository {
  final Ref ref;
  SupabaseTripRepository(this.ref);

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

    return response['id'] as String;
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
