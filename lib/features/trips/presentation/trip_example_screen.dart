import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../service/trip_service.dart';

class TripExampleScreen extends ConsumerStatefulWidget {
  const TripExampleScreen({super.key});

  @override
  ConsumerState<TripExampleScreen> createState() => _TripExampleScreenState();
}

class _TripExampleScreenState extends ConsumerState<TripExampleScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final tripService = ref.read(tripServiceProvider);
      final trips = await tripService.getUserTrips();

      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveExampleTrip() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final tripService = ref.read(tripServiceProvider);

      // Example trip data matching your format
      await tripService.saveTrip(
        startLocation: {"lat": 17.3850, "lng": 78.4867}, // Hyderabad
        endLocation: {"lat": 17.4474, "lng": 78.3569}, // Secunderabad
        distanceKm: 12.4,
        durationMin: 25,
        mode: 'car',
        purpose: 'work',
        companions: {'adults': 1, 'children': 0, 'seniors': 0},
        notes: 'Daily commute to office',
      );

      // Reload trips
      await _loadTrips();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Example'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTrips),
        ],
      ),
      body: Column(
        children: [
          // User info
          if (user != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User ID: ${user.id}'),
                    Text('Email: ${user.email ?? 'No email'}'),
                  ],
                ),
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveExampleTrip,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Example Trip'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _loadTrips,
                    child: const Text('Refresh Trips'),
                  ),
                ),
              ],
            ),
          ),

          // Error display
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Error: $_error',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),

          // Trips list
          Expanded(
            child: _trips.isEmpty
                ? const Center(
                    child: Text(
                      'No trips found.\nTap "Save Example Trip" to add one.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text('Trip ${index + 1}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Distance: ${trip['distance_km']} km'),
                              Text('Duration: ${trip['duration_min']} min'),
                              Text('Mode: ${trip['mode']}'),
                              Text('Purpose: ${trip['purpose']}'),
                              if (trip['notes'] != null)
                                Text('Notes: ${trip['notes']}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTrip(trip['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrip(String tripId) async {
    try {
      final tripService = ref.read(tripServiceProvider);
      await tripService.deleteTrip(tripId);
      await _loadTrips();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }
}



