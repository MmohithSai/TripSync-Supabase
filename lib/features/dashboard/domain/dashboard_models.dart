class DashboardData {
  final List<TripData> trips;
  final Map<String, int> modeShare;
  final TripStats stats;
  final List<OriginDestinationPair> odPairs;
  final DateTime date;
  final String region;

  const DashboardData({
    required this.trips,
    required this.modeShare,
    required this.stats,
    required this.odPairs,
    required this.date,
    required this.region,
  });

  factory DashboardData.fromMap(Map<String, dynamic> map) {
    return DashboardData(
      trips: (map['trips'] as List<dynamic>?)
          ?.map((trip) => TripData.fromMap(trip))
          .toList() ?? [],
      modeShare: Map<String, int>.from(map['modeShare'] ?? {}),
      stats: TripStats.fromMap(map['stats'] ?? {}),
      odPairs: (map['odPairs'] as List<dynamic>?)
          ?.map((pair) => OriginDestinationPair.fromMap(pair))
          .toList() ?? [],
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      region: map['region'] ?? 'All',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trips': trips.map((trip) => trip.toMap()).toList(),
      'modeShare': modeShare,
      'stats': stats.toMap(),
      'odPairs': odPairs.map((pair) => pair.toMap()).toList(),
      'date': date.toIso8601String(),
      'region': region,
    };
  }
}

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
  final List<TripPoint> points;

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
    required this.points,
  });

  factory TripData.fromMap(Map<String, dynamic> map) {
    return TripData(
      id: map['id'] ?? '',
      startedAt: DateTime.parse(map['startedAt'] ?? DateTime.now().toIso8601String()),
      endedAt: map['endedAt'] != null ? DateTime.parse(map['endedAt']) : null,
      distanceMeters: (map['distanceMeters'] ?? 0).toDouble(),
      mode: map['mode'] ?? 'unknown',
      purpose: map['purpose'] ?? 'unknown',
      isRecurring: map['isRecurring'] ?? false,
      destinationRegion: map['destinationRegion'],
      originRegion: map['originRegion'],
      timezoneOffsetMinutes: map['timezoneOffsetMinutes'] ?? 0,
      points: (map['points'] as List<dynamic>?)
          ?.map((point) => TripPoint.fromMap(point))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'distanceMeters': distanceMeters,
      'mode': mode,
      'purpose': purpose,
      'isRecurring': isRecurring,
      'destinationRegion': destinationRegion,
      'originRegion': originRegion,
      'timezoneOffsetMinutes': timezoneOffsetMinutes,
      'points': points.map((point) => point.toMap()).toList(),
    };
  }
}

class TripPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double speed;
  final double heading;

  const TripPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.speed,
    required this.heading,
  });

  factory TripPoint.fromMap(Map<String, dynamic> map) {
    return TripPoint(
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      accuracy: (map['accuracy'] ?? 0).toDouble(),
      speed: (map['speed'] ?? 0).toDouble(),
      heading: (map['heading'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
    };
  }
}

class TripStats {
  final int totalTrips;
  final double totalDistance;
  final Duration totalDuration;
  final double averageSpeed;
  final Map<String, int> modeCounts;
  final Map<String, int> purposeCounts;
  final int recurringTrips;
  final double averageTripDistance;
  final Duration averageTripDuration;

  const TripStats({
    required this.totalTrips,
    required this.totalDistance,
    required this.totalDuration,
    required this.averageSpeed,
    required this.modeCounts,
    required this.purposeCounts,
    required this.recurringTrips,
    required this.averageTripDistance,
    required this.averageTripDuration,
  });

  factory TripStats.fromMap(Map<String, dynamic> map) {
    return TripStats(
      totalTrips: map['totalTrips'] ?? 0,
      totalDistance: (map['totalDistance'] ?? 0).toDouble(),
      totalDuration: Duration(seconds: map['totalDurationSeconds'] ?? 0),
      averageSpeed: (map['averageSpeed'] ?? 0).toDouble(),
      modeCounts: Map<String, int>.from(map['modeCounts'] ?? {}),
      purposeCounts: Map<String, int>.from(map['purposeCounts'] ?? {}),
      recurringTrips: map['recurringTrips'] ?? 0,
      averageTripDistance: (map['averageTripDistance'] ?? 0).toDouble(),
      averageTripDuration: Duration(seconds: map['averageTripDurationSeconds'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalTrips': totalTrips,
      'totalDistance': totalDistance,
      'totalDurationSeconds': totalDuration.inSeconds,
      'averageSpeed': averageSpeed,
      'modeCounts': modeCounts,
      'purposeCounts': purposeCounts,
      'recurringTrips': recurringTrips,
      'averageTripDistance': averageTripDistance,
      'averageTripDurationSeconds': averageTripDuration.inSeconds,
    };
  }
}

class OriginDestinationPair {
  final String origin;
  final String destination;
  final int tripCount;
  final double totalDistance;
  final String primaryMode;

  const OriginDestinationPair({
    required this.origin,
    required this.destination,
    required this.tripCount,
    required this.totalDistance,
    required this.primaryMode,
  });

  factory OriginDestinationPair.fromMap(Map<String, dynamic> map) {
    return OriginDestinationPair(
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      tripCount: map['tripCount'] ?? 0,
      totalDistance: (map['totalDistance'] ?? 0).toDouble(),
      primaryMode: map['primaryMode'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'origin': origin,
      'destination': destination,
      'tripCount': tripCount,
      'totalDistance': totalDistance,
      'primaryMode': primaryMode,
    };
  }
}

class DashboardParams {
  final DateTime date;
  final String region;

  const DashboardParams({
    required this.date,
    required this.region,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardParams &&
        other.date == date &&
        other.region == region;
  }

  @override
  int get hashCode => date.hashCode ^ region.hashCode;
}



