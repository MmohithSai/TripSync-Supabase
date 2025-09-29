import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../common/providers.dart';
import '../../location/service/location_controller.dart';
import '../../../l10n/locale_provider.dart';
import '../../../l10n/locale_service.dart';
import '../../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationControllerProvider);
    final user = ref.watch(currentUserProvider);
    final controller = ref.read(locationControllerProvider.notifier);
    final l10n = ref.watch(appLocalizationsProvider);
    final currentLocale = ref.watch(localeProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // Language Selection
          ListTile(
            title: Text(l10n.language),
            subtitle: Text(LocaleService.getLanguageName(currentLocale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, ref),
          ),
          const Divider(),
          
          // Location Settings
          SwitchListTile(
            title: Text(l10n.locationServiceEnabled),
            value: locationState.serviceEnabled,
            onChanged: (_) async {
              // Prompt user to enable service via OS settings
              await Geolocator.openLocationSettings();
            },
          ),
          ListTile(
            title: Text(l10n.requestLocationPermission),
            subtitle: Text(locationState.permissionsGranted ? l10n.granted : l10n.notGranted),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ref.read(locationControllerProvider.notifier).requestPermissions(),
          ),
          ListTile(
            title: Text(l10n.syncNow),
            subtitle: Text(l10n.flushLocallyQueuedLocations),
            trailing: const Icon(Icons.sync),
            onTap: () async {
              await controller.syncNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.syncAttempted)));
              }
            },
          ),
          const Divider(),
          
          // Privacy & Data
          ListTile(
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPrivacyPolicy(context, ref),
          ),
          ListTile(
            title: Text(l10n.dataRetention),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDataRetention(context, ref),
          ),
          const Divider(),
          
          // Account
          ListTile(
            title: Text(l10n.signOut),
            leading: const Icon(Icons.logout),
            onTap: () async {
              final supabase = ref.read(supabaseProvider);
              await supabase.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.watch(appLocalizationsProvider).language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LocaleService.supportedLocales.map((locale) {
            final l10n = ref.watch(appLocalizationsProvider);
            final isSelected = ref.watch(localeProvider) == locale;
            return RadioListTile<Locale>(
              title: Text(LocaleService.getLanguageName(locale)),
              value: locale,
              groupValue: ref.watch(localeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(localeProvider.notifier).setLocale(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(appLocalizationsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.privacyPolicy),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<String>(
            future: DefaultAssetBundle.of(context).loadString('assets/privacy_policy.md'),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Markdown(data: snapshot.data!);
              } else if (snapshot.hasError) {
                return Text('Error loading privacy policy: ${snapshot.error}');
              }
              return const CircularProgressIndicator();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.dismiss),
          ),
        ],
      ),
    );
  }

  void _showDataRetention(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(appLocalizationsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dataRetention),
        content: const SingleChildScrollView(
          child: Text(
            'Data Retention Policy:\n\n'
            '• Personal trip data: Retained indefinitely unless deleted by user\n'
            '• Location points: Automatically purged after 1 year\n'
            '• Anonymized research data: May be retained indefinitely\n'
            '• You can request complete data deletion at any time\n\n'
            'For detailed information, see our Privacy Policy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.dismiss),
          ),
        ],
      ),
    );
  }
}



