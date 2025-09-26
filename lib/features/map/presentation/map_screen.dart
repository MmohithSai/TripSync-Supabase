import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../location/service/location_controller.dart';
import '../data/places_repository.dart';
import '../../../common/providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  StreamSubscription? _followSub;
  bool _promptedForService = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _followSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Coming back from Settings or background: refresh immediately
      ref.read(locationControllerProvider.notifier).refreshNow();
      final p = ref.read(locationControllerProvider).currentPosition;
      if (p != null && _mapController != null) {
        _mapController!.moveCamera(
          CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationControllerProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final placesRepo = ref.read(placesRepositoryProvider);
    final position = locationState.currentPosition;


    // Permission and service prompts are handled globally by PermissionGate

    return Scaffold(
      appBar: AppBar(title: const Text('Live Map')),
      body: Stack(
        children: [
          StreamBuilder<List<SavedPlace>>(
            stream: user == null ? const Stream.empty() : placesRepo.watchPlaces(user.uid),
            builder: (context, snapshot) {
              final places = snapshot.data ?? const <SavedPlace>[];
              final placeMarkers = places
                  .map((p) => Marker(
                        markerId: MarkerId('place_${p.id}'),
                        position: LatLng(p.latitude, p.longitude),
                        infoWindow: InfoWindow(title: p.label),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      ))
                  .toSet();
              return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: position != null
                  ? LatLng(position.latitude, position.longitude)
                  : const LatLng(37.42796133580664, -122.085749655962),
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            padding: const EdgeInsets.only(bottom: 90, left: 8, right: 8),
            onMapCreated: (c) {
              _mapController = c;
              _followSub?.cancel();
              _followSub = ref.read(locationControllerProvider.notifier).positionStream.listen((p) {
                if (_mapController == null) return;
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
                );
              });
            // Trigger an immediate refresh to move camera to the latest fix
            ref.read(locationControllerProvider.notifier).refreshNow();
            },
            onLongPress: (latLng) async {
              if (user == null) return;
              final label = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (context) {
                  TextEditingController controller = TextEditingController();
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Save place', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(label: const Text('Home'), onPressed: () => Navigator.pop(context, 'Home')),
                            ActionChip(label: const Text('Office'), onPressed: () => Navigator.pop(context, 'Office')),
                            ActionChip(label: const Text('Custom…'), onPressed: () => Navigator.pop(context, '__custom__')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Custom label',
                            hintText: 'e.g. Gym, School, Grocery',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                final txt = controller.text.trim();
                                Navigator.pop(context, txt.isEmpty ? 'Place' : txt);
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
              if (label == null) return;
              final resolvedLabel = label == '__custom__' ? 'Place' : label;
              await placesRepo.addPlace(
                uid: user.uid,
                label: resolvedLabel,
                latitude: latLng.latitude,
                longitude: latLng.longitude,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Place saved')),
              );
            },
            markers: {
              if (position != null)
                Marker(
                  markerId: const MarkerId('me'),
                  position: LatLng(position.latitude, position.longitude),
                ),
              ...placeMarkers,
            },
          );
            },
          ),
          Positioned(
            left: 16,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'locate_me',
              icon: const Icon(Icons.my_location),
              label: const Text('Locate me'),
              onPressed: () async {
                final controller = ref.read(locationControllerProvider.notifier);
                final state = ref.read(locationControllerProvider);
                if (!state.permissionsGranted) {
                  await controller.requestPermissions();
                }
                await controller.refreshNow();
                final p = ref.read(locationControllerProvider).currentPosition;
                if (p != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
                  );
                }
              },
            ),
          ),
          // No extra in-app permission banner; rely on OS dialog and Settings flow
        ],
      ),
    );
  }
}




