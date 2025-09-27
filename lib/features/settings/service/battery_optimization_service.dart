import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('battery_optimization');

  /// Check if battery optimization is enabled for the app
  static Future<bool> isBatteryOptimizationEnabled() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool isEnabled = await _channel.invokeMethod('isBatteryOptimizationEnabled');
      return isEnabled;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request to disable battery optimization
  static Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool success = await _channel.invokeMethod('requestDisableBatteryOptimization');
      return success;
    } catch (e) {
      debugPrint('Error requesting battery optimization disable: $e');
      return false;
    }
  }

  /// Check if the app has necessary permissions for background location
  static Future<bool> hasBackgroundLocationPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final status = await Permission.locationAlways.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking background location permission: $e');
      return false;
    }
  }

  /// Request background location permission
  static Future<bool> requestBackgroundLocationPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final status = await Permission.locationAlways.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting background location permission: $e');
      return false;
    }
  }

  /// Check if the app is whitelisted from battery optimization
  static Future<bool> isAppWhitelisted() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final bool isWhitelisted = await _channel.invokeMethod('isAppWhitelisted');
      return isWhitelisted;
    } catch (e) {
      debugPrint('Error checking app whitelist status: $e');
      return false;
    }
  }

  /// Get battery optimization status summary
  static Future<BatteryOptimizationStatus> getBatteryOptimizationStatus() async {
    if (!Platform.isAndroid) {
      return const BatteryOptimizationStatus(
        isOptimizationEnabled: false,
        hasBackgroundLocationPermission: true,
        isAppWhitelisted: true,
        needsAttention: false,
      );
    }

    try {
      final bool isOptimizationEnabled = await isBatteryOptimizationEnabled();
      final bool hasBackgroundLocation = await hasBackgroundLocationPermission();
      final bool isWhitelisted = await isAppWhitelisted();
      
      final needsAttention = isOptimizationEnabled || !hasBackgroundLocation || !isWhitelisted;
      
      return BatteryOptimizationStatus(
        isOptimizationEnabled: isOptimizationEnabled,
        hasBackgroundLocationPermission: hasBackgroundLocation,
        isAppWhitelisted: isWhitelisted,
        needsAttention: needsAttention,
      );
    } catch (e) {
      debugPrint('Error getting battery optimization status: $e');
      return const BatteryOptimizationStatus(
        isOptimizationEnabled: false,
        hasBackgroundLocationPermission: false,
        isAppWhitelisted: false,
        needsAttention: true,
      );
    }
  }
}

class BatteryOptimizationStatus {
  final bool isOptimizationEnabled;
  final bool hasBackgroundLocationPermission;
  final bool isAppWhitelisted;
  final bool needsAttention;

  const BatteryOptimizationStatus({
    required this.isOptimizationEnabled,
    required this.hasBackgroundLocationPermission,
    required this.isAppWhitelisted,
    required this.needsAttention,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BatteryOptimizationStatus &&
        other.isOptimizationEnabled == isOptimizationEnabled &&
        other.hasBackgroundLocationPermission == hasBackgroundLocationPermission &&
        other.isAppWhitelisted == isAppWhitelisted &&
        other.needsAttention == needsAttention;
  }

  @override
  int get hashCode {
    return isOptimizationEnabled.hashCode ^
        hasBackgroundLocationPermission.hashCode ^
        isAppWhitelisted.hashCode ^
        needsAttention.hashCode;
  }
}

// Provider for battery optimization status
final batteryOptimizationStatusProvider = FutureProvider<BatteryOptimizationStatus>((ref) {
  return BatteryOptimizationService.getBatteryOptimizationStatus();
});

// Widget to show battery optimization warning
class BatteryOptimizationWarning extends ConsumerWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onFix;

  const BatteryOptimizationWarning({
    super.key,
    this.onDismiss,
    this.onFix,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryStatus = ref.watch(batteryOptimizationStatusProvider);
    
    return batteryStatus.when(
      data: (status) {
        if (!status.needsAttention) {
          return const SizedBox.shrink();
        }
        
        return _buildWarningCard(context, status);
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildWarningCard(BuildContext context, BatteryOptimizationStatus status) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert, color: Colors.orange[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Battery Optimization Warning',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getWarningMessage(status),
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (onFix != null)
                  ElevatedButton(
                    onPressed: onFix,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Fix Now'),
                  ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _showDetailedInfo(context),
                  child: const Text('Learn More'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getWarningMessage(BatteryOptimizationStatus status) {
    final issues = <String>[];
    
    if (status.isOptimizationEnabled) {
      issues.add('Battery optimization is enabled');
    }
    
    if (!status.hasBackgroundLocationPermission) {
      issues.add('Background location permission is missing');
    }
    
    if (!status.isAppWhitelisted) {
      issues.add('App is not whitelisted from battery optimization');
    }
    
    if (issues.isEmpty) {
      return 'Battery optimization may affect location tracking.';
    }
    
    return 'The following issues may affect location tracking:\n• ${issues.join('\n• ')}';
  }

  void _showDetailedInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Battery Optimization'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Why is this important?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Battery optimization can prevent the app from tracking your location in the background, which is essential for accurate trip detection.',
              ),
              SizedBox(height: 16),
              Text(
                'How to fix:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Go to Settings > Battery > Battery Optimization'),
              Text('2. Find this app in the list'),
              Text('3. Select "Don\'t optimize" or "Allow"'),
              Text('4. Grant background location permission'),
              SizedBox(height: 16),
              Text(
                'This ensures the app can track your trips even when the screen is off.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// Service to handle battery optimization fixes
class BatteryOptimizationFixService {
  static Future<bool> fixBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // Request to disable battery optimization
      final bool optimizationFixed = await BatteryOptimizationService.requestDisableBatteryOptimization();
      
      // Request background location permission
      final bool permissionGranted = await BatteryOptimizationService.requestBackgroundLocationPermission();
      
      return optimizationFixed && permissionGranted;
    } catch (e) {
      debugPrint('Error fixing battery optimization: $e');
      return false;
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('Error opening battery optimization settings: $e');
    }
  }

  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }
}

// Method channel for native Android implementation
const MethodChannel _channel = MethodChannel('battery_optimization');