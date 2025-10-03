import 'package:flutter_riverpod/flutter_riverpod.dart';

class TripDetectionConfig {
  final double autoStartSpeedThreshold; // m/s
  final int autoStartTimeThreshold; // seconds
  final double stopRadiusThreshold; // meters
  final int stopTimeThreshold; // seconds
  final double minDistanceThreshold; // meters
  final int minDurationThreshold; // seconds
  final double distanceFilter; // meters
  final int intervalDuration; // seconds

  const TripDetectionConfig({
    required this.autoStartSpeedThreshold,
    required this.autoStartTimeThreshold,
    required this.stopRadiusThreshold,
    required this.stopTimeThreshold,
    required this.minDistanceThreshold,
    required this.minDurationThreshold,
    required this.distanceFilter,
    required this.intervalDuration,
  });

  factory TripDetectionConfig.fromMap(Map<String, dynamic> map) {
    return TripDetectionConfig(
      autoStartSpeedThreshold:
          (map['autoStartSpeedThreshold'] as num?)?.toDouble() ?? 0.8,
      autoStartTimeThreshold:
          (map['autoStartTimeThreshold'] as num?)?.toInt() ?? 60,
      stopRadiusThreshold:
          (map['stopRadiusThreshold'] as num?)?.toDouble() ?? 30.0,
      stopTimeThreshold: (map['stopTimeThreshold'] as num?)?.toInt() ?? 120,
      minDistanceThreshold:
          (map['minDistanceThreshold'] as num?)?.toDouble() ?? 50.0,
      minDurationThreshold:
          (map['minDurationThreshold'] as num?)?.toInt() ?? 60,
      distanceFilter: (map['distanceFilter'] as num?)?.toDouble() ?? 5.0,
      intervalDuration: (map['intervalDuration'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoStartSpeedThreshold': autoStartSpeedThreshold,
      'autoStartTimeThreshold': autoStartTimeThreshold,
      'stopRadiusThreshold': stopRadiusThreshold,
      'stopTimeThreshold': stopTimeThreshold,
      'minDistanceThreshold': minDistanceThreshold,
      'minDurationThreshold': minDurationThreshold,
      'distanceFilter': distanceFilter,
      'intervalDuration': intervalDuration,
    };
  }
}

class RemoteConfigService {
  static const TripDetectionConfig _defaultConfig = TripDetectionConfig(
    autoStartSpeedThreshold: 0.8, // Reduced for more sensitive trip detection
    autoStartTimeThreshold: 60, // Reduced for faster trip start
    stopRadiusThreshold: 30.0, // Reduced for more sensitive stop detection
    stopTimeThreshold: 120, // Reduced for faster trip end detection
    minDistanceThreshold: 50.0, // Reduced to capture shorter trips
    minDurationThreshold: 60, // Reduced to capture shorter trips
    distanceFilter: 5.0, // Reduced for more frequent location updates
    intervalDuration: 3, // Reduced for more frequent updates
  );

  static Future<void> initialize() async {
    // TODO: Implement Supabase Edge Function or local storage for remote config
    // For now, using default values
  }

  static TripDetectionConfig getTripDetectionConfig() {
    // TODO: Fetch from Supabase or local storage
    return _defaultConfig;
  }

  static Future<void> refresh() async {
    // TODO: Implement refresh from Supabase
  }

  static Stream<TripDetectionConfig> watchTripDetectionConfig() {
    // TODO: Implement real-time updates from Supabase
    return Stream.value(_defaultConfig);
  }
}

final tripDetectionConfigProvider = StreamProvider<TripDetectionConfig>((ref) {
  return RemoteConfigService.watchTripDetectionConfig();
});

final currentTripDetectionConfigProvider = Provider<TripDetectionConfig>((ref) {
  return RemoteConfigService.getTripDetectionConfig();
});
