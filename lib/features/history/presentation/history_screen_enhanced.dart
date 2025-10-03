import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../../trips/service/trip_service.dart';
import '../../trips/domain/trip_models.dart';
import '../../trips/service/trip_calculator.dart';
import '../../../l10n/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

class HistoryScreenEnhanced extends ConsumerStatefulWidget {
  const HistoryScreenEnhanced({super.key});

  @override
  ConsumerState<HistoryScreenEnhanced> createState() =>
      _HistoryScreenEnhancedState();
}

class _HistoryScreenEnhancedState extends ConsumerState<HistoryScreenEnhanced> {
  final Set<String> _selectedTrips = <String>{};
  bool _isBatchMode = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.notSignedIn)));
    }

    final service = ref.watch(tripServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        actions: [
          if (_isBatchMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAllTrips,
              tooltip: l10n.selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _selectedTrips.isNotEmpty ? _batchEditTrips : null,
              tooltip: l10n.batchEdit,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitBatchMode,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _enterBatchMode,
              tooltip: l10n.batchEdit,
            ),
            // Export icon is only active for NATPAC; hidden otherwise
            // (left as placeholder; feature flagged off by default)
          ],
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.getUserTripsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data!
              .map((row) => TripSummary.fromSupabase(row))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              // Invalidate the trip service to force refresh
              ref.invalidate(tripServiceProvider);
              // Wait a moment for the stream to update
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: Column(
              children: [
                // Weekly Summary Card
                _buildWeeklySummaryCard(trips, l10n),

                // Trips List
                Expanded(
                  child: trips.isEmpty
                      ? Center(child: Text(l10n.noTripsYet))
                      : ListView.separated(
                          itemCount: trips.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final trip = trips[i];
                            final isSelected = _selectedTrips.contains(trip.id);

                            return _buildTripTile(trip, isSelected, l10n);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklySummaryCard(
    List<TripSummary> trips,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final weeklyTrips = trips.where((trip) {
      return trip.startedAt.isAfter(weekStart) &&
          trip.startedAt.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();

    final totalDistance = weeklyTrips.fold<double>(
      0,
      (sum, trip) => sum + trip.distanceMeters,
    );
    final totalTrips = weeklyTrips.length;

    // Calculate CO2 savings for the week
    double totalCO2 = 0;
    for (final trip in weeklyTrips) {
      totalCO2 += TripCalculator.calculateCO2Savings(trip);
    }

    // Find most common mode
    final modeCounts = <TripMode, int>{};
    for (final trip in weeklyTrips) {
      modeCounts[trip.mode] = (modeCounts[trip.mode] ?? 0) + 1;
    }
    final topMode = modeCounts.isNotEmpty
        ? modeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : TripMode.unknown;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  l10n.weeklySummary,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    l10n.totalDistance,
                    '${(totalDistance / 1000).toStringAsFixed(1)} km',
                    Icons.straighten,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    l10n.totalTrips,
                    totalTrips.toString(),
                    Icons.directions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    l10n.co2SavedThisWeek,
                    TripCalculator.formatCO2(totalCO2),
                    Icons.eco,
                    Colors.green[600],
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    l10n.topMode,
                    _getModeName(topMode, l10n),
                    Icons.directions_car,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color ?? Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTripTile(
    TripSummary trip,
    bool isSelected,
    AppLocalizations l10n,
  ) {
    final title = [
      trip.originRegion,
      trip.destinationRegion,
    ].where((e) => (e ?? '').isNotEmpty).join(' → ');
    final duration = trip.endedAt == null
        ? null
        : trip.endedAt!.difference(trip.startedAt);
    final durationStr = duration == null
        ? l10n.ongoing
        : _formatDuration(duration);

    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selectedTrips.add(trip.id);
            } else {
              _selectedTrips.remove(trip.id);
            }
          });
        },
      ),
      title: Text(title.isEmpty ? 'Trip' : title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main trip info with better distance formatting
          Text(
            'Mode: ${trip.mode.name} • Distance: ${_formatDistance(trip.distanceMeters)} • Duration: $durationStr',
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 4),

          // Start and End times
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_formatTime(trip.startedAt)} → ${trip.endedAt != null ? _formatTime(trip.endedAt!) : "Ongoing"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Trip numbers and chain ID
          if (trip.tripNumber != null || trip.chainId != null) ...[
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
                      if (trip.tripNumber != null) 'Trip: ${trip.tripNumber}',
                      if (trip.chainId != null) 'Chain: ${trip.chainId}',
                    ].join(' • '),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Environmental info
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.eco, size: 16, color: Colors.green[600]),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  TripCalculator.formatCO2(
                    TripCalculator.calculateCO2Savings(trip),
                  ),
                  style: TextStyle(color: Colors.green[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () async {
        await _editTrip(context, ref, trip);
      },
    );
  }

  String _getModeName(TripMode mode, AppLocalizations l10n) {
    switch (mode) {
      case TripMode.walk:
        return l10n.walk;
      case TripMode.bicycle:
        return l10n.bicycle;
      case TripMode.car:
        return l10n.car;
      case TripMode.bus:
        return l10n.bus;
      case TripMode.train:
        return l10n.train;
      case TripMode.metro:
        return l10n.metro;
      case TripMode.scooter:
        return l10n.scooter;
      case TripMode.unknown:
        return l10n.unknown;
    }
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

  void _enterBatchMode() {
    setState(() => _isBatchMode = true);
  }

  void _exitBatchMode() {
    setState(() {
      _isBatchMode = false;
      _selectedTrips.clear();
    });
  }

  void _selectAllTrips() {
    // In a real app, we would select all currently loaded trip IDs
    // Here, leave as a no-op placeholder
  }

  Future<void> _batchEditTrips() async {
    // Placeholder for batch edit functionality
  }

  Future<void> _editTrip(
    BuildContext context,
    WidgetRef ref,
    TripSummary trip,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // l10n already available in build; no-op here

    final originCtrl = TextEditingController(text: trip.originRegion ?? '');
    final destCtrl = TextEditingController(text: trip.destinationRegion ?? '');
    final relationshipCtrl = TextEditingController(
      text: trip.companions.relationship ?? '',
    );
    int adults = trip.companions.adults;
    int children = trip.companions.children;
    int seniors = trip.companions.seniors;

    // Calculate environmental impact
    final co2Savings = TripCalculator.calculateCO2Savings(trip);
    final cost = await TripCalculator.calculateCost(trip);

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
                            // Persist a subset of editable fields to Supabase trips row
                            await ref
                                .read(tripServiceProvider)
                                .updateTrip(
                                  tripId: trip.id,
                                  mode: trip.mode.name,
                                  purpose: trip.purpose.name,
                                  notes: trip.notes,
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

// NATPAC export screen removed (unused)
