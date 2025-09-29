import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed unused Supabase import

import '../../../common/providers.dart';
import '../../trips/domain/trip_models.dart';

class HistoryRepository {
  final Ref ref;
  HistoryRepository(this.ref);

  Stream<List<TripSummary>> getTrips({
    required String uid,
    DateTime? startDate,
    DateTime? endDate,
    TripMode? mode,
    int limit = 50,
  }) {
    final supabase = ref.read(supabaseProvider);

    // Build query with all conditions
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
    if (mode != null) {
      query = query.eq('mode', mode.toString());
    }

    return query.stream(primaryKey: ['id']).map((data) {
      return data.map((trip) => TripSummary.fromMap(trip)).toList();
    });
  }

  Stream<List<TripSummary>> watchRecentTrips(String uid, {int limit = 50}) {
    return getTrips(uid: uid, limit: limit);
  }

  Future<void> updateTrip({
    required String uid,
    required String tripId,
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

    if (mode != null) data['mode'] = mode.toString();
    if (purpose != null) data['purpose'] = purpose.toString();
    if (companions != null) data['companions'] = companions.toMap();
    if (destinationRegion != null)
      data['destination_region'] = destinationRegion;
    if (originRegion != null) data['origin_region'] = originRegion;
    if (tripNumber != null) data['trip_number'] = tripNumber;
    if (chainId != null) data['chain_id'] = chainId;

    if (data.isNotEmpty) {
      await supabase
          .from('trips')
          .update(data)
          .eq('id', tripId)
          .eq('user_id', uid);
    }
  }

  Future<void> deleteTrip({required String uid, required String tripId}) async {
    final supabase = ref.read(supabaseProvider);

    // Delete trip points first
    await supabase
        .from('trip_points')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', uid);

    // Delete trip summary
    await supabase.from('trips').delete().eq('id', tripId).eq('user_id', uid);
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

    if (mode != null) data['mode'] = mode.toString();
    if (purpose != null) data['purpose'] = purpose.toString();
    if (companions != null) data['companions'] = companions.toMap();
    if (destinationRegion != null)
      data['destination_region'] = destinationRegion;
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

  Future<void> batchDeleteTrips({
    required String uid,
    required List<String> tripIds,
  }) async {
    final supabase = ref.read(supabaseProvider);

    // Delete trip points first
    await supabase
        .from('trip_points')
        .delete()
        .inFilter('trip_id', tripIds)
        .eq('user_id', uid);

    // Delete trip summaries
    await supabase
        .from('trips')
        .delete()
        .inFilter('id', tripIds)
        .eq('user_id', uid);
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref),
);
