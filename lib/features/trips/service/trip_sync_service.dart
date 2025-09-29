import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../data/pending_trip_queue.dart';
import '../data/supabase_trip_repository.dart';

class TripSyncService {
  final Ref ref;
  final PendingTripQueue _queue;

  TripSyncService(this.ref, this._queue);

  Future<void> syncPending() async {
    final items = await _queue.peekAll();
    if (items.isEmpty) return;
    final repo = ref.read(supabaseTripRepositoryProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final List<int> deleted = [];
    for (final row in items) {
      try {
        final payload =
            jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        await repo.saveTrip(
          userId: user.id,
          startLocation: Map<String, double>.from(
            payload['start_location'] as Map,
          ),
          endLocation: Map<String, double>.from(payload['end_location'] as Map),
          distanceKm: (payload['distance_km'] as num).toDouble(),
          durationMin: (payload['duration_min'] as num).toInt(),
          mode: payload['mode'] as String? ?? 'unknown',
          purpose: payload['purpose'] as String? ?? 'unknown',
          companions: payload['companions'] as Map<String, dynamic>?,
          notes: payload['notes'] as String?,
          tripNumber: payload['trip_number'] as String?,
          chainId: payload['chain_id'] as String?,
          originRegion: payload['origin_region'] as String?,
          destinationRegion: payload['destination_region'] as String?,
          isRecurring: (payload['is_recurring'] as bool?) ?? false,
        );
        deleted.add(row['id'] as int);
      } catch (_) {
        // Leave in queue to retry later
      }
    }
    await _queue.deleteByIds(deleted);
  }
}

final pendingTripQueueProvider = Provider<PendingTripQueue>(
  (ref) => PendingTripQueue(),
);

final tripSyncServiceProvider = Provider<TripSyncService>((ref) {
  return TripSyncService(ref, ref.read(pendingTripQueueProvider));
});
