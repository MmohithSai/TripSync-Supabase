import 'package:cloud_firestore/cloud_firestore.dart';

enum TripMode { unknown, walk, bicycle, car, bus, train, metro, scooter }

enum TripPurpose { unknown, work, school, shopping, leisure, healthcare, other }

class Companions {
  final int adults;
  final int children;
  final int seniors;
  final String? relationship; // optional free text

  const Companions({this.adults = 0, this.children = 0, this.seniors = 0, this.relationship});

  Map<String, dynamic> toMap() => {
        'adults': adults,
        'children': children,
        'seniors': seniors,
        'relationship': relationship,
      };

  static Companions fromMap(Map<String, dynamic>? d) {
    if (d == null) return const Companions();
    return Companions(
      adults: (d['adults'] as num?)?.toInt() ?? 0,
      children: (d['children'] as num?)?.toInt() ?? 0,
      seniors: (d['seniors'] as num?)?.toInt() ?? 0,
      relationship: d['relationship'] as String?,
    );
  }
}

class TripSummary {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceMeters; // accumulated
  final TripMode mode;
  final TripPurpose purpose;
  final Companions companions;
  final bool isRecurring;
  final String? destinationRegion;
  final String? originRegion;
  final String? tripNumber;
  final String? chainId; // identify chain of trips
  final int timezoneOffsetMinutes; // local timezone offset in minutes

  const TripSummary({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.mode,
    required this.purpose,
    required this.companions,
    this.isRecurring = false,
    this.destinationRegion,
    this.originRegion,
    this.tripNumber,
    this.chainId,
    required this.timezoneOffsetMinutes,
  });

  Map<String, dynamic> toMap() => {
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
        'distanceMeters': distanceMeters,
        'mode': mode.name,
        'purpose': purpose.name,
        'companions': companions.toMap(),
        'isRecurring': isRecurring,
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
        if (destinationRegion != null) 'destinationRegion': destinationRegion,
        if (originRegion != null) 'originRegion': originRegion,
        if (tripNumber != null) 'tripNumber': tripNumber,
        if (chainId != null) 'chainId': chainId,
      };

  static TripSummary fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return TripSummary(
      id: doc.id,
      startedAt: (d['startedAt'] as Timestamp).toDate(),
      endedAt: (d['endedAt'] as Timestamp?)?.toDate(),
      distanceMeters: (d['distanceMeters'] as num).toDouble(),
      mode: TripMode.values.firstWhere(
        (m) => m.name == (d['mode'] as String? ?? 'unknown'),
        orElse: () => TripMode.unknown,
      ),
      purpose: TripPurpose.values.firstWhere(
        (p) => p.name == (d['purpose'] as String? ?? 'unknown'),
        orElse: () => TripPurpose.unknown,
      ),
      companions: Companions.fromMap(d['companions'] as Map<String, dynamic>?),
      isRecurring: (d['isRecurring'] as bool?) ?? false,
      timezoneOffsetMinutes: (d['timezoneOffsetMinutes'] as num?)?.toInt() ?? 0,
      destinationRegion: d['destinationRegion'] as String?,
      originRegion: d['originRegion'] as String?,
      tripNumber: d['tripNumber'] as String?,
      chainId: d['chainId'] as String?,
    );
  }

  static TripSummary fromMap(Map<String, dynamic> map) {
    return TripSummary(
      id: map['id'] as String,
      startedAt: (map['startedAt'] as Timestamp).toDate(),
      endedAt: map['endedAt'] != null ? (map['endedAt'] as Timestamp).toDate() : null,
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      mode: TripMode.values.firstWhere(
        (m) => m.name == (map['mode'] as String? ?? 'unknown'),
        orElse: () => TripMode.unknown,
      ),
      purpose: TripPurpose.values.firstWhere(
        (p) => p.name == (map['purpose'] as String? ?? 'unknown'),
        orElse: () => TripPurpose.unknown,
      ),
      companions: Companions.fromMap(map['companions'] as Map<String, dynamic>?),
      isRecurring: (map['isRecurring'] as bool?) ?? false,
      timezoneOffsetMinutes: (map['timezoneOffsetMinutes'] as num?)?.toInt() ?? 0,
      destinationRegion: map['destinationRegion'] as String?,
      originRegion: map['originRegion'] as String?,
      tripNumber: map['tripNumber'] as String?,
      chainId: map['chainId'] as String?,
    );
  }
}

class TripPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final int timezoneOffsetMinutes; // local timezone offset in minutes

  const TripPoint({
    required this.latitude, 
    required this.longitude, 
    required this.timestamp,
    required this.timezoneOffsetMinutes,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.fromDate(timestamp),
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
      };

  static TripPoint fromMap(Map<String, dynamic> map) {
    return TripPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      timezoneOffsetMinutes: (map['timezoneOffsetMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}





