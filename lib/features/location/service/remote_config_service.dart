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
          (map['autoStartSpeedThreshold'] as num?)?.toDouble() ?? 1.2,
      autoStartTimeThreshold:
          (map['autoStartTimeThreshold'] as num?)?.toInt() ?? 120,
      stopRadiusThreshold:
          (map['stopRadiusThreshold'] as num?)?.toDouble() ?? 50.0,
      stopTimeThreshold: (map['stopTimeThreshold'] as num?)?.toInt() ?? 180,
      minDistanceThreshold:
          (map['minDistanceThreshold'] as num?)?.toDouble() ?? 150.0,
      minDurationThreshold:
          (map['minDurationThreshold'] as num?)?.toInt() ?? 300,
      distanceFilter: (map['distanceFilter'] as num?)?.toDouble() ?? 25.0,
      intervalDuration: (map['intervalDuration'] as num?)?.toInt() ?? 5,
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
    autoStartSpeedThreshold: 1.2,
    autoStartTimeThreshold: 120,
    stopRadiusThreshold: 50.0,
    stopTimeThreshold: 180,
    minDistanceThreshold: 150.0,
    minDurationThreshold: 300,
    distanceFilter: 25.0,
    intervalDuration: 5,
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
