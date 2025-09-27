import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../common/providers.dart';
import '../domain/itinerary_models.dart';

class ItineraryRepository {
  final Ref ref;
  ItineraryRepository(this.ref);

  CollectionReference<Map<String, dynamic>> _itinerariesCol(String uid) => ref
      .read(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('itineraries');

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
    final estimatedDuration = items.fold(0, (sum, item) => sum + item.estimatedDuration);
    
    final itinerary = TripItinerary(
      id: 'temp',
      tripId: tripId,
      userId: uid,
      title: title,
      description: description,
      createdAt: now,
      items: items,
      isCompleted: false,
      totalDistance: totalDistance,
      estimatedDuration: estimatedDuration,
    );

    final doc = await _itinerariesCol(uid).add(itinerary.toMap());
    return doc.id;
  }

  /// Get user's itineraries
  Stream<List<TripItinerary>> getUserItineraries(String uid) {
    return _itinerariesCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TripItinerary.fromMap(data);
      }).toList();
    });
  }

  /// Get itinerary by ID
  Future<TripItinerary?> getItinerary(String uid, String itineraryId) async {
    final doc = await _itinerariesCol(uid).doc(itineraryId).get();
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    data['id'] = doc.id;
    return TripItinerary.fromMap(data);
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
      data['totalDistance'] = _calculateTotalDistance(items);
      data['estimatedDuration'] = items.fold(0, (sum, item) => sum + item.estimatedDuration);
    }
    if (isCompleted != null) data['isCompleted'] = isCompleted;
    
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    
    await _itinerariesCol(uid).doc(itineraryId).update(data);
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
    
    final updatedItems = itinerary.items.where((item) => item.id != itemId).toList();
    
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
    await _itinerariesCol(uid).doc(itineraryId).delete();
  }

  /// Get itineraries for a specific trip
  Stream<List<TripItinerary>> getTripItineraries(String uid, String tripId) {
    return _itinerariesCol(uid)
        .where('tripId', isEqualTo: tripId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TripItinerary.fromMap(data);
      }).toList();
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
        current.latitude, current.longitude,
        next.latitude, next.longitude,
      );
    }
    
    return totalDistance;
  }
}

final itineraryRepositoryProvider = Provider<ItineraryRepository>((ref) => ItineraryRepository(ref));
