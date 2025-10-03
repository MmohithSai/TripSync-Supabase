import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/backend_service.dart';
import '../models/sensor_data_model.dart';

/// Complete example of backend integration
class BackendIntegrationExample extends StatefulWidget {
  const BackendIntegrationExample({super.key});

  @override
  State<BackendIntegrationExample> createState() =>
      _BackendIntegrationExampleState();
}

class _BackendIntegrationExampleState extends State<BackendIntegrationExample> {
  final BackendService _backendService = BackendService();
  String _status = 'Ready';
  String? _lastTripState;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backend Integration Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Authentication Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authentication Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Authenticated: ${_backendService.isAuthenticated ? "✅ Yes" : "❌ No"}',
                    ),
                    Text(
                      'User ID: ${_backendService.currentUserId ?? "Not logged in"}',
                    ),
                    if (!_backendService.isAuthenticated) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showLoginPrompt,
                        child: const Text('Login Required'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_lastTripState != null) ...[
                      const SizedBox(height: 8),
                      Text('Last Trip State: $_lastTripState'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton(
                onPressed: _testConnection,
                child: const Text('Test Backend Connection'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _sendTestSensorData,
                child: const Text('Send Test Sensor Data'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _getCurrentLocationAndSend,
                child: const Text('Get Current Location & Send'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'You need to be logged in to use the backend API. Please log in through the app first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing connection...';
    });

    try {
      final result = await _backendService.testConnection();
      setState(() {
        _status = result != null
            ? '✅ Backend connected: ${result['status']}'
            : '❌ Backend not reachable';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Connection error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestSensorData() async {
    if (!_backendService.isAuthenticated) {
      _showLoginPrompt();
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Sending test sensor data...';
    });

    try {
      // Create test sensor data
      final sensorData = SensorDataModel(
        latitude: 37.7749, // San Francisco coordinates
        longitude: -122.4194,
        accuracy: 5.0,
        speedMps: 2.5, // Walking speed
        activityType: 'walking',
        activityConfidence: 0.8,
        platform: 'flutter_test',
      );

      print('📤 Sending: ${sensorData.toString()}');

      final result = await _backendService.sendSensorData(
        latitude: sensorData.latitude,
        longitude: sensorData.longitude,
        accuracy: sensorData.accuracy,
        speedMps: sensorData.speedMps,
        activityType: sensorData.activityType,
        activityConfidence: sensorData.activityConfidence,
        platform: sensorData.platform,
      );

      if (result.success && result.data != null) {
        final response = SensorDataResponse.fromJson(result.data!);
        setState(() {
          _status = '✅ Sensor data sent successfully';
          _lastTripState = response.tripState?.currentState;
        });

        if (response.tripState?.stateChanged == true) {
          _showTripStateChange(response.tripState!);
        }
      } else {
        setState(() {
          _status = '❌ Failed: ${result.error}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocationAndSend() async {
    if (!_backendService.isAuthenticated) {
      _showLoginPrompt();
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Getting current location...';
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _status = 'Sending real location data...';
      });

      // Create sensor data from real position
      final sensorData = SensorDataModel.fromPosition(
        position,
        platform: 'flutter',
        activityType: 'unknown',
      );

      print('📍 Real location: ${sensorData.toString()}');

      final result = await _backendService.sendSensorData(
        latitude: sensorData.latitude,
        longitude: sensorData.longitude,
        accuracy: sensorData.accuracy,
        speedMps: sensorData.speedMps,
        altitude: sensorData.altitude,
        bearing: sensorData.bearing,
        activityType: sensorData.activityType,
        platform: sensorData.platform,
      );

      if (result.success && result.data != null) {
        final response = SensorDataResponse.fromJson(result.data!);
        setState(() {
          _status = '✅ Real location sent successfully';
          _lastTripState = response.tripState?.currentState;
        });

        if (response.tripState?.stateChanged == true) {
          _showTripStateChange(response.tripState!);
        }
      } else {
        setState(() {
          _status = '❌ Failed: ${result.error}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Location error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showTripStateChange(TripStateResponse tripState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚗 Trip State Changed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New State: ${tripState.currentState.toUpperCase()}'),
            if (tripState.tripId != null) Text('Trip ID: ${tripState.tripId}'),
            Text('Speed: ${tripState.speedKmh.toStringAsFixed(1)} km/h'),
            Text(
              'Duration: ${tripState.stateDurationSeconds.toStringAsFixed(0)}s',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// How to retrieve Supabase JWT token - Example functions
class SupabaseAuthExample {
  /// Get current JWT token
  static String? getCurrentJWTToken() {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  /// Check if user is authenticated
  static bool isUserAuthenticated() {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken != null;
  }

  /// Get current user info
  static User? getCurrentUser() {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.user;
  }

  /// Example: Login and get token
  static Future<String?> loginAndGetToken(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response.session?.accessToken;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Listen to auth state changes
  static void listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        print('✅ User logged in, JWT token available');
        print('🔑 Token: ${session.accessToken.substring(0, 20)}...');
      } else {
        print('❌ User logged out, no JWT token');
      }
    });
  }
}


