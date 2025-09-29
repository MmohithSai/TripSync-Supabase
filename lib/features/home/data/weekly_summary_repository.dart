import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/weekly_summary_models.dart';
import '../../../common/providers.dart';

class WeeklySummaryRepository {
  final SupabaseClient _supabase;

  WeeklySummaryRepository(this._supabase);

  Future<WeeklySummary> getWeeklySummary(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = _getStartOfWeek(now);
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      // Get trips for the current week
      final tripsSnapshot = await _supabase
          .from('trips')
          .select()
          .eq('user_id', userId)
          .gte('started_at', startOfWeek.toIso8601String())
          .lt('started_at', endOfWeek.toIso8601String());

      if (tripsSnapshot.isEmpty) {
        return _createEmptySummary(startOfWeek, endOfWeek);
      }

      final trips = tripsSnapshot.map((tripData) {
        return TripData.fromMap(tripData);
      }).toList();

      return _calculateWeeklySummary(trips, startOfWeek, endOfWeek);
    } catch (e) {
      throw Exception('Failed to load weekly summary: $e');
    }
  }

  WeeklySummary _createEmptySummary(DateTime startDate, DateTime endDate) {
    return WeeklySummary(
      startDate: startDate,
      endDate: endDate,
      totalTrips: 0,
      totalDistance: 0,
      totalDuration: Duration.zero,
      averageSpeed: 0,
      modeDistribution: {},
      dailyTripCounts: List.filled(7, 0),
      topDestinations: [],
      co2Saved: 0,
      environmentalScore: 0,
    );
  }

  WeeklySummary _calculateWeeklySummary(
    List<TripData> trips,
    DateTime startDate,
    DateTime endDate,
  ) {
    final totalTrips = trips.length;
    final totalDistance = trips.fold(
      0.0,
      (sum, trip) => sum + trip.distanceMeters,
    );

    final totalDuration = trips.fold(Duration.zero, (sum, trip) {
      if (trip.endedAt != null) {
        return sum + trip.endedAt!.difference(trip.startedAt);
      }
      return sum;
    });

    final averageSpeed = totalDuration.inSeconds > 0
        ? totalDistance /
              (totalDuration.inSeconds / 3600) // km/h
        : 0.0;

    // Calculate mode distribution
    final modeDistribution = <String, int>{};
    for (final trip in trips) {
      modeDistribution[trip.mode] = (modeDistribution[trip.mode] ?? 0) + 1;
    }

    // Calculate daily trip counts
    final dailyTripCounts = List.filled(7, 0);
    for (final trip in trips) {
      final dayOfWeek = trip.startedAt.weekday - 1; // Monday = 0
      dailyTripCounts[dayOfWeek]++;
    }

    // Calculate top destinations
    final destinationMap = <String, DestinationData>{};
    for (final trip in trips) {
      final destName = trip.destinationRegion ?? 'Unknown';
      if (destinationMap.containsKey(destName)) {
        final dest = destinationMap[destName]!;
        destinationMap[destName] = DestinationData(
          name: destName,
          tripCount: dest.tripCount + 1,
          totalDistance: dest.totalDistance + trip.distanceMeters,
          modes: [...dest.modes, trip.mode],
        );
      } else {
        destinationMap[destName] = DestinationData(
          name: destName,
          tripCount: 1,
          totalDistance: trip.distanceMeters,
          modes: [trip.mode],
        );
      }
    }

    final topDestinations =
        destinationMap.values
            .map(
              (dest) => Destination(
                name: dest.name,
                tripCount: dest.tripCount,
                totalDistance: dest.totalDistance,
                primaryMode: _getPrimaryMode(dest.modes),
              ),
            )
            .toList()
          ..sort((a, b) => b.tripCount.compareTo(a.tripCount));

    // Calculate environmental impact
    final co2Saved = _calculateCO2Saved(trips);
    final environmentalScore = _calculateEnvironmentalScore(trips);

    return WeeklySummary(
      startDate: startDate,
      endDate: endDate,
      totalTrips: totalTrips,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      averageSpeed: averageSpeed,
      modeDistribution: modeDistribution,
      dailyTripCounts: dailyTripCounts,
      topDestinations: topDestinations.take(5).toList(),
      co2Saved: co2Saved,
      environmentalScore: environmentalScore,
    );
  }

  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  String _getPrimaryMode(List<String> modes) {
    final modeCounts = <String, int>{};
    for (final mode in modes) {
      modeCounts[mode] = (modeCounts[mode] ?? 0) + 1;
    }

    return modeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _calculateCO2Saved(List<TripData> trips) {
    double co2Saved = 0;

    for (final trip in trips) {
      // CO2 savings compared to driving
      switch (trip.mode.toLowerCase()) {
        case 'walking':
          co2Saved += trip.distanceMeters * 0.0002; // 0.2g CO2 per meter
          break;
        case 'cycling':
          co2Saved += trip.distanceMeters * 0.0001; // 0.1g CO2 per meter
          break;
        case 'public_transport':
          co2Saved += trip.distanceMeters * 0.00005; // 0.05g CO2 per meter
          break;
        case 'train':
          co2Saved += trip.distanceMeters * 0.00003; // 0.03g CO2 per meter
          break;
        case 'bus':
          co2Saved += trip.distanceMeters * 0.00008; // 0.08g CO2 per meter
          break;
        // Driving and motorcycle don't save CO2
        default:
          break;
      }
    }

    return co2Saved / 1000; // Convert to kg
  }

  int _calculateEnvironmentalScore(List<TripData> trips) {
    if (trips.isEmpty) return 0;

    int score = 0;
    int totalTrips = trips.length;

    for (final trip in trips) {
      switch (trip.mode.toLowerCase()) {
        case 'walking':
          score += 20;
          break;
        case 'cycling':
          score += 18;
          break;
        case 'public_transport':
          score += 15;
          break;
        case 'train':
          score += 12;
          break;
        case 'bus':
          score += 10;
          break;
        case 'motorcycle':
          score += 5;
          break;
        case 'driving':
          score += 2;
          break;
        default:
          score += 1;
          break;
      }
    }

    return (score / totalTrips).round();
  }
}

