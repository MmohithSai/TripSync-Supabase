import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/dashboard_models.dart';

class HeatmapWidget extends StatefulWidget {
  final List<TripData> tripData;
  final Function(TripData) onTripSelected;

  const HeatmapWidget({
    super.key,
    required this.tripData,
    required this.onTripSelected,
  });

  @override
  State<HeatmapWidget> createState() => _HeatmapWidgetState();
}

class _HeatmapWidgetState extends State<HeatmapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLngBounds? _bounds;

  @override
  void initState() {
    super.initState();
    _updateMapData();
  }

  @override
  void didUpdateWidget(HeatmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripData != widget.tripData) {
      _updateMapData();
    }
  }

  void _updateMapData() {
    if (widget.tripData.isEmpty) {
      setState(() {
        _markers = {};
        _polylines = {};
        _bounds = null;
      });
      return;
    }

    final markers = <Marker>{};
    final polylines = <Polyline>{};
    LatLngBounds bounds = LatLngBounds(
      southwest: const LatLng(0, 0),
      northeast: const LatLng(0, 0),
    );

    for (int i = 0; i < widget.tripData.length; i++) {
      final trip = widget.tripData[i];
      
      if (trip.points.isNotEmpty) {
        // Create polyline for trip path
        final points = trip.points.map((point) => LatLng(point.latitude, point.longitude)).toList();
        
        polylines.add(Polyline(
          polylineId: PolylineId('trip_${trip.id}'),
          points: points,
          color: _getTripColor(trip.mode),
          width: 3,
          patterns: trip.isRecurring ? [PatternItem.dash(20), PatternItem.gap(10)] : [],
        ));

        // Add start marker
        markers.add(Marker(
          markerId: MarkerId('start_${trip.id}'),
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Start: ${trip.mode}',
            snippet: '${trip.distanceMeters.toStringAsFixed(0)}m',
          ),
          onTap: () => widget.onTripSelected(trip),
        ));

        // Add end marker if trip has ended
        if (trip.endedAt != null && points.length > 1) {
          markers.add(Marker(
            markerId: MarkerId('end_${trip.id}'),
            position: points.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'End: ${trip.mode}',
              snippet: '${trip.distanceMeters.toStringAsFixed(0)}m',
            ),
            onTap: () => widget.onTripSelected(trip),
          ));
        }

        // Expand bounds to include all points
        for (final point in points) {
          if (bounds.southwest.latitude == 0 && bounds.southwest.longitude == 0) {
            bounds = LatLngBounds(southwest: point, northeast: point);
          } else {
            final minLat = bounds.southwest.latitude < point.latitude ? bounds.southwest.latitude : point.latitude;
            final maxLat = bounds.northeast.latitude > point.latitude ? bounds.northeast.latitude : point.latitude;
            final minLng = bounds.southwest.longitude < point.longitude ? bounds.southwest.longitude : point.longitude;
            final maxLng = bounds.northeast.longitude > point.longitude ? bounds.northeast.longitude : point.longitude;
            bounds = LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            );
          }
        }
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
      _bounds = bounds;
    });

    // Fit map to bounds
    if (_mapController != null && bounds.northeast.latitude != bounds.southwest.latitude) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  Color _getTripColor(String mode) {
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

  @override
  Widget build(BuildContext context) {
    if (widget.tripData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No trip data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Select a different date or region',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (_bounds != null) {
              controller.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 100));
            }
          },
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            zoom: 2,
          ),
          markers: _markers,
          polylines: _polylines,
          mapType: MapType.normal,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
        ),
        // Legend
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Modes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildLegendItem('Walking', Colors.green),
                _buildLegendItem('Cycling', Colors.blue),
                _buildLegendItem('Driving', Colors.red),
                _buildLegendItem('Public Transport', Colors.purple),
                _buildLegendItem('Train', Colors.orange),
                _buildLegendItem('Bus', Colors.teal),
                const SizedBox(height: 8),
                const Text(
                  'Dashed lines = Recurring trips',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        // Trip count
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.tripData.length} trips',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 3,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}



