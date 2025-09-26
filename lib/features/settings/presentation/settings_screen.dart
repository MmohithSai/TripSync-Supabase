import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../common/providers.dart';
import '../../location/service/location_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationControllerProvider);
    final auth = ref.watch(firebaseAuthProvider);
    final controller = ref.read(locationControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Location service enabled'),
            value: locationState.serviceEnabled,
            onChanged: (_) async {
              // Prompt user to enable service via OS settings
              await Geolocator.openLocationSettings();
            },
          ),
          ListTile(
            title: const Text('Request location permission'),
            subtitle: Text(locationState.permissionsGranted ? 'Granted' : 'Not granted'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ref.read(locationControllerProvider.notifier).requestPermissions(),
          ),
          ListTile(
            title: const Text('Sync now'),
            subtitle: const Text('Flush locally queued locations to cloud'),
            trailing: const Icon(Icons.sync),
            onTap: () async {
              await controller.syncNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync attempted')));
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Sign out'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}



