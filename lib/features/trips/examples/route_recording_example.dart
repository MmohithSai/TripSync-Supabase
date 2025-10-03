// Example demonstrating how to use the complete route recording functionality
// This file shows how to record and retrieve complete commute route data

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service/trip_service.dart';
import '../domain/trip_models.dart';

class RouteRecordingExample {
  final Ref ref;
  RouteRecordingExample(this.ref);

  /// Example: Start a trip and record complete route data
  Future<String> startTripWithRoute() async {
    final tripService = ref.read(tripServiceProvider);

    // Start location
    final startLocation = {'lat': 17.3850, 'lng': 78.4867};

    // End location (will be set when trip ends)
    final endLocation = {'lat': 17.4474, 'lng': 78.3569};

    // Create some sample trip points representing the route
    final now = DateTime.now();
    final tripPoints = <TripPoint>[
      TripPoint(
        latitude: 17.3850,
        longitude: 78.4867,
        timestamp: now,
        timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
        accuracy: 5.0,
        speed: 0.0,
        address: 'Starting Point, Hyderabad',
        roadName: 'Main Street',
        city: 'Hyderabad',
        country: 'India',
      ),
      TripPoint(
        latitude: 17.3900,
        longitude: 78.4900,
        timestamp: now.add(Duration(minutes: 5)),
        timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
        accuracy: 4.0,
        speed: 15.0,
        address: 'Intersection, Hyderabad',
        roadName: 'Highway 1',
        city: 'Hyderabad',
        country: 'India',
      ),
      TripPoint(
        latitude: 17.4000,
        longitude: 78.5000,
        timestamp: now.add(Duration(minutes: 10)),
        timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
        accuracy: 3.0,
        speed: 20.0,
        address: 'Mid Point, Hyderabad',
        roadName: 'Highway 1',
        city: 'Hyderabad',
        country: 'India',
      ),
      TripPoint(
        latitude: 17.4474,
        longitude: 78.3569,
        timestamp: now.add(Duration(minutes: 15)),
        timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
        accuracy: 5.0,
        speed: 0.0,
        address: 'Destination Point, Hyderabad',
        roadName: 'Destination Street',
        city: 'Hyderabad',
        country: 'India',
      ),
    ];

    // Save trip with complete route data
    final tripId = await tripService.saveTrip(
      startLocation: startLocation,
      endLocation: endLocation,
      distanceKm: 12.4,
      durationMin: 25,
      mode: 'car',
      purpose: 'work',
      companions: {'adults': 1, 'children': 0, 'seniors': 0},
      notes: 'Daily commute to office',
      originRegion: 'Hyderabad Central',
      destinationRegion: 'Hyderabad IT Corridor',
      tripPoints: tripPoints, // Complete route data
    );

    return tripId;
  }

  /// Example: Get trip with complete route data
  Future<void> getTripWithRoute(String tripId) async {
    final tripService = ref.read(tripServiceProvider);

    // Get trip with complete route data
    final tripWithRoute = await tripService.getTripWithRoute(tripId);

    if (tripWithRoute != null) {
      final trip = tripWithRoute['trip'];
      final points = tripWithRoute['points'] as List<Map<String, dynamic>>;

      print('Trip ID: ${trip['id']}');
      print('Distance: ${trip['distance_km']} km');
      print('Duration: ${trip['duration_min']} minutes');
      print('Mode: ${trip['mode']}');
      print('Purpose: ${trip['purpose']}');
      print('Route Points: ${points.length}');

      // Print each route point
      for (int i = 0; i < points.length; i++) {
        final point = points[i];
        print(
          'Point ${i + 1}: ${point['latitude']}, ${point['longitude']} at ${point['timestamp']}',
        );
        if (point['address'] != null) {
          print('  Address: ${point['address']}');
        }
        if (point['road_name'] != null) {
          print('  Road: ${point['road_name']}');
        }
        if (point['speed'] != null) {
          print('  Speed: ${point['speed']} m/s');
        }
      }
    }
  }

