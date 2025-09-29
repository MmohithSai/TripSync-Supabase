import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../data/trip_repository.dart';

class TripService {
  final Ref ref;
  TripService(this.ref);

  /// Save a trip in your specified format
  /// Example usage:
  /// ```dart
  /// final tripService = ref.read(tripServiceProvider);
  /// await tripService.saveTrip(
  ///   startLocation: {"lat": 17.3850, "lng": 78.4867},
  ///   endLocation: {"lat": 17.4474, "lng": 78.3569},
  ///   distanceKm: 12.4,
  ///   durationMin: 25,
  /// );
  /// ```
  Future<String> saveTrip({
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
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Auto-generate identifiers if not supplied by the UI
    final now = DateTime.now();
    final generatedTripNumber = tripNumber ?? _generateTripNumber(now);
    final generatedChainId = chainId ?? _generateChainId(now);

    final repository = ref.read(tripRepositoryProvider);
    return await repository.saveTripToSupabase(
      userId: user.id,
      startLocation: startLocation,
      endLocation: endLocation,
      distanceKm: distanceKm,
      durationMin: durationMin,
      mode: mode,
      purpose: purpose,
      companions: companions,
      notes: notes,
      tripNumber: generatedTripNumber,
      chainId: generatedChainId,
      originRegion: originRegion,
      destinationRegion: destinationRegion,
      isRecurring: isRecurring,
    );
  }

  String _generateTripNumber(DateTime when) {
    final y = when.year.toString().padLeft(4, '0');
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    final ss = when.second.toString().padLeft(2, '0');
    return 'TRIP-$y$m$d-$hh$mm$ss';
  }

  String _generateChainId(DateTime when) {
    // Stable within day window; different for separate days/sessions
    final y = when.year.toString().padLeft(4, '0');
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    // Include hour bucket to group trips into chains per hour window
    final hh = when.hour.toString().padLeft(2, '0');
    return 'CHAIN-$y$m$d-$hh';
  }

  /// Get user's trips
  Future<List<Map<String, dynamic>>> getUserTrips() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final repository = ref.read(tripRepositoryProvider);
    return await repository.getUserTripsFromSupabase(user.id);
  }

  /// Get user's trips stream for real-time updates
  Stream<List<Map<String, dynamic>>> getUserTripsStream() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final repository = ref.read(tripRepositoryProvider);
    return repository.getUserTripsStreamFromSupabase(user.id);
  }

  /// Get trip statistics
  Future<Map<String, dynamic>> getTripStats() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final repository = ref.read(tripRepositoryProvider);
    return await repository.getTripStatsFromSupabase(user.id);
  }

  /// Update a trip
  Future<void> updateTrip({
    required String tripId,
    Map<String, double>? startLocation,
    Map<String, double>? endLocation,
    double? distanceKm,
    int? durationMin,
    String? mode,
    String? purpose,
    Map<String, dynamic>? companions,
    String? notes,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final repository = ref.read(tripRepositoryProvider);
    await repository.updateTripInSupabase(
      tripId: tripId,
      userId: user.id,
      startLocation: startLocation,
      endLocation: endLocation,
      distanceKm: distanceKm,
      durationMin: durationMin,
      mode: mode,
      purpose: purpose,
      companions: companions,
      notes: notes,
    );
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final repository = ref.read(tripRepositoryProvider);
    await repository.deleteTripFromSupabase(tripId: tripId, userId: user.id);
  }
}

final tripServiceProvider = Provider<TripService>((ref) => TripService(ref));
