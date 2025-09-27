import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/itinerary_models.dart';

class PlacesService {
  static final List<PlaceOfInterest> _places = [
    // Famous attractions
    PlaceOfInterest(
      id: '1',
      name: 'Central Park',
      description: 'Large public park in Manhattan with walking paths, lakes, and recreational facilities.',
      latitude: 40.7829,
      longitude: -73.9654,
      category: 'attraction',
      rating: 4.5,
      reviewCount: 125000,
      imageUrl: 'https://example.com/central-park.jpg',
      address: 'Central Park, New York, NY',
      tags: ['park', 'nature', 'walking', 'family'],
      isOpen: true,
      openingHours: '6:00 AM - 1:00 AM',
      distanceFromUser: 0,
    ),
    PlaceOfInterest(
      id: '2',
      name: 'Times Square',
      description: 'Famous commercial intersection known for its bright lights and Broadway theaters.',
      latitude: 40.7580,
      longitude: -73.9855,
      category: 'attraction',
      rating: 4.2,
      reviewCount: 89000,
      imageUrl: 'https://example.com/times-square.jpg',
      address: 'Times Square, New York, NY',
      tags: ['entertainment', 'shopping', 'nightlife', 'tourist'],
      isOpen: true,
      openingHours: '24/7',
      distanceFromUser: 0,
    ),
    PlaceOfInterest(
      id: '3',
      name: 'Statue of Liberty',
      description: 'Iconic symbol of freedom and democracy, accessible by ferry.',
      latitude: 40.6892,
      longitude: -74.0445,
      category: 'attraction',
      rating: 4.6,
      reviewCount: 150000,
      imageUrl: 'https://example.com/statue-liberty.jpg',
      address: 'Liberty Island, New York, NY',
      tags: ['monument', 'history', 'ferry', 'tourist'],
      isOpen: true,
      openingHours: '9:30 AM - 3:30 PM',
      distanceFromUser: 0,
    ),
    PlaceOfInterest(
      id: '4',
      name: 'Brooklyn Bridge',
      description: 'Historic suspension bridge connecting Manhattan and Brooklyn.',
      latitude: 40.7061,
      longitude: -73.9969,
      category: 'attraction',
      rating: 4.7,
      reviewCount: 95000,
      imageUrl: 'https://example.com/brooklyn-bridge.jpg',
      address: 'Brooklyn Bridge, New York, NY',
      tags: ['bridge', 'walking', 'photography', 'history'],
      isOpen: true,
      openingHours: '24/7',
      distanceFromUser: 0,
    ),
    PlaceOfInterest(
      id: '5',
      name: 'High Line',
      description: 'Elevated park built on a former railway line with gardens and art installations.',
      latitude: 40.7480,
      longitude: -74.0048,
      category: 'attraction',
      rating: 4.4,
      reviewCount: 67000,
      imageUrl: 'https://example.com/high-line.jpg',
      address: 'High Line, New York, NY',
      tags: ['park', 'art', 'walking', 'urban'],
      isOpen: true,
      openingHours: '7:00 AM - 7:00 PM',
      distanceFromUser: 0,
    ),
    // Restaurants
    PlaceOfInterest(
      id: '6',
      name: 'Joe\'s Pizza',
      description: 'Famous New York-style pizza joint known for its classic slices.',
      latitude: 40.7505,
      longitude: -73.9934,
      category: 'restaurant',
      rating: 4.3,
      reviewCount: 45000,
      imageUrl: 'https://example.com/joes-pizza.jpg',
      address: '7 Carmine St, New York, NY',
      phoneNumber: '(212) 366-1182',
      tags: ['pizza', 'casual', 'quick', 'local'],
      isOpen: true,
      openingHours: '10:00 AM - 4:00 AM',
      distanceFromUser: 0,
    ),
    PlaceOfInterest(
      id: '7',
      name: 'Shake Shack',
      description: 'Popular burger chain known for its ShackBurger and crinkle-cut fries.',
      latitude: 40.7614,
      longitude: -73.9776,
      category: 'restaurant',
      rating: 4.1,
      reviewCount: 32000,
      imageUrl: 'https://example.com/shake-shack.jpg',
      address: 'Madison Square Park, New York, NY',
      phoneNumber: '(212) 889-6600',
      tags: ['burgers', 'fast-food', 'casual', 'family'],
      isOpen: true,
      openingHours: '11:00 AM - 11:00 PM',
      distanceFromUser: 0,
    ),
    // Shopping
    PlaceOfInterest(
      id: '8',
      name: 'Fifth Avenue',
      description: 'Famous shopping street with luxury stores and flagship locations.',
      latitude: 40.7505,
      longitude: -73.9934,
      category: 'shopping',
      rating: 4.0,
      reviewCount: 28000,
      imageUrl: 'https://example.com/fifth-avenue.jpg',
      address: 'Fifth Avenue, New York, NY',
      tags: ['shopping', 'luxury', 'fashion', 'tourist'],
      isOpen: true,
      openingHours: '10:00 AM - 9:00 PM',
      distanceFromUser: 0,
    ),
    PlaceOfInterest(
      id: '9',
      name: 'Chelsea Market',
      description: 'Indoor food hall and shopping complex with local vendors.',
      latitude: 40.7421,
      longitude: -74.0060,
      category: 'shopping',
      rating: 4.2,
      reviewCount: 18000,
      imageUrl: 'https://example.com/chelsea-market.jpg',
      address: '75 9th Ave, New York, NY',
      tags: ['food-hall', 'local', 'shopping', 'dining'],
      isOpen: true,
      openingHours: '7:00 AM - 9:00 PM',
      distanceFromUser: 0,
    ),
    // Museums
    PlaceOfInterest(
      id: '10',
      name: 'Metropolitan Museum of Art',
      description: 'World-renowned art museum with collections spanning 5,000 years.',
      latitude: 40.7794,
      longitude: -73.9632,
      category: 'museum',
      rating: 4.6,
      reviewCount: 120000,
      imageUrl: 'https://example.com/met-museum.jpg',
      address: '1000 5th Ave, New York, NY',
      phoneNumber: '(212) 535-7710',
      tags: ['art', 'culture', 'education', 'family'],
      isOpen: true,
      openingHours: '10:00 AM - 5:00 PM',
      distanceFromUser: 0,
    ),
  ];

