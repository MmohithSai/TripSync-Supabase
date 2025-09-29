import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
// Supabase types are provided via providers; no direct import needed here

import '../../../common/providers.dart';
import '../domain/itinerary_models.dart';

class ItineraryRepository {
  final Ref ref;
  ItineraryRepository(this.ref);

  // Removed Firestore collection reference - now using Supabase

  /// Create a new itinerary
  Future<String> createItinerary({
    required String uid,
    required String tripId,
    required String title,
    required String description,
    required List<ItineraryItem> items,
  }) async {
    final now = DateTime.now();
    final totalDistance = _calculateTotalDistance(items);
    final estimatedDuration = items.fold(
      0,
      (sum, item) => sum + item.estimatedDuration,
    );

    // Build local object if needed later

    final supabase = ref.read(supabaseProvider);
    final response = await supabase
        .from('itineraries')
        .insert({
          'user_id': uid,
          'trip_id': tripId,
          'title': title,
          'description': description,
          'items': items.map((item) => item.toMap()).toList(),
          'created_at': now.toIso8601String(),
          'is_completed': false,
          'total_distance': totalDistance,
          'estimated_duration': estimatedDuration,
        })
        .select()
        .single();
    return response['id'] as String;
  }

  /// Get user's itineraries
  Stream<List<TripItinerary>> getUserItineraries(String uid) {
    final supabase = ref.read(supabaseProvider);
    return supabase
        .from('itineraries')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((item) => TripItinerary.fromMap(item)).toList();
        });
  }

  /// Get itinerary by ID
  Future<TripItinerary?> getItinerary(String uid, String itineraryId) async {
    final supabase = ref.read(supabaseProvider);
    final response = await supabase
        .from('itineraries')
        .select()
        .eq('id', itineraryId)
        .eq('user_id', uid)
        .maybeSingle();

    if (response == null) return null;
    return TripItinerary.fromMap(response);
  }

  /// Update itinerary
  Future<void> updateItinerary({
    required String uid,
    required String itineraryId,
    String? title,
    String? description,
    List<ItineraryItem>? items,
    bool? isCompleted,
  }) async {
    final data = <String, dynamic>{};

    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (items != null) {
      data['items'] = items.map((item) => item.toMap()).toList();
      data['total_distance'] = _calculateTotalDistance(items);
      data['estimated_duration'] = items.fold(
        0,
        (sum, item) => sum + item.estimatedDuration,
      );
    }
    if (isCompleted != null) data['is_completed'] = isCompleted;

    data['updated_at'] = DateTime.now().toIso8601String();

    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('itineraries')
        .update(data)
        .eq('id', itineraryId)
        .eq('user_id', uid);
  }

  /// Add item to itinerary
  Future<void> addItineraryItem({
    required String uid,
    required String itineraryId,
    required ItineraryItem item,
  }) async {
    final itinerary = await getItinerary(uid, itineraryId);
    if (itinerary == null) return;

    final updatedItems = List<ItineraryItem>.from(itinerary.items)..add(item);

    await updateItinerary(
      uid: uid,
      itineraryId: itineraryId,
      items: updatedItems,
    );
  }

  /// Remove item from itinerary
  Future<void> removeItineraryItem({
    required String uid,
    required String itineraryId,
    required String itemId,
  }) async {
    final itinerary = await getItinerary(uid, itineraryId);
    if (itinerary == null) return;

    final updatedItems = itinerary.items
        .where((item) => item.id != itemId)
        .toList();

    await updateItinerary(
      uid: uid,
      itineraryId: itineraryId,
      items: updatedItems,
    );
  }

  /// Mark itinerary item as completed
  Future<void> markItemCompleted({
    required String uid,
    required String itineraryId,
    required String itemId,
    required bool isCompleted,
  }) async {
    final itinerary = await getItinerary(uid, itineraryId);
    if (itinerary == null) return;

    final updatedItems = itinerary.items.map((item) {
      if (item.id == itemId) {
        return ItineraryItem(
          id: item.id,
          placeId: item.placeId,
          name: item.name,
          description: item.description,
          latitude: item.latitude,
          longitude: item.longitude,
          category: item.category,
          order: item.order,
          estimatedDuration: item.estimatedDuration,
          scheduledTime: item.scheduledTime,
          isCompleted: isCompleted,
          notes: item.notes,
          rating: item.rating,
          imageUrl: item.imageUrl,
        );
      }
      return item;
    }).toList();

    await updateItinerary(
      uid: uid,
      itineraryId: itineraryId,
      items: updatedItems,
    );
  }

  /// Delete itinerary
  Future<void> deleteItinerary({
    required String uid,
    required String itineraryId,
  }) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('itineraries')
        .delete()
        .eq('id', itineraryId)
        .eq('user_id', uid);
  }

  /// Get itineraries for a specific trip
  Stream<List<TripItinerary>> getTripItineraries(String uid, String tripId) {
    final supabase = ref.read(supabaseProvider);
    return supabase
        .from('itineraries')
        .stream(primaryKey: ['id'])
        // ignore: undefined_method
        .eq('user_id', uid)
        // ignore: undefined_method
        .eq('trip_id', tripId)
        // ignore: undefined_method
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((item) => TripItinerary.fromMap(item)).toList();
        });
  }

  /// Calculate total distance for itinerary items
  double _calculateTotalDistance(List<ItineraryItem> items) {
    if (items.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < items.length - 1; i++) {
      final current = items[i];
      final next = items[i + 1];

      totalDistance += Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        next.latitude,
        next.longitude,
      );
    }

    return totalDistance;
  }
}

final itineraryRepositoryProvider = Provider<ItineraryRepository>(
  (ref) => ItineraryRepository(ref),
);
