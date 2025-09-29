import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceSearchService {
  // For now, we'll use a simple fallback without Google Maps API
  // In production, you would add your Google Maps API key here
  static const String _apiKey =
      'YOUR_GOOGLE_MAPS_API_KEY'; // Add your API key here

  static Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    // For now, return a simple fallback result
    // In production, implement Google Places API integration
    return [
      PlaceSearchResult(
        placeId: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
        name: query,
        formattedAddress: query,
        latitude: 0.0, // Will be filled by user
        longitude: 0.0, // Will be filled by user
      ),
    ];
  }

  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // For now, return null as we're using fallback
    return null;
  }
}

class PlaceSearchResult {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceSearchResult(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
    );
  }
}

class PlaceDetails {
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceDetails(
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
    );
  }
}
