import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/dashboard_models.dart';

class TripStatsWidget extends StatelessWidget {
  final TripStats stats;
  final VoidCallback onExportRequested;

  const TripStatsWidget({
    super.key,
    required this.stats,
    required this.onExportRequested,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with export button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trip Statistics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: onExportRequested,
                icon: const Icon(Icons.download),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Key metrics cards
          _buildMetricsGrid(),
          const SizedBox(height: 24),
          
          // Charts
          _buildChartsSection(),
          const SizedBox(height: 24),
          
          // Detailed breakdown
          _buildDetailedBreakdown(),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Trips',
          stats.totalTrips.toString(),
          Icons.directions,
          Colors.blue,
        ),
        _buildMetricCard(
          'Total Distance',
          '${(stats.totalDistance / 1000).toStringAsFixed(1)} km',
          Icons.straighten,
          Colors.green,
        ),
        _buildMetricCard(
          'Total Duration',
          _formatDuration(stats.totalDuration),
          Icons.access_time,
          Colors.orange,
        ),
        _buildMetricCard(
          'Average Speed',
          '${stats.averageSpeed.toStringAsFixed(1)} km/h',
          Icons.speed,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mode Distribution',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: _buildModeBarChart(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Purpose Distribution',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: _buildPurposeBarChart(),
        ),
      ],
    );
  }

  Widget _buildModeBarChart() {
    if (stats.modeCounts.isEmpty) {
      return const Center(
        child: Text('No mode data available'),
      );
    }

    final sortedModes = stats.modeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: sortedModes.first.value.toDouble() * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${sortedModes[group.x].key}\n${rod.toY.toInt()} trips',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedModes.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _formatModeName(sortedModes[value.toInt()].key),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: sortedModes.asMap().entries.map((entry) {
          final index = entry.key;
          final mode = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: mode.value.toDouble(),
                color: _getModeColor(mode.key),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPurposeBarChart() {
    if (stats.purposeCounts.isEmpty) {
      return const Center(
        child: Text('No purpose data available'),
      );
    }

    final sortedPurposes = stats.purposeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: sortedPurposes.first.value.toDouble() * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${sortedPurposes[group.x].key}\n${rod.toY.toInt()} trips',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedPurposes.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _formatPurposeName(sortedPurposes[value.toInt()].key),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: sortedPurposes.asMap().entries.map((entry) {
          final index = entry.key;
          final purpose = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: purpose.value.toDouble(),
                color: _getPurposeColor(purpose.key),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailedBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              _buildBreakdownRow('Average Trip Distance', '${stats.averageTripDistance.toStringAsFixed(1)} m'),
              _buildBreakdownRow('Average Trip Duration', _formatDuration(stats.averageTripDuration)),
              _buildBreakdownRow('Recurring Trips', '${stats.recurringTrips} (${(stats.recurringTrips / stats.totalTrips * 100).toStringAsFixed(1)}%)'),
              _buildBreakdownRow('Total Active Time', _formatDuration(stats.totalDuration)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
        return Colors.green;
      case 'cycling':
        return Colors.blue;
      case 'driving':
        return Colors.red;
      case 'public_transport':
        return Colors.purple;
      case 'train':
        return Colors.orange;
      case 'bus':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getPurposeColor(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'education':
        return Colors.green;
      case 'shopping':
        return Colors.orange;
      case 'leisure':
        return Colors.purple;
      case 'health':
        return Colors.red;
      case 'personal':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatModeName(String mode) {
    switch (mode.toLowerCase()) {
      case 'public_transport':
        return 'Public\nTransport';
      case 'motorcycle':
        return 'Motorcycle';
      default:
        return mode.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  String _formatPurposeName(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'personal':
        return 'Personal';
      default:
        return purpose.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}



