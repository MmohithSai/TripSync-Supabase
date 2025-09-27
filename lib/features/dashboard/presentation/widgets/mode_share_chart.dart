import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ModeShareChart extends StatefulWidget {
  final Map<String, int> modeData;
  final Function(String) onModeSelected;

  const ModeShareChart({
    super.key,
    required this.modeData,
    required this.onModeSelected,
  });

  @override
  State<ModeShareChart> createState() => _ModeShareChartState();
}

class _ModeShareChartState extends State<ModeShareChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.modeData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No mode data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final total = widget.modeData.values.fold(0, (sum, count) => sum + count);
    final sortedModes = widget.modeData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // Chart
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: _buildSections(sortedModes, total),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Legend
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: sortedModes.length,
            itemBuilder: (context, index) {
              final entry = sortedModes[index];
              final percentage = (entry.value / total * 100).toStringAsFixed(1);
              final color = _getModeColor(entry.key);
              final isSelected = _touchedIndex == index;
              
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    _formatModeName(entry.key),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.value} trips',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    widget.onModeSelected(entry.key);
                  },
                ),
              );
            },
          ),
        ),
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Trips', total.toString()),
              _buildSummaryItem('Modes', sortedModes.length.toString()),
              _buildSummaryItem(
                'Most Common',
                sortedModes.isNotEmpty ? _formatModeName(sortedModes.first.key) : 'N/A',
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(List<MapEntry<String, int>> sortedModes, int total) {
    return sortedModes.asMap().entries.map((entry) {
      final index = entry.key;
      final modeEntry = entry.value;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 110.0 : 100.0;
      final color = _getModeColor(modeEntry.key);
      final percentage = (modeEntry.value / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        color: color,
        value: modeEntry.value.toDouble(),
        title: isTouched ? '$percentage%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();
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
      case 'motorcycle':
        return Colors.indigo;
      case 'taxi':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  String _formatModeName(String mode) {
    switch (mode.toLowerCase()) {
      case 'public_transport':
        return 'Public Transport';
      case 'motorcycle':
        return 'Motorcycle';
      default:
        return mode.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}



