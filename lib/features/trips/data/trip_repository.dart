import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../domain/trip_models.dart';

class TripRepository {
  final Ref ref;
  TripRepository(this.ref);

  CollectionReference<Map<String, dynamic>> _tripsCol(String uid) => ref
      .read(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('trips');

  Future<String> startTrip({
    required String uid,
    TripMode mode = TripMode.unknown,
    TripPurpose purpose = TripPurpose.unknown,
    Companions companions = const Companions(),
    String? destinationRegion,
    String? originRegion,
    String? tripNumber,
    String? chainId,
  }) async {
    final now = DateTime.now();
    final doc = await _tripsCol(uid).add(TripSummary(
      id: 'tmp',
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
    ).toMap());
    return doc.id;
  }

  Future<void> appendPoints({required String uid, required String tripId, required List<TripPoint> points}) async {
    if (points.isEmpty) return;
    final batch = ref.read(firestoreProvider).batch();
    final coll = _tripsCol(uid).doc(tripId).collection('points');
    for (final p in points) {
      batch.set(coll.doc(), p.toMap());
    }
    await batch.commit();
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
  }) async {
    final data = <String, dynamic>{};
    if (distanceMeters != null) data['distanceMeters'] = distanceMeters;
    if (endedAt != null) data['endedAt'] = Timestamp.fromDate(endedAt);
    if (mode != null) data['mode'] = mode.name;
    if (purpose != null) data['purpose'] = purpose.name;
    if (companions != null) data['companions'] = companions.toMap();
    if (isRecurring != null) data['isRecurring'] = isRecurring;
    if (destinationRegion != null) data['destinationRegion'] = destinationRegion;
    if (originRegion != null) data['originRegion'] = originRegion;
    if (tripNumber != null) data['tripNumber'] = tripNumber;
    if (chainId != null) data['chainId'] = chainId;
    await _tripsCol(uid).doc(tripId).update(data);
  }

  Future<void> deleteTrip({required String uid, required String tripId}) async {
    final fs = ref.read(firestoreProvider);
    final tripDoc = _tripsCol(uid).doc(tripId);
    // Delete points subcollection in batches
    final points = await tripDoc.collection('points').limit(500).get();
    for (final doc in points.docs) {
      await doc.reference.delete();
    }
    await tripDoc.delete();
  }

  Stream<List<TripSummary>> watchRecentTrips(String uid, {int limit = 50}) {
    return _tripsCol(uid)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(TripSummary.fromDoc).toList());
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) => TripRepository(ref));