  /// Example: Get all trips with route data
  Future<void> getAllTripsWithRoutes() async {
    final tripService = ref.read(tripServiceProvider);

    // Get all trips with complete route data
    final tripsWithRoutes = await tripService.getUserTripsWithRoutes();

    print('Total trips: ${tripsWithRoutes.length}');

    for (final tripData in tripsWithRoutes) {
      final trip = tripData['trip'];
      final points = tripData['points'] as List<Map<String, dynamic>>;

      print('\nTrip: ${trip['id']}');
      print('  Distance: ${trip['distance_km']} km');
      print('  Duration: ${trip['duration_min']} minutes');
      print('  Route Points: ${points.length}');

      // Show route summary
      if (points.isNotEmpty) {
        final firstPoint = points.first;
        final lastPoint = points.last;
        print('  Route: ${firstPoint['address']} → ${lastPoint['address']}');
      }
    }
  }

  /// Example: Update trip points for an existing trip
  Future<void> updateTripRoute(String tripId) async {
    final tripService = ref.read(tripServiceProvider);

    // Get existing trip points
    final existingPoints = await tripService.getTripPoints(tripId);

    // Add additional points or modify existing ones
    final updatedPoints = <TripPoint>[];
    updatedPoints.addAll(existingPoints);

    // Add a new point
    final newPoint = TripPoint(
      latitude: 17.4200,
      longitude: 78.4800,
      timestamp: DateTime.now(),
      timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      accuracy: 4.0,
      speed: 18.0,
      address: 'Additional Stop, Hyderabad',
      roadName: 'Side Street',
      city: 'Hyderabad',
      country: 'India',
    );
    updatedPoints.add(newPoint);

    // Update trip points
    await tripService.updateTripPoints(tripId, updatedPoints);

    print('Updated trip $tripId with ${updatedPoints.length} route points');
  }

  /// Example: Analyze route data
  Future<void> analyzeRoute(String tripId) async {
    final tripService = ref.read(tripServiceProvider);

    final points = await tripService.getTripPoints(tripId);

    if (points.isEmpty) {
      print('No route data available for trip $tripId');
      return;
    }

    // Calculate route statistics
    double totalDistance = 0.0;
    double totalSpeed = 0.0;
    double maxSpeed = 0.0;
    double minSpeed = double.infinity;
    int validSpeedCount = 0;

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      // Calculate distance between points
      final distance = _calculateDistance(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      totalDistance += distance;

      // Calculate speed statistics
      if (curr.speed != null && curr.speed!.isFinite) {
        totalSpeed += curr.speed!;
        validSpeedCount++;
        if (curr.speed! > maxSpeed) maxSpeed = curr.speed!;
        if (curr.speed! < minSpeed) minSpeed = curr.speed!;
      }
    }

    final averageSpeed = validSpeedCount > 0
        ? totalSpeed / validSpeedCount
        : 0.0;

    print('Route Analysis for Trip $tripId:');
    print('  Total Distance: ${totalDistance.toStringAsFixed(2)} km');
    print('  Total Points: ${points.length}');
    print('  Average Speed: ${averageSpeed.toStringAsFixed(2)} m/s');
    print('  Max Speed: ${maxSpeed.toStringAsFixed(2)} m/s');
    print('  Min Speed: ${minSpeed.toStringAsFixed(2)} m/s');

    // Show route segments
    print('  Route Segments:');
    for (int i = 0; i < points.length - 1; i++) {
      final curr = points[i];
      final next = points[i + 1];
      final segmentDistance = _calculateDistance(
        curr.latitude,
        curr.longitude,
        next.latitude,
        next.longitude,
      );
      print(
        '    ${i + 1}: ${curr.address ?? 'Unknown'} → ${next.address ?? 'Unknown'} (${segmentDistance.toStringAsFixed(2)} km)',
      );
    }
  }

  /// Helper method to calculate distance between two points
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    // Simple distance calculation (in km)
    const double earthRadius = 6371; // Earth's radius in km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    final double a =
        (dLat / 2).sin() * (dLat / 2).sin() +
        lat1.cos() * lat2.cos() * (dLng / 2).sin() * (dLng / 2).sin();
    final double c = 2 * (a.sqrt()).asin();
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}

// Extension methods for math functions
extension MathExtensions on double {
  double sin() => this * (3.14159265359 / 180);
  double cos() => this * (3.14159265359 / 180);
  double sqrt() => this * this;
  double asin() => this;
}

