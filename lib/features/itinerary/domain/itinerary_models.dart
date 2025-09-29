// Removed Firebase import - now using Supabase

class PlaceOfInterest {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String category; // restaurant, attraction, shopping, etc.
  final double rating;
  final int reviewCount;
  final String? imageUrl;
  final String? address;
  final String? phoneNumber;
  final String? website;
  final List<String> tags;
  final bool isOpen;
  final String? openingHours;
  final double distanceFromUser; // in meters

  const PlaceOfInterest({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.rating,
    required this.reviewCount,
    this.imageUrl,
    this.address,
    this.phoneNumber,
    this.website,
    required this.tags,
    required this.isOpen,
    this.openingHours,
    required this.distanceFromUser,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
    'rating': rating,
    'reviewCount': reviewCount,
    'imageUrl': imageUrl,
    'address': address,
    'phoneNumber': phoneNumber,
    'website': website,
    'tags': tags,
    'isOpen': isOpen,
    'openingHours': openingHours,
    'distanceFromUser': distanceFromUser,
  };

  static PlaceOfInterest fromMap(Map<String, dynamic> map) {
    return PlaceOfInterest(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      category: map['category'] as String,
      rating: (map['rating'] as num).toDouble(),
      reviewCount: map['reviewCount'] as int,
      imageUrl: map['imageUrl'] as String?,
      address: map['address'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      website: map['website'] as String?,
      tags: List<String>.from(map['tags'] ?? []),
      isOpen: map['isOpen'] as bool,
      openingHours: map['openingHours'] as String?,
      distanceFromUser: (map['distanceFromUser'] as num).toDouble(),
    );
  }
}

class TripItinerary {
  final String id;
  final String tripId;
  final String userId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ItineraryItem> items;
  final bool isCompleted;
  final double totalDistance;
  final int estimatedDuration; // in minutes

  const TripItinerary({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.updatedAt,
    required this.items,
    required this.isCompleted,
    required this.totalDistance,
    required this.estimatedDuration,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'trip_id': tripId,
    'user_id': userId,
    'title': title,
    'description': description,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'items': items.map((item) => item.toMap()).toList(),
    'is_completed': isCompleted,
    'total_distance': totalDistance,
    'estimated_duration': estimatedDuration,
  };

  static TripItinerary fromMap(Map<String, dynamic> map) {
    return TripItinerary(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      items: (map['items'] as List<dynamic>)
          .map((item) => ItineraryItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      isCompleted: map['is_completed'] as bool,
      totalDistance: (map['total_distance'] as num).toDouble(),
      estimatedDuration: map['estimated_duration'] as int,
    );
  }
}

class ItineraryItem {
  final String id;
  final String placeId;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String category;
  final int order; // sequence in itinerary
  final int estimatedDuration; // in minutes
  final DateTime? scheduledTime;
  final bool isCompleted;
  final String? notes;
  final double rating;
  final String? imageUrl;

  const ItineraryItem({
    required this.id,
    required this.placeId,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.order,
    required this.estimatedDuration,
    this.scheduledTime,
    required this.isCompleted,
    this.notes,
    required this.rating,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'placeId': placeId,
    'name': name,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
    'order': order,
    'estimatedDuration': estimatedDuration,
    'scheduledTime': scheduledTime?.toIso8601String(),
    'isCompleted': isCompleted,
    'notes': notes,
    'rating': rating,
    'imageUrl': imageUrl,
  };

  static ItineraryItem fromMap(Map<String, dynamic> map) {
    return ItineraryItem(
      id: map['id'] as String,
      placeId: map['placeId'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      category: map['category'] as String,
      order: map['order'] as int,
      estimatedDuration: map['estimatedDuration'] as int,
      scheduledTime: map['scheduledTime'] != null
          ? DateTime.parse(map['scheduledTime'])
          : null,
      isCompleted: map['isCompleted'] as bool,
      notes: map['notes'] as String?,
      rating: (map['rating'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String?,
    );
  }
}

class TripSuggestion {
  final String id;
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String? imageUrl;
  final double distanceFromUser;
  final List<String> tags;
  final String reason; // why this suggestion is relevant
  final int estimatedVisitDuration; // in minutes

  const TripSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    this.imageUrl,
    required this.distanceFromUser,
    required this.tags,
    required this.reason,
    required this.estimatedVisitDuration,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'latitude': latitude,
    'longitude': longitude,
    'rating': rating,
    'reviewCount': reviewCount,
    'imageUrl': imageUrl,
    'distanceFromUser': distanceFromUser,
    'tags': tags,
    'reason': reason,
    'estimatedVisitDuration': estimatedVisitDuration,
  };

  static TripSuggestion fromMap(Map<String, dynamic> map) {
    return TripSuggestion(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      rating: (map['rating'] as num).toDouble(),
      reviewCount: map['reviewCount'] as int,
      imageUrl: map['imageUrl'] as String?,
      distanceFromUser: (map['distanceFromUser'] as num).toDouble(),
      tags: List<String>.from(map['tags'] ?? []),
      reason: map['reason'] as String,
      estimatedVisitDuration: map['estimatedVisitDuration'] as int,
    );
  }
}