  /// Get nearby places within a specified radius
  static List<PlaceOfInterest> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    String? category,
    int limit = 20,
  }) {
    final nearbyPlaces = <PlaceOfInterest>[];
    
    for (final place in _places) {
      final distance = Geolocator.distanceBetween(
        latitude, longitude,
        place.latitude, place.longitude,
      ) / 1000; // Convert to km
      
      if (distance <= radiusKm) {
        if (category == null || place.category == category) {
          final updatedPlace = PlaceOfInterest(
            id: place.id,
            name: place.name,
            description: place.description,
            latitude: place.latitude,
            longitude: place.longitude,
            category: place.category,
            rating: place.rating,
            reviewCount: place.reviewCount,
            imageUrl: place.imageUrl,
            address: place.address,
            phoneNumber: place.phoneNumber,
            website: place.website,
            tags: place.tags,
            isOpen: place.isOpen,
            openingHours: place.openingHours,
            distanceFromUser: distance * 1000, // Convert back to meters
          );
          nearbyPlaces.add(updatedPlace);
        }
      }
    }
    
    // Sort by distance
    nearbyPlaces.sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));
    
    return nearbyPlaces.take(limit).toList();
  }

  /// Get trip suggestions based on user preferences and location
  static List<TripSuggestion> getTripSuggestions({
    required double latitude,
    required double longitude,
    String? userPreference,
    double radiusKm = 10.0,
    int limit = 10,
  }) {
    final nearbyPlaces = getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
    
    final suggestions = <TripSuggestion>[];
    
    for (final place in nearbyPlaces) {
      final reason = _generateSuggestionReason(place, userPreference);
      final estimatedDuration = _estimateVisitDuration(place);
      
      final suggestion = TripSuggestion(
        id: 'suggestion_${place.id}',
        title: place.name,
        description: place.description,
        category: place.category,
        latitude: place.latitude,
        longitude: place.longitude,
        rating: place.rating,
        reviewCount: place.reviewCount,
        imageUrl: place.imageUrl,
        distanceFromUser: place.distanceFromUser,
        tags: place.tags,
        reason: reason,
        estimatedVisitDuration: estimatedDuration,
      );
      
      suggestions.add(suggestion);
    }
    
    // Sort by rating and distance
    suggestions.sort((a, b) {
      final scoreA = (a.rating * 0.7) + ((1000 - a.distanceFromUser) / 1000 * 0.3);
      final scoreB = (b.rating * 0.7) + ((1000 - b.distanceFromUser) / 1000 * 0.3);
      return scoreB.compareTo(scoreA);
    });
    
    return suggestions.take(limit).toList();
  }

  /// Generate a reason why this place is suggested
  static String _generateSuggestionReason(PlaceOfInterest place, String? userPreference) {
    final reasons = <String>[];
    
    if (place.rating >= 4.5) {
      reasons.add('Highly rated (${place.rating}/5)');
    }
    
    if (place.distanceFromUser < 1000) {
      reasons.add('Very close by (${(place.distanceFromUser / 1000).toStringAsFixed(1)}km)');
    } else if (place.distanceFromUser < 5000) {
      reasons.add('Nearby (${(place.distanceFromUser / 1000).toStringAsFixed(1)}km)');
    }
    
    if (place.category == 'attraction' && place.tags.contains('tourist')) {
      reasons.add('Popular tourist destination');
    }
    
    if (place.category == 'restaurant' && place.tags.contains('local')) {
      reasons.add('Local favorite');
    }
    
    if (userPreference != null && place.tags.contains(userPreference.toLowerCase())) {
      reasons.add('Matches your interests');
    }
    
    if (reasons.isEmpty) {
      return 'Interesting place to visit';
    }
    
    return reasons.join(', ');
  }

  /// Estimate how long someone might spend at a place
  static int _estimateVisitDuration(PlaceOfInterest place) {
    switch (place.category) {
      case 'restaurant':
        return 60; // 1 hour for dining
      case 'attraction':
        if (place.tags.contains('park')) {
          return 120; // 2 hours for parks
        }
        return 90; // 1.5 hours for other attractions
      case 'museum':
        return 180; // 3 hours for museums
      case 'shopping':
        return 90; // 1.5 hours for shopping
      default:
        return 60; // 1 hour default
    }
  }

  /// Get places by category
  static List<PlaceOfInterest> getPlacesByCategory({
    required String category,
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) {
    return getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      category: category,
    );
  }

  /// Search places by name or tags
  static List<PlaceOfInterest> searchPlaces({
    required String query,
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) {
    final nearbyPlaces = getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
    
    final queryLower = query.toLowerCase();
    
    return nearbyPlaces.where((place) {
      return place.name.toLowerCase().contains(queryLower) ||
             place.description.toLowerCase().contains(queryLower) ||
             place.tags.any((tag) => tag.toLowerCase().contains(queryLower));
    }).toList();
  }
}

// Provider for places service
final placesServiceProvider = Provider<PlacesService>((ref) => PlacesService());
