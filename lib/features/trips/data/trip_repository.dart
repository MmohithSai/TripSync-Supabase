import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../domain/trip_models.dart';

class TripRepository {
  final Ref ref;
  TripRepository(this.ref);

  // Local storage for trips (will be replaced with your chosen database)
  final List<TripSummary> _trips = [];
  final Map<String, List<TripPoint>> _tripPoints = {};

  /// Save a trip to Supabase in your specified format
  Future<String> saveTripToSupabase({
    required String userId,
    required Map<String, double> startLocation,
    required Map<String, double> endLocation,
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

  /// Get trips for a user from Supabase
  Future<List<Map<String, dynamic>>> getUserTripsFromSupabase(String userId) async {
    final supabase = ref.read(supabaseProvider);

    final response = await supabase
        .from('trips')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get user's trips stream for real-time updates from Supabase
  Stream<List<Map<String, dynamic>>> getUserTripsStreamFromSupabase(String userId) {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('timestamp', ascending: false);
  }

  /// Get trip statistics from Supabase
  Future<Map<String, dynamic>> getTripStatsFromSupabase(String userId) async {
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

  /// Update a trip in Supabase
  Future<void> updateTripInSupabase({
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

  /// Delete a trip from Supabase
  Future<void> deleteTripFromSupabase({
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

    // Create trip in Supabase
    final supabase = ref.read(supabaseProvider);
    final tripData = {
      'id': tripId,
      'user_id': uid,
      'start_location': {
        'lat': originLatitude ?? 0.0,
        'lng': originLongitude ?? 0.0,
      },
      'end_location': {
        'lat': destinationLatitude ?? 0.0,
        'lng': destinationLongitude ?? 0.0,
      },
      'distance_km': 0.0,
      'duration_min': 0,
      'timestamp': now.toIso8601String(),
      'mode': mode.name,
      'purpose': purpose.name,
      'companions': companions.toMap(),
      'is_recurring': false,
      if (destinationRegion != null) 'destination_region': destinationRegion,
      if (originRegion != null) 'origin_region': originRegion,
      if (tripNumber != null) 'trip_number': tripNumber,
      if (chainId != null) 'chain_id': chainId,
      if (destinationName != null) 'destination_name': destinationName,
      if (destinationAddress != null) 'destination_address': destinationAddress,
      if (originName != null) 'origin_name': originName,
      if (originAddress != null) 'origin_address': originAddress,
    };

    try {
      await supabase.from('trips').insert(tripData);
    } catch (e) {
      print('Failed to create trip in Supabase: $e');
    }

    // Also store locally for immediate access
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
    
    // Store locally
    _tripPoints[tripId]?.addAll(points);
    
    // Also save to Supabase
    final supabase = ref.read(supabaseProvider);
    final pointsData = points.map((point) => {
      'trip_id': tripId,
      'user_id': uid,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'timestamp': point.timestamp.toIso8601String(),
      'timezone_offset_minutes': point.timezoneOffsetMinutes,
      if (point.accuracy != null) 'accuracy': point.accuracy,
      if (point.altitude != null) 'altitude': point.altitude,
      if (point.speed != null) 'speed': point.speed,
      if (point.heading != null) 'heading': point.heading,
    }).toList();
    
    try {
      await supabase.from('trip_points').insert(pointsData);
    } catch (e) {
      // Continue if cloud sync fails - data is still stored locally
      print('Failed to sync trip points to Supabase: $e');
    }
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
    // Update locally
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
    
    // Also update in Supabase
    final supabase = ref.read(supabaseProvider);
    final updateData = <String, dynamic>{};
    
    if (distanceMeters != null) updateData['distance_km'] = distanceMeters / 1000;
    if (endedAt != null) updateData['ended_at'] = endedAt.toIso8601String();
    if (mode != null) updateData['mode'] = mode.name;
    if (purpose != null) updateData['purpose'] = purpose.name;
    if (companions != null) updateData['companions'] = companions.toMap();
    if (isRecurring != null) updateData['is_recurring'] = isRecurring;
    if (destinationRegion != null) updateData['destination_region'] = destinationRegion;
    if (originRegion != null) updateData['origin_region'] = originRegion;
    if (tripNumber != null) updateData['trip_number'] = tripNumber;
    if (chainId != null) updateData['chain_id'] = chainId;
    if (notes != null) updateData['notes'] = notes;
    
    if (updateData.isNotEmpty) {
      try {
        await supabase
            .from('trips')
            .update(updateData)
            .eq('id', tripId)
            .eq('user_id', uid);
      } catch (e) {
        print('Failed to update trip in Supabase: $e');
      }
    }
  }

  Future<void> deleteTrip({required String uid, required String tripId}) async {
    // Delete locally
    _trips.removeWhere((trip) => trip.id == tripId);
    _tripPoints.remove(tripId);
    
    // Also delete from Supabase
    try {
      await deleteTripFromSupabase(tripId: tripId, userId: uid);
    } catch (e) {
      print('Failed to delete trip from Supabase: $e');
    }
  }

  Stream<List<TripSummary>> getTrips({
    required String uid,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    // Use Supabase for real data
    final supabase = ref.read(supabaseProvider);
    var query = supabase
        .from('trips')
        .select()
        .eq('user_id', uid)
        .order('timestamp', ascending: false)
        .limit(limit);

    if (startDate != null) {
      query = query.gte('timestamp', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('timestamp', endDate.toIso8601String());
    }

    return query.stream(primaryKey: ['id']).map((data) {
      return data.map((trip) => TripSummary.fromSupabase(trip)).toList();
    });
  }

  Future<List<TripPoint>> getTripPoints({
    required String uid,
    required String tripId,
  }) async {
    // Get from Supabase
    final supabase = ref.read(supabaseProvider);
    final response = await supabase
        .from('trip_points')
        .select()
        .eq('trip_id', tripId)
        .eq('user_id', uid)
        .order('timestamp', ascending: true);

    return response.map((pointData) => TripPoint.fromMap(pointData)).toList();
  }

  Stream<List<TripSummary>> watchRecentTrips(String uid, {int limit = 50}) {
    final supabase = ref.read(supabaseProvider);
    return supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('timestamp', ascending: false)
        .limit(limit)
        .map((data) {
          return data.map((trip) => TripSummary.fromSupabase(trip)).toList();
        });
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
    final supabase = ref.read(supabaseProvider);
    final data = <String, dynamic>{};

    if (mode != null) data['mode'] = mode.name;
    if (purpose != null) data['purpose'] = purpose.name;
    if (companions != null) data['companions'] = companions.toMap();
    if (destinationRegion != null) data['destination_region'] = destinationRegion;
    if (originRegion != null) data['origin_region'] = originRegion;
    if (tripNumber != null) data['trip_number'] = tripNumber;
    if (chainId != null) data['chain_id'] = chainId;

    if (data.isNotEmpty) {
      await supabase
          .from('trips')
          .update(data)
          .inFilter('id', tripIds)
          .eq('user_id', uid);
    }
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref);
});
