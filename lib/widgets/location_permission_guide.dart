import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// A widget that shows users how to properly set up location permissions
/// for optimal trip tracking experience
class LocationPermissionGuide extends StatelessWidget {
  final VoidCallback? onDismiss;

  const LocationPermissionGuide({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Location Setup Guide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'For accurate trip tracking, please:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            _buildGuideItem(
              icon: Icons.check_circle,
              color: Colors.green,
              title: 'Choose "Always" or "While using the app"',
              description: 'This allows continuous trip tracking',
            ),

            _buildGuideItem(
              icon: Icons.gps_fixed,
              color: Colors.blue,
              title: 'Select "Precise" location',
              description: 'For accurate distance and route tracking',
            ),

            _buildGuideItem(
              icon: Icons.cancel,
              color: Colors.red,
              title: 'Avoid "Only this time" or "Don\'t allow"',
              description: 'These will stop tracking when you close the app',
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Without proper permissions, trips may not be recorded when you switch apps or lock your phone.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Geolocator.openAppSettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Settings'),
                  ),
                ),
                if (onDismiss != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onDismiss,
                      child: const Text('Got it'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple banner that can be shown at the top of screens to warn about
/// insufficient location permissions
class LocationPermissionBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const LocationPermissionBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Limited location access may affect trip tracking',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.orange),
          ],
        ),
      ),
    );
  }
}


