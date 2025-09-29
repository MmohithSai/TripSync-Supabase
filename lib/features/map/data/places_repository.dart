import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static SavedPlace fromSupabase(Map<String, dynamic> data) {
    return SavedPlace(
      id: data['id'] as String,
      label: data['name'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}

class PlacesRepository {
  final Ref ref;
  PlacesRepository(this.ref);

  Future<void> addPlace({
    required String uid,
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('saved_places').insert({
      'user_id': uid,
      'name': label,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<void> deletePlace({
    required String uid,
    required String placeId,
  }) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('saved_places')
        .delete()
        .eq('id', placeId)
        .eq('user_id', uid);
  }

  Stream<List<SavedPlace>> watchPlaces(String uid) {
    final supabase = ref.read(supabaseProvider);
    return supabase
        .from('saved_places')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((data) => data.map(SavedPlace.fromSupabase).toList());
  }
}

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref),
);
