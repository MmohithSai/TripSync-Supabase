import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip_models.dart';
import '../../trips/service/trip_calculator.dart';
import '../../../l10n/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

class HistoryScreenEnhanced extends ConsumerStatefulWidget {
  const HistoryScreenEnhanced({super.key});

  @override
  ConsumerState<HistoryScreenEnhanced> createState() => _HistoryScreenEnhancedState();
}

class _HistoryScreenEnhancedState extends ConsumerState<HistoryScreenEnhanced> {
  final Set<String> _selectedTrips = <String>{};
  bool _isBatchMode = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final l10n = ref.watch(appLocalizationsProvider);
    
    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.notSignedIn)));
    }
    
    final repo = ref.watch(tripRepositoryProvider);

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
          ] else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _enterBatchMode,
              tooltip: l10n.batchEdit,
            ),
        ],
      ),
      body: StreamBuilder<List<TripSummary>>(
        stream: repo.watchRecentTrips(user.uid, limit: 100),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data!;
          
          return Column(
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
          );
        },
      ),
    );
  }

  Widget _buildWeeklySummaryCard(List<TripSummary> trips, AppLocalizations l10n) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    final weeklyTrips = trips.where((trip) {
      return trip.startedAt.isAfter(weekStart) && 
             trip.startedAt.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();
    
    final totalDistance = weeklyTrips.fold<double>(0, (sum, trip) => sum + trip.distanceMeters);
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

  Widget _buildSummaryItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color ?? Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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

  Widget _buildTripTile(TripSummary trip, bool isSelected, AppLocalizations l10n) {
    final title = [trip.originRegion, trip.destinationRegion]
        .where((e) => (e ?? '').isNotEmpty)
        .join(' → ');
    final duration = trip.endedAt == null 
        ? null 
        : trip.endedAt!.difference(trip.startedAt);
    final durationStr = duration == null ? l10n.ongoing : _formatDuration(duration);

    return ListTile(
      leading: _isBatchMode
          ? Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleTripSelection(trip.id),
            )
          : const Icon(Icons.alt_route),
      title: Text(title.isEmpty ? l10n.trip : title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.mode}: ${_getModeName(trip.mode, l10n)} • ${l10n.distance}: ${trip.distanceMeters.toStringAsFixed(0)} m • ${l10n.time}: $durationStr'),
          const SizedBox(height: 4),
          FutureBuilder<Map<String, dynamic>>(
            future: _calculateTripData(trip),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final co2Savings = snapshot.data!['co2'] ?? 0.0;
                final cost = snapshot.data!['cost'] ?? 0.0;
                
                return Row(
                  children: [
                    Icon(Icons.eco, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text('${TripCalculator.formatCO2(co2Savings)} ${l10n.saved}', 
                         style: TextStyle(color: Colors.green[600], fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.attach_money, size: 16, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Text(TripCalculator.formatCost(cost), 
                         style: TextStyle(color: Colors.blue[600], fontSize: 12)),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      trailing: _isBatchMode ? null : const Icon(Icons.edit_outlined),
      onTap: _isBatchMode 
          ? () => _toggleTripSelection(trip.id)
          : () => _editTrip(context, ref, trip),
    );
  }

  String _getModeName(TripMode mode, AppLocalizations l10n) {
    switch (mode) {
      case TripMode.walk: return l10n.walk;
      case TripMode.bicycle: return l10n.bicycle;
      case TripMode.car: return l10n.car;
      case TripMode.bus: return l10n.bus;
      case TripMode.train: return l10n.train;
      case TripMode.metro: return l10n.metro;
      case TripMode.scooter: return l10n.scooter;
      default: return l10n.unknown;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Future<Map<String, dynamic>> _calculateTripData(TripSummary trip) async {
    final co2Savings = TripCalculator.calculateCO2Savings(trip);
    final cost = await TripCalculator.calculateCost(trip);
    return {'co2': co2Savings, 'cost': cost};
  }

  void _enterBatchMode() {
    setState(() {
      _isBatchMode = true;
      _selectedTrips.clear();
    });
  }

  void _exitBatchMode() {
    setState(() {
      _isBatchMode = false;
      _selectedTrips.clear();
    });
  }

  void _toggleTripSelection(String tripId) {
    setState(() {
      if (_selectedTrips.contains(tripId)) {
        _selectedTrips.remove(tripId);
      } else {
        _selectedTrips.add(tripId);
      }
    });
  }

  void _selectAllTrips() {
    // This would need access to the current trips list
    // For now, we'll implement a simple toggle
    setState(() {
      if (_selectedTrips.isEmpty) {
        // Select all visible trips (this is a simplified implementation)
        // In a real implementation, you'd need access to the trips list
      } else {
        _selectedTrips.clear();
      }
    });
  }

  void _batchEditTrips() {
    if (_selectedTrips.isEmpty) return;
    
    final l10n = ref.read(appLocalizationsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.batchEdit),
        content: Text('${l10n.updateSelected} ${_selectedTrips.length} ${l10n.trip.toLowerCase()}s?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              // Implement batch edit logic here
              Navigator.pop(context);
              _exitBatchMode();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _editTrip(BuildContext context, WidgetRef ref, TripSummary trip) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    
    final repo = ref.read(tripRepositoryProvider);
    final l10n = ref.read(appLocalizationsProvider);
    
    final originCtrl = TextEditingController(text: trip.originRegion ?? '');
    final destCtrl = TextEditingController(text: trip.destinationRegion ?? '');
    final tripNumCtrl = TextEditingController(text: trip.tripNumber ?? '');
    final chainCtrl = TextEditingController(text: trip.chainId ?? '');
    final relationshipCtrl = TextEditingController(text: trip.companions.relationship ?? '');
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
                    Text(l10n.editTrip, style: Theme.of(context).textTheme.titleMedium),
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
                                Text(l10n.environmentalImpact, 
                                     style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.co2Saved, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    Text(TripCalculator.formatCO2(co2Savings), 
                                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.cost, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    Text(TripCalculator.formatCost(cost), 
                                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.impact, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    Text(TripCalculator.getEnvironmentalImpact(co2Savings), 
                                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700], fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: originCtrl, decoration: InputDecoration(labelText: l10n.originRegion)), 
                    const SizedBox(height: 8),
                    TextField(controller: destCtrl, decoration: InputDecoration(labelText: l10n.destinationRegion)), 
                    const SizedBox(height: 8),
                    TextField(controller: tripNumCtrl, decoration: InputDecoration(labelText: l10n.tripNumber)), 
                    const SizedBox(height: 8),
                    TextField(controller: chainCtrl, decoration: InputDecoration(labelText: l10n.chainId)), 
                    const SizedBox(height: 12),
                    Text(l10n.passengers, style: Theme.of(context).textTheme.titleSmall),
                    Row(children: [
                      Expanded(child: Text(l10n.adults)),
                      IconButton(onPressed: () => setState(() => adults = adults > 0 ? adults - 1 : 0), icon: const Icon(Icons.remove_circle_outline)),
                      Text('$adults'),
                      IconButton(onPressed: () => setState(() => adults = adults + 1), icon: const Icon(Icons.add_circle_outline)),
                    ]),
                    Row(children: [
                      Expanded(child: Text(l10n.children)),
                      IconButton(onPressed: () => setState(() => children = children > 0 ? children - 1 : 0), icon: const Icon(Icons.remove_circle_outline)),
                      Text('$children'),
                      IconButton(onPressed: () => setState(() => children = children + 1), icon: const Icon(Icons.add_circle_outline)),
                    ]),
                    Row(children: [
                      Expanded(child: Text(l10n.seniors)),
                      IconButton(onPressed: () => setState(() => seniors = seniors > 0 ? seniors - 1 : 0), icon: const Icon(Icons.remove_circle_outline)),
                      Text('$seniors'),
                      IconButton(onPressed: () => setState(() => seniors = seniors + 1), icon: const Icon(Icons.add_circle_outline)),
                    ]),
                    const SizedBox(height: 8),
                    TextField(controller: relationshipCtrl, decoration: InputDecoration(labelText: l10n.companionRelationship)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            await repo.updateSummary(
                              uid: user.uid,
                              tripId: trip.id,
                              originRegion: originCtrl.text.trim().isEmpty ? null : originCtrl.text.trim(),
                              destinationRegion: destCtrl.text.trim().isEmpty ? null : destCtrl.text.trim(),
                              tripNumber: tripNumCtrl.text.trim().isEmpty ? null : tripNumCtrl.text.trim(),
                              chainId: chainCtrl.text.trim().isEmpty ? null : chainCtrl.text.trim(),
                              companions: Companions(
                                adults: adults,
                                children: children,
                                seniors: seniors,
                                relationship: relationshipCtrl.text.trim().isEmpty ? null : relationshipCtrl.text.trim(),
                              ),
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Text(l10n.save),
                        ),
                      ],
                    )
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






