import 'package:flutter_test/flutter_test.dart';
import 'package:location_tracker_app/features/dashboard/domain/dashboard_models.dart';

void main() {
  group('Export Function Tests', () {
    test('should generate CSV data correctly', () {
      final trips = [
        TripData(
          id: 'trip-1',
          startedAt: DateTime(2024, 1, 1, 9, 0),
          endedAt: DateTime(2024, 1, 1, 9, 30),
          distanceMeters: 2000.0,
          mode: 'walking',
          purpose: 'work',
          isRecurring: false,
          destinationRegion: 'Office',
          originRegion: 'Home',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
        TripData(
          id: 'trip-2',
          startedAt: DateTime(2024, 1, 1, 17, 0),
          endedAt: DateTime(2024, 1, 1, 17, 45),
          distanceMeters: 1500.0,
          mode: 'cycling',
          purpose: 'leisure',
          isRecurring: true,
          destinationRegion: 'Park',
          originRegion: 'Office',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
      ];
      
      final csvData = _generateCSVData(trips);
      
      expect(csvData, isNotEmpty);
      expect(csvData, contains('Trip ID'));
      expect(csvData, contains('Start Time'));
      expect(csvData, contains('trip-1'));
      expect(csvData, contains('walking'));
      expect(csvData, contains('2000'));
    });

    test('should generate GeoJSON data correctly', () {
      final trips = [
        TripData(
          id: 'trip-1',
          startedAt: DateTime(2024, 1, 1, 9, 0),
          endedAt: DateTime(2024, 1, 1, 9, 30),
          distanceMeters: 2000.0,
          mode: 'walking',
          purpose: 'work',
          isRecurring: false,
          destinationRegion: 'Office',
          originRegion: 'Home',
          timezoneOffsetMinutes: -300,
          points: [
            TripPoint(
              latitude: 40.7128,
              longitude: -74.0060,
              timestamp: DateTime(2024, 1, 1, 9, 0),
              accuracy: 5.0,
              speed: 1.5,
              heading: 90.0,
            ),
            TripPoint(
              latitude: 40.7589,
              longitude: -73.9851,
              timestamp: DateTime(2024, 1, 1, 9, 30),
              accuracy: 5.0,
              speed: 0.0,
              heading: 0.0,
            ),
          ],
        ),
      ];
      
      final geoJsonData = _generateGeoJSONData(trips);
      
      expect(geoJsonData, isNotEmpty);
      expect(geoJsonData, contains('FeatureCollection'));
      expect(geoJsonData, contains('LineString'));
      expect(geoJsonData, contains('trip-1'));
      expect(geoJsonData, contains('walking'));
    });

    test('should anonymize trip data correctly', () {
      final originalTrip = TripData(
        id: 'user123-trip456',
        startedAt: DateTime(2024, 1, 1, 9, 0),
        endedAt: DateTime(2024, 1, 1, 9, 30),
        distanceMeters: 2000.0,
        mode: 'walking',
        purpose: 'work',
        isRecurring: false,
        destinationRegion: 'Office',
        originRegion: 'Home',
        timezoneOffsetMinutes: -300,
        points: [],
      );
      
      final anonymizedTrip = _anonymizeTripData(originalTrip);
      
      // ID should be anonymized
      expect(anonymizedTrip.id, isNot(equals(originalTrip.id)));
      expect(anonymizedTrip.id, isNotEmpty);
      
      // Other data should remain the same
      expect(anonymizedTrip.distanceMeters, originalTrip.distanceMeters);
      expect(anonymizedTrip.mode, originalTrip.mode);
      expect(anonymizedTrip.purpose, originalTrip.purpose);
    });

    test('should calculate trip statistics correctly', () {
      final trips = [
        TripData(
          id: 'trip-1',
          startedAt: DateTime(2024, 1, 1, 9, 0),
          endedAt: DateTime(2024, 1, 1, 9, 30),
          distanceMeters: 2000.0,
          mode: 'walking',
          purpose: 'work',
          isRecurring: false,
          destinationRegion: 'Office',
          originRegion: 'Home',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
        TripData(
          id: 'trip-2',
          startedAt: DateTime(2024, 1, 1, 17, 0),
          endedAt: DateTime(2024, 1, 1, 17, 45),
          distanceMeters: 1500.0,
          mode: 'cycling',
          purpose: 'leisure',
          isRecurring: true,
          destinationRegion: 'Park',
          originRegion: 'Office',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
      ];
      
      final stats = _calculateTripStats(trips);
      
      expect(stats.totalTrips, 2);
      expect(stats.totalDistance, 3500.0);
      expect(stats.modeCounts['walking'], 1);
      expect(stats.modeCounts['cycling'], 1);
      expect(stats.purposeCounts['work'], 1);
      expect(stats.purposeCounts['leisure'], 1);
      expect(stats.recurringTrips, 1);
    });

    test('should filter trips by date range', () {
      final allTrips = [
        TripData(
          id: 'trip-1',
          startedAt: DateTime(2024, 1, 1, 9, 0),
          endedAt: DateTime(2024, 1, 1, 9, 30),
          distanceMeters: 2000.0,
          mode: 'walking',
          purpose: 'work',
          isRecurring: false,
          destinationRegion: 'Office',
          originRegion: 'Home',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
        TripData(
          id: 'trip-2',
          startedAt: DateTime(2024, 1, 2, 9, 0),
          endedAt: DateTime(2024, 1, 2, 9, 30),
          distanceMeters: 1500.0,
          mode: 'cycling',
          purpose: 'leisure',
          isRecurring: true,
          destinationRegion: 'Park',
          originRegion: 'Office',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
        TripData(
          id: 'trip-3',
          startedAt: DateTime(2024, 1, 3, 9, 0),
          endedAt: DateTime(2024, 1, 3, 9, 30),
          distanceMeters: 1000.0,
          mode: 'driving',
          purpose: 'shopping',
          isRecurring: false,
          destinationRegion: 'Mall',
          originRegion: 'Home',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
      ];
      
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 2);
      
      final filteredTrips = _filterTripsByDateRange(allTrips, startDate, endDate);
      
      expect(filteredTrips.length, 2);
      expect(filteredTrips.any((trip) => trip.id == 'trip-1'), true);
      expect(filteredTrips.any((trip) => trip.id == 'trip-2'), true);
      expect(filteredTrips.any((trip) => trip.id == 'trip-3'), false);
    });

    test('should validate export data format', () {
      final trips = [
        TripData(
          id: 'trip-1',
          startedAt: DateTime(2024, 1, 1, 9, 0),
          endedAt: DateTime(2024, 1, 1, 9, 30),
          distanceMeters: 2000.0,
          mode: 'walking',
          purpose: 'work',
          isRecurring: false,
          destinationRegion: 'Office',
          originRegion: 'Home',
          timezoneOffsetMinutes: -300,
          points: [],
        ),
      ];
      
      final csvData = _generateCSVData(trips);
      final geoJsonData = _generateGeoJSONData(trips);
      
      // Validate CSV format
      expect(csvData, contains(','));
      expect(csvData.split('\n').length, greaterThan(1)); // Header + data rows
      
      // Validate GeoJSON format
      expect(geoJsonData, contains('"type"'));
      expect(geoJsonData, contains('"FeatureCollection"'));
      expect(geoJsonData, contains('"features"'));
    });
  });
}

// Helper functions for testing
String _generateCSVData(List<TripData> trips) {
  final buffer = StringBuffer();
  
  // Header
  buffer.writeln('Trip ID,Start Time,End Time,Distance (m),Mode,Purpose,Is Recurring,Origin Region,Destination Region,Timezone Offset (min)');
  
  // Data rows
  for (final trip in trips) {
    buffer.writeln('${trip.id},${trip.startedAt.toIso8601String()},${trip.endedAt?.toIso8601String() ?? ""},${trip.distanceMeters},${trip.mode},${trip.purpose},${trip.isRecurring},${trip.originRegion ?? ""},${trip.destinationRegion ?? ""},${trip.timezoneOffsetMinutes}');
  }
  
  return buffer.toString();
}

String _generateGeoJSONData(List<TripData> trips) {
  final features = <Map<String, dynamic>>[];
  
  for (final trip in trips) {
    if (trip.points.isNotEmpty) {
      final coordinates = trip.points.map((point) => [point.longitude, point.latitude]).toList();
      
      features.add({
        'type': 'Feature',
        'properties': {
          'tripId': trip.id,
          'startedAt': trip.startedAt.toIso8601String(),
          'endedAt': trip.endedAt?.toIso8601String(),
          'distanceMeters': trip.distanceMeters,
          'mode': trip.mode,
          'purpose': trip.purpose,
          'isRecurring': trip.isRecurring,
          'originRegion': trip.originRegion,
          'destinationRegion': trip.destinationRegion,
          'timezoneOffsetMinutes': trip.timezoneOffsetMinutes,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': coordinates,
        },
      });
    }
  }
  
  return {
    'type': 'FeatureCollection',
    'features': features,
    'properties': {
      'exportDate': DateTime.now().toIso8601String(),
      'tripCount': trips.length,
      'totalPoints': trips.fold(0, (sum, trip) => sum + trip.points.length),
    },
  }.toString();
}

TripData _anonymizeTripData(TripData trip) {
  // Simple anonymization by hashing the ID
  final anonymizedId = trip.id.hashCode.abs().toString();
  
  return TripData(
    id: anonymizedId,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    distanceMeters: trip.distanceMeters,
    mode: trip.mode,
    purpose: trip.purpose,
    isRecurring: trip.isRecurring,
    destinationRegion: trip.destinationRegion,
    originRegion: trip.originRegion,
    timezoneOffsetMinutes: trip.timezoneOffsetMinutes,
    points: trip.points,
  );
}

TripStats _calculateTripStats(List<TripData> trips) {
  final totalTrips = trips.length;
  final totalDistance = trips.fold(0.0, (sum, trip) => sum + trip.distanceMeters);
  
  final modeCounts = <String, int>{};
  final purposeCounts = <String, int>{};
  int recurringTrips = 0;
  
  for (final trip in trips) {
    modeCounts[trip.mode] = (modeCounts[trip.mode] ?? 0) + 1;
    purposeCounts[trip.purpose] = (purposeCounts[trip.purpose] ?? 0) + 1;
    if (trip.isRecurring) recurringTrips++;
  }
  
  return TripStats(
    totalTrips: totalTrips,
    totalDistance: totalDistance,
    totalDuration: Duration.zero, // Simplified for test
    averageSpeed: 0.0, // Simplified for test
    modeCounts: modeCounts,
    purposeCounts: purposeCounts,
    recurringTrips: recurringTrips,
    averageTripDistance: totalDistance / totalTrips,
    averageTripDuration: Duration.zero, // Simplified for test
  );
}

List<TripData> _filterTripsByDateRange(List<TripData> trips, DateTime startDate, DateTime endDate) {
  return trips.where((trip) {
    return trip.startedAt.isAfter(startDate.subtract(Duration(seconds: 1))) &&
           trip.startedAt.isBefore(endDate.add(Duration(seconds: 1)));
  }).toList();
}