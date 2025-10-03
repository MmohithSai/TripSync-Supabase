import 'package:flutter/material.dart';

/// A compelling dialog that explains why background location is critical
/// and guides users to select the right permission
class BackgroundLocationRequestDialog extends StatelessWidget {
  final VoidCallback onProceed;
  final VoidCallback? onCancel;

  const BackgroundLocationRequestDialog({
    super.key,
    required this.onProceed,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable Trip Tracking',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚗 Why TripSync needs background location:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('• Track trips even when you switch apps'),
                  Text('• Record accurate routes and distances'),
                  Text('• Automatically detect trip start/stop'),
                  Text('• Work seamlessly in the background'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ When prompted, please select:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '"Allow all the time" or "Always"',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('This enables full trip tracking capabilities'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❌ Please avoid:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• "Only while using the app"'),
                  Text('• "Ask next time"'),
                  Text('• "Don\'t allow"'),
                  SizedBox(height: 4),
                  Text(
                    'These will prevent background trip tracking',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Row(
              children: [
                Icon(Icons.security, color: Colors.grey, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your location data stays private and is only used for trip tracking.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (onCancel != null)
          TextButton(onPressed: onCancel, child: const Text('Maybe Later')),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onProceed,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// A follow-up dialog shown if user selected "While using app" to encourage upgrade
class UpgradeToAlwaysDialog extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onKeepCurrent;

  const UpgradeToAlwaysDialog({
    super.key,
    required onUpgrade,
    required onKeepCurrent,
  }) : onUpgrade = onUpgrade,
       onKeepCurrent = onKeepCurrent;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Limited Trip Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You selected "While using the app" which limits trip tracking.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ This means:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Trips stop recording when you switch apps'),
                Text('• Incomplete trip data and distances'),
                Text('• Manual trip start/stop required'),
                Text('• Reduced accuracy and reliability'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'For the best experience, we recommend upgrading to "Always" permission.',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onKeepCurrent,
          child: const Text('Keep Current Setting'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onUpgrade,
          icon: const Icon(Icons.upgrade),
          label: const Text('Upgrade to Always'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}


