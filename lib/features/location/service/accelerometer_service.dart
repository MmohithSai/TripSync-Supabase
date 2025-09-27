import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

class AccelerometerData {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  const AccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });

  factory AccelerometerData.fromEvent(AccelerometerEvent event) {
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    return AccelerometerData(
      x: event.x,
      y: event.y,
      z: event.z,
      magnitude: magnitude,
      timestamp: DateTime.now(),
    );
  }
}

class MovementState {
  final bool isMoving;
  final double confidence;
  final double averageMagnitude;
  final int sampleCount;

  const MovementState({
    required this.isMoving,
    required this.confidence,
    required this.averageMagnitude,
    required this.sampleCount,
  });
}

class AccelerometerService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<AccelerometerData> _recentData = [];
  final int _maxSamples = 50; // Keep last 50 samples
  final Duration _sampleWindow = const Duration(seconds: 5);
  
  // Movement detection thresholds
  static const double _movementThreshold = 0.5; // m/s²
  static const double _stationaryThreshold = 0.1; // m/s²
  static const int _minSamplesForDetection = 10;
  static const double _confidenceThreshold = 0.7;

  final StreamController<MovementState> _movementController = StreamController<MovementState>.broadcast();
  Stream<MovementState> get movementStream => _movementController.stream;

  /// Start monitoring accelerometer data
  void startMonitoring() {
    if (_subscription != null) return;
    
    _subscription = accelerometerEvents.listen(
      _onAccelerometerEvent,
      onError: (error) {
        print('Accelerometer error: $error');
      },
    );
  }

  /// Stop monitoring accelerometer data
  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _recentData.clear();
  }

  /// Get current movement state
  MovementState getCurrentMovementState() {
    if (_recentData.length < _minSamplesForDetection) {
      return const MovementState(
        isMoving: false,
        confidence: 0.0,
        averageMagnitude: 0.0,
        sampleCount: 0,
      );
    }

    final now = DateTime.now();
    final recentSamples = _recentData.where((data) => 
      now.difference(data.timestamp) <= _sampleWindow
    ).toList();

    if (recentSamples.isEmpty) {
      return const MovementState(
        isMoving: false,
        confidence: 0.0,
        averageMagnitude: 0.0,
        sampleCount: 0,
      );
    }

    final averageMagnitude = recentSamples.fold(0.0, (sum, data) => sum + data.magnitude) / recentSamples.length;
    final variance = _calculateVariance(recentSamples, averageMagnitude);
    final isMoving = _detectMovement(recentSamples, averageMagnitude, variance);
    final confidence = _calculateConfidence(recentSamples, averageMagnitude, variance);

    return MovementState(
      isMoving: isMoving,
      confidence: confidence,
      averageMagnitude: averageMagnitude,
      sampleCount: recentSamples.length,
    );
  }

  /// Get smoothed accelerometer data
  AccelerometerData getSmoothedData() {
    if (_recentData.isEmpty) {
      return AccelerometerData(
        x: 0.0,
        y: 0.0,
        z: 0.0,
        magnitude: 0.0,
        timestamp: DateTime.now(),
      );
    }

    final recentSamples = _recentData.take(10).toList();
    final avgX = recentSamples.fold(0.0, (sum, data) => sum + data.x) / recentSamples.length;
    final avgY = recentSamples.fold(0.0, (sum, data) => sum + data.y) / recentSamples.length;
    final avgZ = recentSamples.fold(0.0, (sum, data) => sum + data.z) / recentSamples.length;
    final magnitude = sqrt(avgX * avgX + avgY * avgY + avgZ * avgZ);

    return AccelerometerData(
      x: avgX,
      y: avgY,
      z: avgZ,
      magnitude: magnitude,
      timestamp: DateTime.now(),
    );
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final data = AccelerometerData.fromEvent(event);
    
    // Add to recent data
    _recentData.add(data);
    
    // Keep only recent samples
    if (_recentData.length > _maxSamples) {
      _recentData.removeAt(0);
    }
    
    // Remove old samples
    final now = DateTime.now();
    _recentData.removeWhere((sample) => 
      now.difference(sample.timestamp) > _sampleWindow
    );
    
    // Analyze movement
    if (_recentData.length >= _minSamplesForDetection) {
      final movementState = getCurrentMovementState();
      _movementController.add(movementState);
    }
  }

  bool _detectMovement(List<AccelerometerData> samples, double averageMagnitude, double variance) {
    // Check if average magnitude indicates movement
    if (averageMagnitude > _movementThreshold) {
      return true;
    }
    
    // Check for sudden changes (variance) that might indicate movement
    if (variance > 0.5 && averageMagnitude > _stationaryThreshold) {
      return true;
    }
    
    // Check for patterns that indicate walking or other movement
    return _detectMovementPattern(samples);
  }

  bool _detectMovementPattern(List<AccelerometerData> samples) {
    if (samples.length < 5) return false;
    
    // Look for periodic patterns that might indicate walking
    final magnitudes = samples.map((s) => s.magnitude).toList();
    final peaks = _findPeaks(magnitudes);
    
    // If we have multiple peaks in a short time, likely moving
    return peaks.length >= 3;
  }

  List<int> _findPeaks(List<double> data) {
    final peaks = <int>[];
    
    for (int i = 1; i < data.length - 1; i++) {
      if (data[i] > data[i - 1] && data[i] > data[i + 1] && data[i] > _stationaryThreshold) {
        peaks.add(i);
      }
    }
    
    return peaks;
  }

  double _calculateVariance(List<AccelerometerData> samples, double mean) {
    if (samples.isEmpty) return 0.0;
    
    final sumSquaredDiffs = samples.fold(0.0, (sum, data) => 
      sum + pow(data.magnitude - mean, 2)
    );
    
    return sumSquaredDiffs / samples.length;
  }

  double _calculateConfidence(List<AccelerometerData> samples, double averageMagnitude, double variance) {
    if (samples.isEmpty) return 0.0;
    
    // Base confidence on how clear the signal is
    double confidence = 0.0;
    
    // Higher magnitude = higher confidence in movement detection
    if (averageMagnitude > _movementThreshold) {
      confidence += 0.4;
    } else if (averageMagnitude > _stationaryThreshold) {
      confidence += 0.2;
    }
    
    // Lower variance = more consistent signal = higher confidence
    if (variance < 0.1) {
      confidence += 0.3;
    } else if (variance < 0.5) {
      confidence += 0.1;
    }
    
    // More samples = higher confidence
    final sampleConfidence = (samples.length / _minSamplesForDetection).clamp(0.0, 1.0) * 0.3;
    confidence += sampleConfidence;
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Detect if the device is in a vehicle (car, bus, etc.)
  bool detectVehicleMovement() {
    final recentSamples = _recentData.take(20).toList();
    if (recentSamples.length < 10) return false;
    
    final averageMagnitude = recentSamples.fold(0.0, (sum, data) => sum + data.magnitude) / recentSamples.length;
    final variance = _calculateVariance(recentSamples, averageMagnitude);
    
    // Vehicle movement typically has:
    // - Moderate to high magnitude
    // - Low variance (smooth movement)
    // - Consistent patterns
    return averageMagnitude > 0.3 && 
           averageMagnitude < 2.0 && 
           variance < 0.3;
  }

  /// Detect if the device is stationary
  bool detectStationary() {
    final recentSamples = _recentData.take(10).toList();
    if (recentSamples.length < 5) return false;
    
    final averageMagnitude = recentSamples.fold(0.0, (sum, data) => sum + data.magnitude) / recentSamples.length;
    final variance = _calculateVariance(recentSamples, averageMagnitude);
    
    // Stationary typically has:
    // - Low magnitude
    // - Low variance
    return averageMagnitude < _stationaryThreshold && variance < 0.1;
  }

  /// Get movement classification
  String getMovementClassification() {
    final state = getCurrentMovementState();
    
    if (!state.isMoving || state.confidence < _confidenceThreshold) {
      return 'stationary';
    }
    
    if (detectVehicleMovement()) {
      return 'vehicle';
    }
    
    if (state.averageMagnitude > 1.5) {
      return 'active'; // Running, cycling, etc.
    }
    
    return 'walking';
  }

  void dispose() {
    stopMonitoring();
    _movementController.close();
  }
}

// Provider for accelerometer service
final accelerometerServiceProvider = Provider<AccelerometerService>((ref) {
  final service = AccelerometerService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Provider for current movement state
final movementStateProvider = StreamProvider<MovementState>((ref) {
  final service = ref.watch(accelerometerServiceProvider);
  service.startMonitoring();
  return service.movementStream;
});

// Provider for current accelerometer data
final accelerometerDataProvider = Provider<AccelerometerData>((ref) {
  final service = ref.watch(accelerometerServiceProvider);
  return service.getSmoothedData();
});