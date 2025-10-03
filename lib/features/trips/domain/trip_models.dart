// Removed Firebase import - now using Supabase

enum TripMode { unknown, walk, bicycle, car, bus, train, metro, scooter }

enum TripPurpose { unknown, work, school, shopping, leisure, healthcare, other }

class Companions {
  final int adults;
  final int children;
  final int seniors;
  final String? relationship; // optional free text

  const Companions({
    this.adults = 0,
    this.children = 0,
    this.seniors = 0,
    this.relationship,
  });

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
  // Enhanced destination information
  final String? destinationName;
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationPlaceId;
  final String? originName;
  final String? originAddress;
  final double? originLatitude;
  final double? originLongitude;
  final String? originPlaceId;
  // Additional detailed trip information
  final double? averageSpeed; // average speed in m/s
  final double? maxSpeed; // maximum speed in m/s
  final double? minSpeed; // minimum speed in m/s
  final int? totalPoints; // total number of GPS points
  final double? totalElevationGain; // total elevation gain in meters
  final double? totalElevationLoss; // total elevation loss in meters
  final double? averageAccuracy; // average GPS accuracy in meters
  final String? weatherCondition; // weather condition during trip
  final double? temperature; // temperature in Celsius
  final String? notes; // user notes about the trip
  final List<String>? tags; // user-defined tags
  final String? routeName; // name of the route taken
  final String? routeType; // type of route (highway, city, rural, etc.)
  final int? stopsCount; // number of stops during the trip
  final double? fuelConsumption; // fuel consumption (for vehicles)
  final double? co2Emissions; // CO2 emissions in kg
  final String? deviceInfo; // device information
  final String? appVersion; // app version used
  final Map<String, dynamic>? customData; // custom additional data

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
    this.destinationName,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationPlaceId,
    this.originName,
    this.originAddress,
    this.originLatitude,
    this.originLongitude,
    this.originPlaceId,
    // Additional detailed trip information
    this.averageSpeed,
    this.maxSpeed,
    this.minSpeed,
    this.totalPoints,
    this.totalElevationGain,
    this.totalElevationLoss,
    this.averageAccuracy,
    this.weatherCondition,
    this.temperature,
    this.notes,
    this.tags,
    this.routeName,
    this.routeType,
    this.stopsCount,
    this.fuelConsumption,
    this.co2Emissions,
    this.deviceInfo,
    this.appVersion,
    this.customData,
  });

  Map<String, dynamic> toMap() => {
    'start_location': {
      'lat': originLatitude ?? 0.0,
      'lng': originLongitude ?? 0.0,
    },
    'end_location': {
      'lat': destinationLatitude ?? 0.0,
      'lng': destinationLongitude ?? 0.0,
    },
    'distance_km': distanceMeters / 1000, // Convert meters to km
    'duration_min': endedAt != null
        ? endedAt!.difference(startedAt).inMinutes
        : 0,
    'timestamp': startedAt.toIso8601String(),
    'mode': mode.name,
    'purpose': purpose.name,
    'companions': companions.toMap(),
    'is_recurring': isRecurring,
    if (destinationRegion != null) 'destination_region': destinationRegion,
    if (originRegion != null) 'origin_region': originRegion,
    if (tripNumber != null) 'trip_number': tripNumber,
    if (chainId != null) 'chain_id': chainId,
    if (notes != null) 'notes': notes,
  };

  static TripSummary fromSupabase(Map<String, dynamic> data) {
    final startLocation = data['start_location'] as Map<String, dynamic>? ?? {};
    final endLocation = data['end_location'] as Map<String, dynamic>? ?? {};
    final timestamp = DateTime.parse(data['timestamp'] as String);
    final durationMin = (data['duration_min'] as num?)?.toInt() ?? 0;

    return TripSummary(
      id: data['id'] as String,
      startedAt: timestamp,
      endedAt: durationMin > 0
          ? timestamp.add(Duration(minutes: durationMin))
          : null,
      distanceMeters:
          ((data['distance_km'] as num?)?.toDouble() ?? 0.0) *
          1000, // Convert km to meters
      mode: TripMode.values.firstWhere(
        (m) => m.name == (data['mode'] as String? ?? 'unknown'),
        orElse: () => TripMode.unknown,
      ),
      purpose: TripPurpose.values.firstWhere(
        (p) => p.name == (data['purpose'] as String? ?? 'unknown'),
        orElse: () => TripPurpose.unknown,
      ),
      companions: Companions.fromMap(
        data['companions'] as Map<String, dynamic>?,
      ),
      isRecurring: (data['is_recurring'] as bool?) ?? false,
      timezoneOffsetMinutes: timestamp.timeZoneOffset.inMinutes,
      destinationRegion: data['destination_region'] as String?,
      originRegion: data['origin_region'] as String?,
      tripNumber: data['trip_number'] as String?,
      chainId: data['chain_id'] as String?,
      // Enhanced destination information
      destinationName: data['destination_name'] as String?,
      destinationAddress: data['destination_address'] as String?,
      destinationLatitude: (endLocation['lat'] as num?)?.toDouble(),
      destinationLongitude: (endLocation['lng'] as num?)?.toDouble(),
      destinationPlaceId: data['destination_place_id'] as String?,
      originName: data['origin_name'] as String?,
      originAddress: data['origin_address'] as String?,
      originLatitude: (startLocation['lat'] as num?)?.toDouble(),
      originLongitude: (startLocation['lng'] as num?)?.toDouble(),
      originPlaceId: data['origin_place_id'] as String?,
      notes: data['notes'] as String?,
    );
  }

  static TripSummary fromMap(Map<String, dynamic> map) {
    return TripSummary(
      id: map['id'] as String,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: map['endedAt'] != null
          ? DateTime.parse(map['endedAt'] as String)
          : null,
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      mode: TripMode.values.firstWhere(
        (m) => m.name == (map['mode'] as String? ?? 'unknown'),
        orElse: () => TripMode.unknown,
      ),
      purpose: TripPurpose.values.firstWhere(
        (p) => p.name == (map['purpose'] as String? ?? 'unknown'),
        orElse: () => TripPurpose.unknown,
      ),
      companions: Companions.fromMap(
        map['companions'] as Map<String, dynamic>?,
      ),
      isRecurring: (map['isRecurring'] as bool?) ?? false,
      timezoneOffsetMinutes:
          (map['timezoneOffsetMinutes'] as num?)?.toInt() ?? 0,
      destinationRegion: map['destinationRegion'] as String?,
      originRegion: map['originRegion'] as String?,
      tripNumber: map['tripNumber'] as String?,
      chainId: map['chainId'] as String?,
      // Enhanced destination information
      destinationName: map['destinationName'] as String?,
      destinationAddress: map['destinationAddress'] as String?,
      destinationLatitude: (map['destinationLatitude'] as num?)?.toDouble(),
      destinationLongitude: (map['destinationLongitude'] as num?)?.toDouble(),
      destinationPlaceId: map['destinationPlaceId'] as String?,
      originName: map['originName'] as String?,
      originAddress: map['originAddress'] as String?,
      originLatitude: (map['originLatitude'] as num?)?.toDouble(),
      originLongitude: (map['originLongitude'] as num?)?.toDouble(),
      originPlaceId: map['originPlaceId'] as String?,
      // Additional detailed trip information
      averageSpeed: (map['averageSpeed'] as num?)?.toDouble(),
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble(),
      minSpeed: (map['minSpeed'] as num?)?.toDouble(),
      totalPoints: (map['totalPoints'] as num?)?.toInt(),
      totalElevationGain: (map['totalElevationGain'] as num?)?.toDouble(),
      totalElevationLoss: (map['totalElevationLoss'] as num?)?.toDouble(),
      averageAccuracy: (map['averageAccuracy'] as num?)?.toDouble(),
      weatherCondition: map['weatherCondition'] as String?,
      temperature: (map['temperature'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>(),
      routeName: map['routeName'] as String?,
      routeType: map['routeType'] as String?,
      stopsCount: (map['stopsCount'] as num?)?.toInt(),
      fuelConsumption: (map['fuelConsumption'] as num?)?.toDouble(),
      co2Emissions: (map['co2Emissions'] as num?)?.toDouble(),
      deviceInfo: map['deviceInfo'] as String?,
      appVersion: map['appVersion'] as String?,
      customData: map['customData'] as Map<String, dynamic>?,
    );
  }

  /// Get route points for this trip (requires external service call)
  /// This method is a placeholder - actual implementation would call the trip service
  Future<List<TripPoint>> getRoutePoints() async {
    // This would typically call a service to get the route points
    // For now, return an empty list as a placeholder
    return [];
  }

  /// Get route summary information
  Map<String, dynamic> getRouteSummary() {
    return {
      'hasRouteData': totalPoints != null && totalPoints! > 0,
      'totalPoints': totalPoints ?? 0,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'minSpeed': minSpeed,
      'routeName': routeName,
      'routeType': routeType,
      'stopsCount': stopsCount,
      'totalElevationGain': totalElevationGain,
      'totalElevationLoss': totalElevationLoss,
      'averageAccuracy': averageAccuracy,
    };
  }
}

class TripPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final int timezoneOffsetMinutes; // local timezone offset in minutes
  final double? accuracy; // GPS accuracy in meters
  final double? altitude; // altitude in meters
  final double? speed; // speed in m/s
  final double? heading; // heading in degrees
  final double? speedAccuracy; // speed accuracy in m/s
  final double? headingAccuracy; // heading accuracy in degrees
  final String? address; // reverse geocoded address
  final String? placeName; // nearby place name
  final String? placeId; // Google Places ID
  final String? roadName; // road/street name
  final String? city; // city name
  final String? country; // country name
  final String? postalCode; // postal code
  final Map<String, dynamic>? metadata; // additional metadata

  const TripPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.timezoneOffsetMinutes,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.speedAccuracy,
    this.headingAccuracy,
    this.address,
    this.placeName,
    this.placeId,
    this.roadName,
    this.city,
    this.country,
    this.postalCode,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'timezone_offset_minutes': timezoneOffsetMinutes,
    if (accuracy != null) 'accuracy': accuracy,
    if (altitude != null) 'altitude': altitude,
    if (speed != null) 'speed': speed,
    if (heading != null) 'heading': heading,
    if (speedAccuracy != null) 'speed_accuracy': speedAccuracy,
    if (headingAccuracy != null) 'heading_accuracy': headingAccuracy,
    if (address != null) 'address': address,
    if (placeName != null) 'place_name': placeName,
    if (placeId != null) 'place_id': placeId,
    if (roadName != null) 'road_name': roadName,
    if (city != null) 'city': city,
    if (country != null) 'country': country,
    if (postalCode != null) 'postal_code': postalCode,
    if (metadata != null) 'metadata': metadata,
  };

  static TripPoint fromMap(Map<String, dynamic> map) {
    return TripPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      timezoneOffsetMinutes:
          (map['timezone_offset_minutes'] as num?)?.toInt() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      speedAccuracy: (map['speed_accuracy'] as num?)?.toDouble(),
      headingAccuracy: (map['heading_accuracy'] as num?)?.toDouble(),
      address: map['address'] as String?,
      placeName: map['place_name'] as String?,
      placeId: map['place_id'] as String?,
      roadName: map['road_name'] as String?,
      city: map['city'] as String?,
      country: map['country'] as String?,
      postalCode: map['postal_code'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
