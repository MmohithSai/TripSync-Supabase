import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/dashboard_models.dart';

class DashboardRepository {
  final FirebaseFirestore _firestore;
  
  DashboardRepository(this._firestore);

  Future<DashboardData> getDashboardData(DashboardParams params) async {
    try {
      // Get trips for the specified date and region
      final trips = await _getTrips(params);
      
      // Calculate statistics
      final stats = _calculateStats(trips);
      
      // Calculate mode share
      final modeShare = _calculateModeShare(trips);
      
      // Calculate origin-destination pairs
      final odPairs = _calculateOriginDestinationPairs(trips);
      
      return DashboardData(
        trips: trips,
        modeShare: modeShare,
        stats: stats,
        odPairs: odPairs,
        date: params.date,
        region: params.region,
      );
    } catch (e) {
      throw Exception('Failed to load dashboard data: $e');
    }
  }

  Future<List<TripData>> _getTrips(DashboardParams params) async {
    final startOfDay = DateTime(params.date.year, params.date.month, params.date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    Query query = _firestore.collectionGroup('trips')
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startedAt', isLessThan: Timestamp.fromDate(endOfDay));
    
    // Filter by region if not 'All'
    if (params.region != 'All') {
      query = query.where('originRegion', isEqualTo: params.region);
    }
    
    final snapshot = await query.get();
    
    final trips = <TripData>[];
    
    for (final doc in snapshot.docs) {
      final tripData = doc.data() as Map<String, dynamic>;
      
      // Get trip points
      final pointsSnapshot = await doc.reference.collection('points').get();
      final points = pointsSnapshot.docs.map((pointDoc) {
        final pointData = pointDoc.data() as Map<String, dynamic>;
        return TripPoint.fromMap(pointData);
      }).toList();
      
      final trip = TripData(
        id: doc.id,
        startedAt: (tripData['startedAt'] as Timestamp).toDate(),
        endedAt: tripData['endedAt'] != null 
            ? (tripData['endedAt'] as Timestamp).toDate() 
            : null,
        distanceMeters: (tripData['distanceMeters'] ?? 0).toDouble(),
        mode: tripData['mode'] ?? 'unknown',
        purpose: tripData['purpose'] ?? 'unknown',
        isRecurring: tripData['isRecurring'] ?? false,
        destinationRegion: tripData['destinationRegion'],
        originRegion: tripData['originRegion'],
        timezoneOffsetMinutes: tripData['timezoneOffsetMinutes'] ?? 0,
        points: points,
      );
      
      trips.add(trip);
    }
    
    return trips;
  }

  TripStats _calculateStats(List<TripData> trips) {
    if (trips.isEmpty) {
      return const TripStats(
        totalTrips: 0,
        totalDistance: 0,
        totalDuration: Duration.zero,
        averageSpeed: 0,
        modeCounts: {},
        purposeCounts: {},
        recurringTrips: 0,
        averageTripDistance: 0,
        averageTripDuration: Duration.zero,
      );
    }
    
    final totalTrips = trips.length;
    final totalDistance = trips.fold(0.0, (sum, trip) => sum + trip.distanceMeters);
    
    final totalDuration = trips.fold(Duration.zero, (sum, trip) {
      if (trip.endedAt != null) {
        return sum + trip.endedAt!.difference(trip.startedAt);
      }
      return sum;
    });
    
    final averageSpeed = totalDuration.inSeconds > 0 
        ? totalDistance / (totalDuration.inSeconds / 3600) // km/h
        : 0.0;
    
    final modeCounts = <String, int>{};
    final purposeCounts = <String, int>{};
    int recurringTrips = 0;
    
    for (final trip in trips) {
      modeCounts[trip.mode] = (modeCounts[trip.mode] ?? 0) + 1;
      purposeCounts[trip.purpose] = (purposeCounts[trip.purpose] ?? 0) + 1;
      if (trip.isRecurring) recurringTrips++;
    }
    
    final averageTripDistance = totalDistance / totalTrips;
    final averageTripDuration = Duration(
      milliseconds: totalDuration.inMilliseconds ~/ totalTrips
    );
    
    return TripStats(
      totalTrips: totalTrips,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      averageSpeed: averageSpeed,
      modeCounts: modeCounts,
      purposeCounts: purposeCounts,
      recurringTrips: recurringTrips,
      averageTripDistance: averageTripDistance,
      averageTripDuration: averageTripDuration,
    );
  }

  Map<String, int> _calculateModeShare(List<TripData> trips) {
    final modeCounts = <String, int>{};
    
    for (final trip in trips) {
      modeCounts[trip.mode] = (modeCounts[trip.mode] ?? 0) + 1;
    }
    
    return modeCounts;
  }

  List<OriginDestinationPair> _calculateOriginDestinationPairs(List<TripData> trips) {
    final odMap = <String, Map<String, int>>{};
    
    for (final trip in trips) {
      final origin = trip.originRegion ?? 'Unknown';
      final destination = trip.destinationRegion ?? 'Unknown';
      
      if (!odMap.containsKey(origin)) {
        odMap[origin] = <String, int>{};
      }
      
      odMap[origin]![destination] = (odMap[origin]![destination] ?? 0) + 1;
    }
    
    final odPairs = <OriginDestinationPair>[];
    
    for (final origin in odMap.keys) {
      for (final destination in odMap[origin]!.keys) {
        final tripCount = odMap[origin]![destination]!;
        
        // Find trips for this OD pair to calculate total distance and primary mode
        final odTrips = trips.where((trip) => 
            (trip.originRegion ?? 'Unknown') == origin &&
            (trip.destinationRegion ?? 'Unknown') == destination
        ).toList();
        
        final totalDistance = odTrips.fold(0.0, (sum, trip) => sum + trip.distanceMeters);
        
        // Find primary mode (most common mode for this OD pair)
        final modeCounts = <String, int>{};
        for (final trip in odTrips) {
          modeCounts[trip.mode] = (modeCounts[trip.mode] ?? 0) + 1;
        }
        
        final primaryMode = modeCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        
        odPairs.add(OriginDestinationPair(
          origin: origin,
          destination: destination,
          tripCount: tripCount,
          totalDistance: totalDistance,
          primaryMode: primaryMode,
        ));
      }
    }
    
    // Sort by trip count descending
    odPairs.sort((a, b) => b.tripCount.compareTo(a.tripCount));
    
    return odPairs;
  }

  Future<void> exportData(DashboardData data, String format) async {
    // TODO: Implement export functionality
    // This would call the Firebase Cloud Function for export
    throw UnimplementedError('Export functionality not yet implemented');
  }
}

// Provider for DashboardRepository
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(FirebaseFirestore.instance);
});

// Provider for dashboard data
final dashboardDataProvider = FutureProvider.family<DashboardData, DashboardParams>((ref, params) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getDashboardData(params);
});



