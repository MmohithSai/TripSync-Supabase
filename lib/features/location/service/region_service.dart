import 'package:geolocator/geolocator.dart';

class RegionService {
  // Define region boundaries (simplified grid-based system)
  static const Map<String, RegionBoundary> _regions = {
    'Downtown': RegionBoundary(
      name: 'Downtown',
      minLat: 40.7,
      maxLat: 40.8,
      minLng: -74.0,
      maxLng: -73.9,
    ),
    'Midtown': RegionBoundary(
      name: 'Midtown',
      minLat: 40.6,
      maxLat: 40.7,
      minLng: -74.0,
      maxLng: -73.9,
    ),
    'Uptown': RegionBoundary(
      name: 'Uptown',
      minLat: 40.5,
      maxLat: 40.6,
      minLng: -74.0,
      maxLng: -73.9,
    ),
    'Brooklyn': RegionBoundary(
      name: 'Brooklyn',
      minLat: 40.6,
      maxLat: 40.7,
      minLng: -74.1,
      maxLng: -74.0,
    ),
    'Queens': RegionBoundary(
      name: 'Queens',
      minLat: 40.7,
      maxLat: 40.8,
      minLng: -74.1,
      maxLng: -74.0,
    ),
    'Bronx': RegionBoundary(
      name: 'Bronx',
      minLat: 40.8,
      maxLat: 40.9,
      minLng: -74.0,
      maxLng: -73.9,
    ),
  };

  /// Determine the region for a given latitude and longitude
  static String? getRegionForLocation(double latitude, double longitude) {
    for (final region in _regions.values) {
      if (region.contains(latitude, longitude)) {
        return region.name;
      }
    }
    return null; // No region found
  }

  /// Get all available regions
  static List<String> getAllRegions() {
    return _regions.keys.toList();
  }

  /// Get region boundary information
  static RegionBoundary? getRegionBoundary(String regionName) {
    return _regions[regionName];
  }

  /// Calculate distance to nearest region center
  static double? getDistanceToRegion(double latitude, double longitude, String regionName) {
    final region = _regions[regionName];
    if (region == null) return null;
    
    final centerLat = (region.minLat + region.maxLat) / 2;
    final centerLng = (region.minLng + region.maxLng) / 2;
    
    return Geolocator.distanceBetween(
      latitude, longitude,
      centerLat, centerLng,
    );
  }

  /// Find the nearest region to a location
  static String? getNearestRegion(double latitude, double longitude) {
    String? nearestRegion;
    double? minDistance;
    
    for (final regionName in _regions.keys) {
      final distance = getDistanceToRegion(latitude, longitude, regionName);
      if (distance != null && (minDistance == null || distance < minDistance)) {
        minDistance = distance;
        nearestRegion = regionName;
      }
    }
    
    return nearestRegion;
  }
}

class RegionBoundary {
  final String name;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const RegionBoundary({
    required this.name,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  bool contains(double latitude, double longitude) {
    return latitude >= minLat && 
           latitude <= maxLat && 
           longitude >= minLng && 
           longitude <= maxLng;
  }

  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;
}


