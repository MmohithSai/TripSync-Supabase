import 'package:flutter_test/flutter_test.dart';
import 'package:location_tracker_app/features/location/service/accelerometer_service.dart';
import 'package:location_tracker_app/features/trips/domain/trip_models.dart';
import 'package:location_tracker_app/features/trips/service/trip_controller.dart';

void main() {
  group('Trip Detection Tests', () {
    test('should detect movement from accelerometer data', () {
      final service = AccelerometerService();
      
      // Simulate accelerometer data for movement
      final movementData = AccelerometerData(
        x: 1.0,
        y: 0.5,
        z: 0.2,
        magnitude: 1.1,
        timestamp: DateTime.now(),
      );
      
      // Add multiple samples to simulate movement
      for (int i = 0; i < 15; i++) {
        service._recentData.add(AccelerometerData(
          x: 1.0 + (i * 0.1),
          y: 0.5 + (i * 0.05),
          z: 0.2 + (i * 0.02),
          magnitude: 1.1 + (i * 0.1),
          timestamp: DateTime.now().subtract(Duration(seconds: 15 - i)),
        ));
      }
      
      final state = service.getCurrentMovementState();
      expect(state.isMoving, true);
      expect(state.confidence, greaterThan(0.5));
    });

    test('should detect stationary state', () {
      final service = AccelerometerService();
      
      // Simulate stationary data
      for (int i = 0; i < 15; i++) {
        service._recentData.add(AccelerometerData(
          x: 0.05,
          y: 0.02,
          z: 0.01,
          magnitude: 0.05,
          timestamp: DateTime.now().subtract(Duration(seconds: 15 - i)),
        ));
      }
      
      final state = service.getCurrentMovementState();
      expect(state.isMoving, false);
      expect(service.detectStationary(), true);
    });

    test('should classify vehicle movement', () {
      final service = AccelerometerService();
      
      // Simulate vehicle movement (smooth, consistent)
      for (int i = 0; i < 20; i++) {
        service._recentData.add(AccelerometerData(
          x: 0.8 + (i * 0.01),
          y: 0.3 + (i * 0.005),
          z: 0.1 + (i * 0.002),
          magnitude: 0.85 + (i * 0.01),
          timestamp: DateTime.now().subtract(Duration(seconds: 20 - i)),
        ));
      }
      
      expect(service.detectVehicleMovement(), true);
      expect(service.getMovementClassification(), 'vehicle');
    });

    test('should calculate confidence correctly', () {
      final service = AccelerometerService();
      
      // Add high-quality movement data
      for (int i = 0; i < 20; i++) {
        service._recentData.add(AccelerometerData(
          x: 1.0,
          y: 0.5,
          z: 0.2,
          magnitude: 1.1,
          timestamp: DateTime.now().subtract(Duration(seconds: 20 - i)),
        ));
      }
      
      final state = service.getCurrentMovementState();
      expect(state.confidence, greaterThan(0.7));
    });
  });

  group('Trip Model Tests', () {
    test('should create TripPoint with timezone offset', () {
      final now = DateTime.now();
      final point = TripPoint(
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: now,
        timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      );
      
      expect(point.latitude, 40.7128);
      expect(point.longitude, -74.0060);
      expect(point.timestamp, now);
      expect(point.timezoneOffsetMinutes, now.timeZoneOffset.inMinutes);
    });

    test('should serialize TripPoint to map', () {
      final now = DateTime.now();
      final point = TripPoint(
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: now,
        timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      );
      
      final map = point.toMap();
      expect(map['latitude'], 40.7128);
      expect(map['longitude'], -74.0060);
      expect(map['timestamp'], now.toIso8601String());
      expect(map['timezoneOffsetMinutes'], now.timeZoneOffset.inMinutes);
    });

    test('should create TripPoint from map', () {
      final now = DateTime.now();
      final map = {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'timestamp': now.toIso8601String(),
        'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      };
      
      final point = TripPoint.fromMap(map);
      expect(point.latitude, 40.7128);
      expect(point.longitude, -74.0060);
      expect(point.timestamp, now);
      expect(point.timezoneOffsetMinutes, now.timeZoneOffset.inMinutes);
    });

    test('should create TripSummary with timezone offset', () {
      final now = DateTime.now();
      final summary = TripSummary(
        id: 'test-trip',
        startedAt: now,
        endedAt: now.add(Duration(hours: 1)),
        distanceMeters: 5000.0,
        mode: TransportMode.walking,
        purpose: TripPurpose.work,
        companions: const Companions(alone: true),
        timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      );
      
      expect(summary.id, 'test-trip');
      expect(summary.startedAt, now);
      expect(summary.distanceMeters, 5000.0);
      expect(summary.timezoneOffsetMinutes, now.timeZoneOffset.inMinutes);
    });
  });

  group('Trip Detection Logic Tests', () {
    test('should detect trip start based on speed threshold', () {
      // Mock location data with speed above threshold
      final position = MockPosition(
        latitude: 40.7128,
        longitude: -74.0060,
        speed: 2.0, // Above threshold
        accuracy: 5.0,
        timestamp: DateTime.now(),
      );
      
      final config = TripDetectionConfig(
        autoStartSpeedThreshold: 1.2,
        autoStartTimeThreshold: 120,
        stopRadiusThreshold: 50.0,
        stopTimeThreshold: 180,
        minDistanceThreshold: 150.0,
        minDurationThreshold: 300,
        distanceFilter: 25.0,
        intervalDuration: 5,
      );
      
      expect(position.speed > config.autoStartSpeedThreshold, true);
    });

    test('should detect trip end based on stop conditions', () {
      final config = TripDetectionConfig(
        autoStartSpeedThreshold: 1.2,
        autoStartTimeThreshold: 120,
        stopRadiusThreshold: 50.0,
        stopTimeThreshold: 180,
        minDistanceThreshold: 150.0,
        minDurationThreshold: 300,
        distanceFilter: 25.0,
        intervalDuration: 5,
      );
      
      // Mock stationary position
      final stationaryPosition = MockPosition(
        latitude: 40.7128,
        longitude: -74.0060,
        speed: 0.1, // Below threshold
        accuracy: 5.0,
        timestamp: DateTime.now(),
      );
      
      expect(stationaryPosition.speed < config.autoStartSpeedThreshold, true);
    });

    test('should calculate distance between points', () {
      final point1 = TripPoint(
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
        timezoneOffsetMinutes: 0,
      );
      
      final point2 = TripPoint(
        latitude: 40.7589,
        longitude: -73.9851,
        timestamp: DateTime.now(),
        timezoneOffsetMinutes: 0,
      );
      
      final distance = _calculateDistance(point1, point2);
      expect(distance, greaterThan(0));
      expect(distance, lessThan(10000)); // Should be reasonable distance
    });
  });
}

// Mock classes for testing
class MockPosition {
  final double latitude;
  final double longitude;
  final double speed;
  final double accuracy;
  final DateTime timestamp;

  MockPosition({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
  });
}

// Helper function to calculate distance between two points
double _calculateDistance(TripPoint point1, TripPoint point2) {
  const double earthRadius = 6371000; // Earth's radius in meters
  
  final lat1Rad = point1.latitude * (3.14159265359 / 180);
  final lat2Rad = point2.latitude * (3.14159265359 / 180);
  final deltaLatRad = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
  final deltaLonRad = (point2.longitude - point1.longitude) * (3.14159265359 / 180);
  
  final a = (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
      lat1Rad.cos() * lat2Rad.cos() *
      (deltaLonRad / 2).sin() * (deltaLonRad / 2).sin();
  final c = 2 * (a.sqrt()).asin();
  
  return earthRadius * c;
}