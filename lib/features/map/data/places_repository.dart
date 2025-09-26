import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';

class SavedPlace {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const SavedPlace({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt,
      };

  static SavedPlace fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final ts = d['createdAt'] as Timestamp?;
    return SavedPlace(
      id: doc.id,
      label: (d['label'] as String?) ?? 'Place',
      latitude: (d['latitude'] as num).toDouble(),
      longitude: (d['longitude'] as num).toDouble(),
      createdAt: ts?.toDate() ?? DateTime.now(),
    );
  }
}

class PlacesRepository {
  final Ref ref;
  PlacesRepository(this.ref);

  CollectionReference<Map<String, dynamic>> _col(String uid) => ref
      .read(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('places');

  Future<void> addPlace({
    required String uid,
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    await _col(uid).add({
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlace({required String uid, required String placeId}) async {
    await _col(uid).doc(placeId).delete();
  }

  Stream<List<SavedPlace>> watchPlaces(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(SavedPlace.fromDoc).toList());
  }
}

final placesRepositoryProvider = Provider<PlacesRepository>((ref) => PlacesRepository(ref));

