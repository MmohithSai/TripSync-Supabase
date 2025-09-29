import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../map/presentation/map_screen.dart';
import '../../history/presentation/history_screen_enhanced.dart';
import '../../settings/presentation/settings_screen.dart';
// import '../../itinerary/presentation/itinerary_screen.dart'; // Removed itinerary functionality
// import '../../../l10n/locale_provider.dart'; // Removed unused import

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
    // ItineraryScreen(), // Removed itinerary functionality
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
      floatingActionButtonLocation: null,
      floatingActionButton: null,
    );
  }
}
