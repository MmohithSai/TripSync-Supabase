import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../service/location_controller.dart';
import '../../../widgets/background_location_request_dialog.dart';

class PermissionGate extends ConsumerStatefulWidget {
  final Widget child;
  const PermissionGate({super.key, required this.child});

  @override
  ConsumerState<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends ConsumerState<PermissionGate> {
  bool _promptedOnce = false;
  bool _requestedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Show compelling dialog first, then request permissions
      await _showBackgroundLocationDialog();
    });
  }

  Future<void> _showBackgroundLocationDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackgroundLocationRequestDialog(
        onProceed: () async {
          Navigator.pop(context);
          await _requestPermissionsWithUpgrade();
        },
        onCancel: () async {
          Navigator.pop(context);
          await _requestPermissionsWithUpgrade();
        },
      ),
    );
  }

  Future<void> _requestPermissionsWithUpgrade() async {
    // Request permissions
    await ref.read(locationControllerProvider.notifier).requestPermissions();

    if (mounted) {
      setState(() {
        _requestedOnce = true;
      });

      // Check if we got "while in use" and offer upgrade
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse && mounted) {
        await _showUpgradeDialog();
      }
    }
  }

  Future<void> _showUpgradeDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => UpgradeToAlwaysDialog(
        onUpgrade: () async {
          Navigator.pop(context);
          await ref
              .read(locationControllerProvider.notifier)
              .requestAlwaysPermission();
          setState(() {});
        },
        onKeepCurrent: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showInAppPromptOnce() async {
    if (_promptedOnce) return;
    _promptedOnce = true;
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('Location Access Required'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TripSync needs location access to track your trips accurately.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('📍 For best results, please choose:'),
              SizedBox(height: 8),
              Text('✅ "While using the app" (minimum)'),
              Text('✅ "Always" (recommended for background tracking)'),
              SizedBox(height: 8),
              Text('❌ Avoid "Only this time" or "Don\'t allow"'),
              SizedBox(height: 12),
              Text(
                'These options will stop trip recording when you close the app or switch to other apps.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref
                    .read(locationControllerProvider.notifier)
                    .requestPermissions();
                setState(() {});
              },
              child: const Text('Grant Permission'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
                await ref
                    .read(locationControllerProvider.notifier)
                    .refreshNow();
                setState(() {});
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationControllerProvider);

    final hasPermission = locationState.permissionsGranted;
    final serviceEnabled = locationState.serviceEnabled;

    if (hasPermission && serviceEnabled) {
      return widget.child;
    }

    // If permission not granted, show one in-app prompt ONLY after we've requested once
    if (!hasPermission && _requestedOnce) {
      // Show the in-app prompt once after the OS dialog denial
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showInAppPromptOnce();
      });
      return _BlockedScreen(
        title: 'Location Permission Needed',
        message:
            'TripSync needs location access to track your trips.\n\n'
            '📍 Please choose "While using the app" or "Always" when prompted.\n\n'
            '❌ "Only this time" and "Don\'t allow" will prevent trip tracking.',
        onRetry: () async {
          await ref
              .read(locationControllerProvider.notifier)
              .requestPermissions();
          setState(() {});
        },
        onOpenSettings: () async {
          await Geolocator.openAppSettings();
          await ref.read(locationControllerProvider.notifier).refreshNow();
          setState(() {});
        },
      );
    }

    // Permission granted but services are off: block and direct to enable services
    return _BlockedScreen(
      title: 'Turn on Location services',
      message: 'Location services are off. Please enable them to continue.',
      onRetry: () async {
        await ref.read(locationControllerProvider.notifier).refreshNow();
        setState(() {});
      },
      onOpenSettings: () async {
        await Geolocator.openLocationSettings();
        await ref.read(locationControllerProvider.notifier).refreshNow();
        setState(() {});
      },
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _BlockedScreen({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onOpenSettings,
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
