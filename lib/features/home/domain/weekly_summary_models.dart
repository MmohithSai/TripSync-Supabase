class WeeklySummary {
  final DateTime startDate;
  final DateTime endDate;
  final int totalTrips;
  final double totalDistance;
  final Duration totalDuration;
  final double averageSpeed;
  final Map<String, int> modeDistribution;
  final List<int> dailyTripCounts;
  final List<Destination> topDestinations;
  final double co2Saved;
  final int environmentalScore;

  const WeeklySummary({
    required this.startDate,
    required this.endDate,
    required this.totalTrips,
    required this.totalDistance,
    required this.totalDuration,
    required this.averageSpeed,
    required this.modeDistribution,
    required this.dailyTripCounts,
    required this.topDestinations,
    required this.co2Saved,
    required this.environmentalScore,
  });

  factory WeeklySummary.fromMap(Map<String, dynamic> map) {
    return WeeklySummary(
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      totalTrips: map['totalTrips'] ?? 0,
      totalDistance: (map['totalDistance'] ?? 0).toDouble(),
      totalDuration: Duration(seconds: map['totalDurationSeconds'] ?? 0),
      averageSpeed: (map['averageSpeed'] ?? 0).toDouble(),
      modeDistribution: Map<String, int>.from(map['modeDistribution'] ?? {}),
      dailyTripCounts: List<int>.from(map['dailyTripCounts'] ?? []),
      topDestinations: (map['topDestinations'] as List<dynamic>?)
          ?.map((dest) => Destination.fromMap(dest))
          .toList() ?? [],
      co2Saved: (map['co2Saved'] ?? 0).toDouble(),
      environmentalScore: map['environmentalScore'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalTrips': totalTrips,
      'totalDistance': totalDistance,
      'totalDurationSeconds': totalDuration.inSeconds,
      'averageSpeed': averageSpeed,
      'modeDistribution': modeDistribution,
      'dailyTripCounts': dailyTripCounts,
      'topDestinations': topDestinations.map((dest) => dest.toMap()).toList(),
      'co2Saved': co2Saved,
      'environmentalScore': environmentalScore,
    };
  }
}

class Destination {
  final String name;
  final int tripCount;
  final double totalDistance;
  final String primaryMode;

  const Destination({
    required this.name,
    required this.tripCount,
    required this.totalDistance,
    required this.primaryMode,
  });

  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      name: map['name'] ?? '',
      tripCount: map['tripCount'] ?? 0,
      totalDistance: (map['totalDistance'] ?? 0).toDouble(),
      primaryMode: map['primaryMode'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tripCount': tripCount,
      'totalDistance': totalDistance,
      'primaryMode': primaryMode,
    };
  }
}



