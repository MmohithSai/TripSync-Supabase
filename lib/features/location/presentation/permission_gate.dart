import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../service/location_controller.dart';

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
      // Trigger only the OS dialog first
      await ref.read(locationControllerProvider.notifier).requestPermissions();
      if (mounted) {
        setState(() {
          _requestedOnce = true;
        });
      }
    });
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
          title: const Text('Location permission needed'),
          content: const Text(
            'We need your location to run the app. Allow access when prompted or open settings to enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(locationControllerProvider.notifier).requestPermissions();
                setState(() {});
              },
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
                await ref.read(locationControllerProvider.notifier).refreshNow();
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
        title: 'Allow location permission',
        message:
            'Location permission is required. Tap Retry to allow, or open Settings and enable Location for this app.',
        onRetry: () async {
          await ref.read(locationControllerProvider.notifier).requestPermissions();
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
                  OutlinedButton(onPressed: onOpenSettings, child: const Text('Open Settings')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


