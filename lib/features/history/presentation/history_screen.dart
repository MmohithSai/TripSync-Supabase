import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../../trips/service/trip_service.dart';
import '../../trips/domain/trip_models.dart';
import '../../trips/service/trip_calculator.dart';
// Removed unused l10n imports

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final service = ref.watch(tripServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.getUserTripsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Map Supabase rows to TripSummary for display
          final trips = snapshot.data!
              .map((row) => TripSummary.fromSupabase(row))
              .toList();
          if (trips.isEmpty) {
            return const Center(child: Text('No trips yet'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              // Invalidate the trip service to force refresh
              ref.invalidate(tripServiceProvider);
              // Wait a moment for the stream to update
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.separated(
              itemCount: trips.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = trips[i];
                final title = [
                  t.originRegion,
                  t.destinationRegion,
                ].where((e) => (e ?? '').isNotEmpty).join(' → ');
                final duration = t.endedAt == null
                    ? null
                    : t.endedAt!.difference(t.startedAt);
                final durationStr = duration == null
                    ? 'ongoing'
                    : _formatDuration(duration);
                return FutureBuilder<Map<String, dynamic>>(
                  future: _calculateTripData(t),
                  builder: (context, snapshot) {
                    final co2Savings = snapshot.data?['co2'] ?? 0.0;
                    final cost = snapshot.data?['cost'] ?? 0.0;

                    return ListTile(
                      leading: const Icon(Icons.alt_route),
                      title: Text(title.isEmpty ? 'Trip' : title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main trip info with better distance formatting
                          Text(
                            'Mode: ${t.mode.name} • Distance: ${_formatDistance(t.distanceMeters)} • Duration: $durationStr',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),

                          // Start and End times
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_formatTime(t.startedAt)} → ${t.endedAt != null ? _formatTime(t.endedAt!) : "Ongoing"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Trip numbers and chain ID
                          if (t.tripNumber != null || t.chainId != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    [
                                      if (t.tripNumber != null)
                                        'Trip: ${t.tripNumber}',
                                      if (t.chainId != null)
                                        'Chain: ${t.chainId}',
                                    ].join(' • '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Environmental and cost info
                          if (snapshot.hasData) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.eco,
                                  size: 16,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${TripCalculator.formatCO2(co2Savings)} saved',
                                    style: TextStyle(
                                      color: Colors.green[600],
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.attach_money,
                                  size: 16,
                                  color: Colors.blue[600],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    TripCalculator.formatCost(cost),
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () async {
                        await _editTrip(context, ref, user.id, t);
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      // Show in kilometers with 2 decimal places for distances >= 1km
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    } else {
      // Show in meters for shorter distances
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
  }

  String _formatTime(DateTime dateTime) {
    // Format as HH:MM (24-hour format)
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _calculateTripData(TripSummary trip) async {
    final co2Savings = TripCalculator.calculateCO2Savings(trip);
    final cost = await TripCalculator.calculateCost(trip);
    return {'co2': co2Savings, 'cost': cost};
  }

  Future<void> _editTrip(
    BuildContext context,
    WidgetRef ref,
    String uid,
    TripSummary t,
  ) async {
    final service = ref.read(tripServiceProvider);
    final originCtrl = TextEditingController(text: t.originRegion ?? '');
    final destCtrl = TextEditingController(text: t.destinationRegion ?? '');
    final relationshipCtrl = TextEditingController(
      text: t.companions.relationship ?? '',
    );
    int adults = t.companions.adults;
    int children = t.companions.children;
    int seniors = t.companions.seniors;

    // Calculate environmental impact
    final co2Savings = TripCalculator.calculateCO2Savings(t);
    final cost = await TripCalculator.calculateCost(t);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit trip',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    // Environmental impact card
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.eco, color: Colors.green[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Environmental Impact',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CO₂ Saved',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      TripCalculator.formatCO2(co2Savings),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cost',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      TripCalculator.formatCost(cost),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Impact',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      TripCalculator.getEnvironmentalImpact(
                                        co2Savings,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: originCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Origin region',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: destCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Destination region',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Passengers',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Adults')),
                        IconButton(
                          onPressed: () => setState(
                            () => adults = adults > 0 ? adults - 1 : 0,
                          ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$adults'),
                        IconButton(
                          onPressed: () => setState(() => adults = adults + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Children')),
                        IconButton(
                          onPressed: () => setState(
                            () => children = children > 0 ? children - 1 : 0,
                          ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$children'),
                        IconButton(
                          onPressed: () =>
                              setState(() => children = children + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Seniors')),
                        IconButton(
                          onPressed: () => setState(
                            () => seniors = seniors > 0 ? seniors - 1 : 0,
                          ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$seniors'),
                        IconButton(
                          onPressed: () =>
                              setState(() => seniors = seniors + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: relationshipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Companion relationship (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            await service.updateTrip(
                              tripId: t.id,
                              // Map fields supported by SupabaseTripRepository
                              startLocation:
                                  t.originLatitude != null &&
                                      t.originLongitude != null
                                  ? {
                                      'lat': t.originLatitude!,
                                      'lng': t.originLongitude!,
                                    }
                                  : null,
                              endLocation:
                                  t.destinationLatitude != null &&
                                      t.destinationLongitude != null
                                  ? {
                                      'lat': t.destinationLatitude!,
                                      'lng': t.destinationLongitude!,
                                    }
                                  : null,
                              mode: t.mode.name,
                              purpose: t.purpose.name,
                              notes: t.notes,
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
