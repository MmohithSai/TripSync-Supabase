import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Response wrapper for backend API calls
class BackendResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  BackendResponse._({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory BackendResponse.success(T data, {int? statusCode}) {
    return BackendResponse._(success: true, data: data, statusCode: statusCode);
  }

  factory BackendResponse.error(String error, {int? statusCode}) {
    return BackendResponse._(
      success: false,
      error: error,
      statusCode: statusCode,
    );
  }
}

class BackendService {
  // For local development - change this for production
  // Using localhost with adb port forwarding
  static const String baseUrl = 'http://localhost:8000';

  // For production, use your deployed backend URL:
  // static const String baseUrl = 'https://your-backend-domain.com';

  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  /// Get authorization headers with Supabase JWT token
  Future<Map<String, String>> _getHeaders() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (kDebugMode && token != null) {
        print('🔑 Using JWT token: ${token.substring(0, 20)}...');
      }

      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting auth headers: $e');
      }
      return {'Content-Type': 'application/json', 'Accept': 'application/json'};
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session?.accessToken != null;
      if (kDebugMode) {
        print(
          '🔐 Authentication status: ${isAuth ? "✅ Authenticated" : "❌ Not authenticated"}',
        );
      }
      return isAuth;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking authentication: $e');
      }
      return false;
    }
  }

  /// Get current user ID
  String? get currentUserId {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.user.id;
  }

  /// Handle HTTP response with proper error handling
  BackendResponse<Map<String, dynamic>> _handleResponse(
    http.Response response,
    String operation,
  ) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (kDebugMode) {
          print('✅ $operation success: ${response.statusCode}');
        }
        return BackendResponse.success(data, statusCode: response.statusCode);
      } else if (response.statusCode == 401) {
        if (kDebugMode) {
          print('🔒 Authentication error for $operation');
        }
        return BackendResponse.error(
          'Authentication failed. Please log in again.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 403) {
        return BackendResponse.error(
          'Access denied. Check your permissions.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode >= 500) {
        return BackendResponse.error(
          'Server error. Please try again later.',
          statusCode: response.statusCode,
        );
      } else {
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'Unknown error';
        if (kDebugMode) {
          print('❌ $operation failed: ${response.statusCode} - $errorBody');
        }
        return BackendResponse.error(
          'Request failed: $errorBody',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing $operation response: $e');
      }
      return BackendResponse.error('Failed to parse response: $e');
    }
  }

  /// Test backend connection
  Future<Map<String, dynamic>?> testConnection() async {
    try {
      if (kDebugMode) {
        print('🔗 Testing backend connection to $baseUrl...');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: await _getHeaders(),
      );

      if (kDebugMode) {
        print('🔗 Backend response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Backend connection successful!');
        }
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Backend connection error: $e');
      }
      return null;
    }
  }

  /// Send sensor data to Trip Recording System
  Future<BackendResponse<Map<String, dynamic>>> sendSensorData({
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedMps,
    double? altitude,
    double? bearing,
    String? activityType,
    double? activityConfidence,
    double? accelerometerX,
    double? accelerometerY,
    double? accelerometerZ,
    String? deviceId,
    String? platform,
  }) async {
    try {
      // Check authentication first
      if (!isAuthenticated) {
        return BackendResponse.error('Not authenticated. Please log in first.');
      }

      final data = {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        if (speedMps != null) 'speed_mps': speedMps,
        if (altitude != null) 'altitude': altitude,
        if (bearing != null) 'bearing': bearing,
        if (activityType != null) 'activity_type': activityType,
        if (activityConfidence != null)
          'activity_confidence': activityConfidence,
        if (accelerometerX != null) 'accelerometer_x': accelerometerX,
        if (accelerometerY != null) 'accelerometer_y': accelerometerY,
        if (accelerometerZ != null) 'accelerometer_z': accelerometerZ,
        if (deviceId != null) 'device_id': deviceId,
        if (platform != null) 'platform': platform,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      };

      if (kDebugMode) {
        print(
          '📡 Sending sensor data: lat=${latitude.toStringAsFixed(4)}, lng=${longitude.toStringAsFixed(4)}, speed=${speedMps?.toStringAsFixed(1)}',
        );
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/trip-recording/sensor-data'),
            headers: await _getHeaders(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response, 'sensor data');
    } on SocketException {
      return BackendResponse.error(
        'Network error. Check your connection and ensure backend is running.',
      );
    } on HttpException {
      return BackendResponse.error('HTTP error occurred.');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Send sensor data error: $e');
      }
      return BackendResponse.error('Failed to send sensor data: $e');
    }
  }

  /// Manually start a trip
  Future<Map<String, dynamic>?> startTrip() async {
    try {
      if (kDebugMode) {
        print('🌐 Sending POST to $baseUrl/api/v1/trip-recording/trip/start');
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/trip-recording/trip/start'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('🌐 Start trip response: ${response.statusCode}');
        print('🌐 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'error': 'HTTP ${response.statusCode}: ${response.body}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting trip: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Manually stop a trip
  Future<Map<String, dynamic>?> stopTrip() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/trip-recording/trip/stop'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Stop trip error: $e');
      return null;
    }
  }

  /// Get current trip state
  Future<Map<String, dynamic>?> getTripState() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/trip-recording/trip/state'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get trip state error: $e');
      return null;
    }
  }

  /// Get system status
  Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/trip-recording/status/all'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get system status error: $e');
      return null;
    }
  }

  /// Add GPS point to active trip
  Future<bool> addGpsPoint({
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedKmh,
    double? altitude,
    double? bearing,
  }) async {
    try {
      final data = {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        if (speedKmh != null) 'speed_kmh': speedKmh,
        if (altitude != null) 'altitude': altitude,
        if (bearing != null) 'bearing': bearing,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/trip-recording/gps-point'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Add GPS point error: $e');
      return false;
    }
  }
}
