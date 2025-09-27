import 'package:flutter/material.dart';

class ExportControlsWidget extends StatelessWidget {
  final VoidCallback onExportCSV;
  final VoidCallback onExportGeoJSON;
  final VoidCallback onExportPDF;

  const ExportControlsWidget({
    super.key,
    required this.onExportCSV,
    required this.onExportGeoJSON,
    required this.onExportPDF,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Export Data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildExportButton(
                  'CSV',
                  Icons.table_chart,
                  Colors.green,
                  onExportCSV,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildExportButton(
                  'GeoJSON',
                  Icons.map,
                  Colors.blue,
                  onExportGeoJSON,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildExportButton(
                  'PDF',
                  Icons.picture_as_pdf,
                  Colors.red,
                  onExportPDF,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}



