import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';
import 'widgets/heatmap_widget.dart';
import 'widgets/mode_share_chart.dart';
import 'widgets/trip_stats_widget.dart';
import 'widgets/export_controls_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _selectedRegion = 'All';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Analytics Dashboard'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map), 
                child: Text('Heatmap', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.pie_chart), 
                child: Text('Mode Share', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.analytics), 
                child: Text('Statistics', style: TextStyle(fontSize: 12))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardDataProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date and Region Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DateTime>(
                    value: _selectedDate,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(7, (index) {
                      final date = DateTime.now().subtract(Duration(days: index));
                      return DropdownMenuItem(
                        value: date,
                        child: Text(date.toString().split(' ')[0]),
                      );
                    }),
                    onChanged: (date) {
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                        ref.invalidate(dashboardDataProvider);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Regions')),
                      DropdownMenuItem(value: 'North', child: Text('North')),
                      DropdownMenuItem(value: 'South', child: Text('South')),
                      DropdownMenuItem(value: 'East', child: Text('East')),
                      DropdownMenuItem(value: 'West', child: Text('West')),
                    ],
                    onChanged: (region) {
                      if (region != null) {
                        setState(() {
                          _selectedRegion = region;
                        });
                        ref.invalidate(dashboardDataProvider);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHeatmapTab(),
                _buildModeShareTab(),
                _buildStatisticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapTab() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboardData = ref.watch(dashboardDataProvider(
          DashboardParams(date: _selectedDate, region: _selectedRegion)
        ));
        
        return dashboardData.when(
          data: (data) => HeatmapWidget(
            tripData: data.trips,
            onTripSelected: (trip) {
              _showTripDetails(trip);
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading heatmap: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardDataProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeShareTab() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboardData = ref.watch(dashboardDataProvider(
          DashboardParams(date: _selectedDate, region: _selectedRegion)
        ));
        
        return dashboardData.when(
          data: (data) => ModeShareChart(
            modeData: data.modeShare,
            onModeSelected: (mode) {
              _showModeDetails(mode, data.modeShare);
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading mode share: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardDataProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboardData = ref.watch(dashboardDataProvider(
          DashboardParams(date: _selectedDate, region: _selectedRegion)
        ));
        
        return dashboardData.when(
          data: (data) => Column(
            children: [
              Expanded(
                child: TripStatsWidget(
                  stats: data.stats,
                  onExportRequested: () {
                    _showExportDialog(data);
                  },
                ),
              ),
              ExportControlsWidget(
                onExportCSV: () => _exportData(data, 'csv'),
                onExportGeoJSON: () => _exportData(data, 'geojson'),
                onExportPDF: () => _exportData(data, 'pdf'),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading statistics: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardDataProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTripDetails(TripData trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trip Details - ${trip.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start: ${trip.startedAt}'),
            Text('End: ${trip.endedAt}'),
            Text('Distance: ${trip.distanceMeters}m'),
            Text('Mode: ${trip.mode}'),
            Text('Purpose: ${trip.purpose}'),
            Text('Points: ${trip.points.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showModeDetails(String mode, Map<String, int> modeData) {
    final count = modeData[mode] ?? 0;
    final total = modeData.values.fold(0, (sum, value) => sum + value);
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$mode Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trips: $count'),
            Text('Percentage: $percentage%'),
            Text('Total trips: $total'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(DashboardData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV Export'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.of(context).pop();
                _exportData(data, 'csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('GeoJSON Export'),
              subtitle: const Text('Geographic data format'),
              onTap: () {
                Navigator.of(context).pop();
                _exportData(data, 'geojson');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF Report'),
              subtitle: const Text('Visual report with charts'),
              onTap: () {
                Navigator.of(context).pop();
                _exportData(data, 'pdf');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportData(DashboardData data, String format) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting data as $format...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}



