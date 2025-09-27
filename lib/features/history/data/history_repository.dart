import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../../trips/domain/trip_models.dart';

class HistoryRepository {
  final Ref ref;
  HistoryRepository(this.ref);

  CollectionReference<Map<String, dynamic>> _tripsCol(String uid) => ref
      .read(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('trips');

  Stream<List<TripSummary>> getTrips({
    required String uid,
    DateTime? startDate,
    DateTime? endDate,
    TripMode? mode,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _tripsCol(uid)
        .orderBy('startedAt', descending: true)
        .limit(limit);

    if (startDate != null) {
      query = query.where('startedAt', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('startedAt', isLessThanOrEqualTo: endDate);
    }
    if (mode != null) {
      query = query.where('mode', isEqualTo: mode.toString());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TripSummary.fromMap(data, doc.id);
      }).toList();
    });
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
    final data = <String, dynamic>{};
    
    if (mode != null) data['mode'] = mode.toString();
    if (purpose != null) data['purpose'] = purpose.toString();
    if (companions != null) data['companions'] = companions.toMap();
    if (destinationRegion != null) data['destinationRegion'] = destinationRegion;
    if (originRegion != null) data['originRegion'] = originRegion;
    if (tripNumber != null) data['tripNumber'] = tripNumber;
    if (chainId != null) data['chainId'] = chainId;

    if (data.isNotEmpty) {
      await _tripsCol(uid).doc(tripId).update(data);
    }
  }

  Future<void> deleteTrip({
    required String uid,
    required String tripId,
  }) async {
    // Delete trip summary
    await _tripsCol(uid).doc(tripId).delete();
    
    // Delete trip points
    final pointsSnapshot = await _tripsCol(uid)
        .doc(tripId)
        .collection('points')
        .get();
    
    final batch = ref.read(firestoreProvider).batch();
    for (final doc in pointsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
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
    final batch = ref.read(firestoreProvider).batch();
    
    for (final tripId in tripIds) {
      final data = <String, dynamic>{};
      
      if (mode != null) data['mode'] = mode.toString();
      if (purpose != null) data['purpose'] = purpose.toString();
      if (companions != null) data['companions'] = companions.toMap();
      if (destinationRegion != null) data['destinationRegion'] = destinationRegion;
      if (originRegion != null) data['originRegion'] = originRegion;
      if (tripNumber != null) data['tripNumber'] = tripNumber;
      if (chainId != null) data['chainId'] = chainId;

      if (data.isNotEmpty) {
        batch.update(_tripsCol(uid).doc(tripId), data);
      }
    }
    
    await batch.commit();
  }

  Future<void> batchDeleteTrips({
    required String uid,
    required List<String> tripIds,
  }) async {
    final batch = ref.read(firestoreProvider).batch();
    
    for (final tripId in tripIds) {
      // Delete trip summary
      batch.delete(_tripsCol(uid).doc(tripId));
      
      // Note: Trip points will be deleted by Firestore rules or background cleanup
    }
    
    await batch.commit();
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository(ref));


