import 'dart:convert';

/// Model for sensor data sent to the backend Trip Recording System
class SensorDataModel {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speedMps;
  final double? altitude;
  final double? bearing;
  final String? activityType;
  final double? activityConfidence;
  final double? accelerometerX;
  final double? accelerometerY;
  final double? accelerometerZ;
  final String? deviceId;
  final String? platform;
  final double timestamp;

  SensorDataModel({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speedMps,
    this.altitude,
    this.bearing,
    this.activityType,
    this.activityConfidence,
    this.accelerometerX,
    this.accelerometerY,
    this.accelerometerZ,
    this.deviceId,
    this.platform,
    double? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch / 1000;

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      if (speedMps != null) 'speed_mps': speedMps,
      if (altitude != null) 'altitude': altitude,
      if (bearing != null) 'bearing': bearing,
      if (activityType != null) 'activity_type': activityType,
      if (activityConfidence != null) 'activity_confidence': activityConfidence,
      if (accelerometerX != null) 'accelerometer_x': accelerometerX,
      if (accelerometerY != null) 'accelerometer_y': accelerometerY,
      if (accelerometerZ != null) 'accelerometer_z': accelerometerZ,
      if (deviceId != null) 'device_id': deviceId,
      if (platform != null) 'platform': platform,
      'timestamp': timestamp,
    };
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from Position (Geolocator)
  factory SensorDataModel.fromPosition(
    dynamic position, {
    String? platform,
    String? deviceId,
    String? activityType,
    double? activityConfidence,
    double? accelerometerX,
    double? accelerometerY,
    double? accelerometerZ,
  }) {
    return SensorDataModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy.isFinite ? position.accuracy : 100.0,
      speedMps: position.speed.isFinite ? position.speed : null,
      altitude: position.altitude.isFinite ? position.altitude : null,
      bearing: position.heading.isFinite ? position.heading : null,
      platform: platform,
      deviceId: deviceId,
      activityType: activityType,
      activityConfidence: activityConfidence,
      accelerometerX: accelerometerX,
      accelerometerY: accelerometerY,
      accelerometerZ: accelerometerZ,
    );
  }

  @override
  String toString() {
    return 'SensorData(lat: ${latitude.toStringAsFixed(4)}, '
        'lng: ${longitude.toStringAsFixed(4)}, '
        'speed: ${speedMps?.toStringAsFixed(1)} m/s, '
        'activity: $activityType)';
  }
}

/// Response model for trip state from backend
class TripStateResponse {
  final String currentState;
  final String? tripId;
  final double stateDurationSeconds;
  final double speedKmh;
  final String? activityType;
  final bool stateChanged;

  TripStateResponse({
    required this.currentState,
    this.tripId,
    required this.stateDurationSeconds,
    required this.speedKmh,
    this.activityType,
    required this.stateChanged,
  });

  factory TripStateResponse.fromJson(Map<String, dynamic> json) {
    return TripStateResponse(
      currentState: json['current_state'] ?? 'unknown',
      tripId: json['trip_id'],
      stateDurationSeconds: (json['state_duration_seconds'] ?? 0).toDouble(),
      speedKmh: (json['speed_kmh'] ?? 0).toDouble(),
      activityType: json['activity_type'],
      stateChanged: json['state_changed'] ?? false,
    );
  }

  bool get isActive => currentState == 'active';
  bool get isIdle => currentState == 'idle';
}

/// Complete response from sensor data endpoint
class SensorDataResponse {
  final bool success;
  final TripStateResponse? tripState;
  final Map<String, dynamic>? processedSensorData;
  final String timestamp;

  SensorDataResponse({
    required this.success,
    this.tripState,
    this.processedSensorData,
    required this.timestamp,
  });

  factory SensorDataResponse.fromJson(Map<String, dynamic> json) {
    return SensorDataResponse(
      success: json['success'] ?? false,
      tripState: json['state_machine'] != null
          ? TripStateResponse.fromJson(json['state_machine'])
          : null,
      processedSensorData: json['processed_sensor_data'],
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}