// Helper class for destination calculations
class DestinationData {
  final String name;
  final int tripCount;
  final double totalDistance;
  final List<String> modes;

  DestinationData({
    required this.name,
    required this.tripCount,
    required this.totalDistance,
    required this.modes,
  });
}

// Trip data model for calculations
class TripData {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceMeters;
  final String mode;
  final String purpose;
  final bool isRecurring;
  final String? destinationRegion;
  final String? originRegion;
  final int timezoneOffsetMinutes;

  const TripData({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.distanceMeters,
    required this.mode,
    required this.purpose,
    required this.isRecurring,
    this.destinationRegion,
    this.originRegion,
    required this.timezoneOffsetMinutes,
  });

  factory TripData.fromMap(Map<String, dynamic> map) {
    return TripData(
      id: map['id'] ?? '',
      startedAt: DateTime.parse(map['started_at']),
      endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at']) : null,
      distanceMeters: (map['distance_meters'] ?? 0).toDouble(),
      mode: map['mode'] ?? 'unknown',
      purpose: map['purpose'] ?? 'unknown',
      isRecurring: map['is_recurring'] ?? false,
      destinationRegion: map['destination_region'],
      originRegion: map['origin_region'],
      timezoneOffsetMinutes: map['timezone_offset_minutes'] ?? 0,
    );
  }
}

// Provider for WeeklySummaryRepository
final weeklySummaryRepositoryProvider = Provider<WeeklySummaryRepository>((
  ref,
) {
  return WeeklySummaryRepository(ref.watch(supabaseProvider));
});

// Provider for weekly summary
final weeklySummaryProvider = FutureProvider<WeeklySummary>((ref) async {
  // TODO: Get current user ID from auth provider
  final userId = 'current-user-id'; // This should come from auth
  final repository = ref.watch(weeklySummaryRepositoryProvider);
  return repository.getWeeklySummary(userId);
});
