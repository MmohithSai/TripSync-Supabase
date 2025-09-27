import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../map/presentation/map_screen.dart';
import '../../history/presentation/history_screen_enhanced.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../itinerary/presentation/itinerary_screen.dart';
import '../../location/service/location_controller.dart';
import '../../../l10n/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  final List<Widget> _pages = const [
    MapScreen(),
    HistoryScreenEnhanced(),
    ItineraryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: l10n.map),
          NavigationDestination(icon: const Icon(Icons.history), label: l10n.history),
          NavigationDestination(icon: const Icon(Icons.route), label: 'Itinerary'),
          NavigationDestination(icon: const Icon(Icons.settings), label: l10n.settings),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
      floatingActionButtonLocation: null,
      floatingActionButton: null,
    );
  }
}




