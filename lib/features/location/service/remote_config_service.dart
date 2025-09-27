import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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
      autoStartSpeedThreshold: (map['autoStartSpeedThreshold'] as num?)?.toDouble() ?? 1.2,
      autoStartTimeThreshold: (map['autoStartTimeThreshold'] as num?)?.toInt() ?? 120,
      stopRadiusThreshold: (map['stopRadiusThreshold'] as num?)?.toDouble() ?? 50.0,
      stopTimeThreshold: (map['stopTimeThreshold'] as num?)?.toInt() ?? 180,
      minDistanceThreshold: (map['minDistanceThreshold'] as num?)?.toDouble() ?? 150.0,
      minDurationThreshold: (map['minDurationThreshold'] as num?)?.toInt() ?? 300,
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
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  
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
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // Set default values as individual parameters to avoid Map issues
    await _remoteConfig.setDefaults({
      'autoStartSpeedThreshold': _defaultConfig.autoStartSpeedThreshold,
      'autoStartTimeThreshold': _defaultConfig.autoStartTimeThreshold,
      'stopRadiusThreshold': _defaultConfig.stopRadiusThreshold,
      'stopTimeThreshold': _defaultConfig.stopTimeThreshold,
      'minDistanceThreshold': _defaultConfig.minDistanceThreshold,
      'minDurationThreshold': _defaultConfig.minDurationThreshold,
      'distanceFilter': _defaultConfig.distanceFilter,
      'intervalDuration': _defaultConfig.intervalDuration,
    });

    // Fetch and activate
    await _remoteConfig.fetchAndActivate();
  }

  static TripDetectionConfig getTripDetectionConfig() {
    try {
      return TripDetectionConfig(
        autoStartSpeedThreshold: _remoteConfig.getDouble('autoStartSpeedThreshold'),
        autoStartTimeThreshold: _remoteConfig.getInt('autoStartTimeThreshold'),
        stopRadiusThreshold: _remoteConfig.getDouble('stopRadiusThreshold'),
        stopTimeThreshold: _remoteConfig.getInt('stopTimeThreshold'),
        minDistanceThreshold: _remoteConfig.getDouble('minDistanceThreshold'),
        minDurationThreshold: _remoteConfig.getInt('minDurationThreshold'),
        distanceFilter: _remoteConfig.getDouble('distanceFilter'),
        intervalDuration: _remoteConfig.getInt('intervalDuration'),
      );
    } catch (e) {
      return _defaultConfig;
    }
  }

  static Future<void> refresh() async {
    await _remoteConfig.fetchAndActivate();
  }

  static Stream<TripDetectionConfig> watchTripDetectionConfig() {
    return _remoteConfig.onConfigUpdated.map((_) => getTripDetectionConfig());
  }
}

final tripDetectionConfigProvider = StreamProvider<TripDetectionConfig>((ref) {
  return RemoteConfigService.watchTripDetectionConfig();
});

final currentTripDetectionConfigProvider = Provider<TripDetectionConfig>((ref) {
  return RemoteConfigService.getTripDetectionConfig();
});


