import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../location/service/location_controller.dart';
import '../data/places_repository.dart';
import '../../../common/providers.dart';
import '../../trips/service/trip_controller.dart';
import '../../trips/domain/trip_models.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  StreamSubscription? _followSub;

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
    final user = ref.watch(currentUserProvider);
    final placesRepo = ref.read(placesRepositoryProvider);
    final position = locationState.currentPosition;
    final tripState = ref.watch(tripControllerProvider);

    // Permission and service prompts are handled globally by PermissionGate

    return Scaffold(
      appBar: AppBar(title: const Text('Live Map')),
      body: Stack(
        children: [
          StreamBuilder<List<SavedPlace>>(
            stream: user == null
                ? const Stream.empty()
                : placesRepo.watchPlaces(user.id),
            builder: (context, snapshot) {
              final places = snapshot.data ?? const <SavedPlace>[];
              final placeMarkers = places
                  .map(
                    (p) => Marker(
                      markerId: MarkerId('place_${p.id}'),
                      position: LatLng(p.latitude, p.longitude),
                      infoWindow: InfoWindow(title: p.label),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  )
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
                  _followSub = ref
                      .read(locationControllerProvider.notifier)
                      .positionStream
                      .listen((p) {
                        if (_mapController == null) return;
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLng(
                            LatLng(p.latitude, p.longitude),
                          ),
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
                      TextEditingController controller =
                          TextEditingController();
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Save place',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                ActionChip(
                                  label: const Text('Home'),
                                  onPressed: () =>
                                      Navigator.pop(context, 'Home'),
                                ),
                                ActionChip(
                                  label: const Text('Office'),
                                  onPressed: () =>
                                      Navigator.pop(context, 'Office'),
                                ),
                                ActionChip(
                                  label: const Text('Custom…'),
                                  onPressed: () =>
                                      Navigator.pop(context, '__custom__'),
                                ),
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
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () {
                                    final txt = controller.text.trim();
                                    Navigator.pop(
                                      context,
                                      txt.isEmpty ? 'Place' : txt,
                                    );
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  if (label == null) return;
                  final resolvedLabel = label == '__custom__' ? 'Place' : label;
                  await placesRepo.addPlace(
                    uid: user.id,
                    label: resolvedLabel,
                    latitude: latLng.latitude,
                    longitude: latLng.longitude,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Place saved')));
                },
                polylines: {
                  if (tripState.bufferedPoints.length >= 2)
                    Polyline(
                      polylineId: const PolylineId('active_trip'),
                      color: Colors.indigo,
                      width: 4,
                      points: tripState.bufferedPoints
                          .map((p) => LatLng(p.latitude, p.longitude))
                          .toList(),
                    ),
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
            right: 16,
            bottom: 24,
            child: Row(
              children: [
                Expanded(
                  child: FloatingActionButton.extended(
                    heroTag: 'locate_me',
                    icon: const Icon(Icons.my_location),
                    label: const Text('Locate'),
                    onPressed: () async {
                      final controller = ref.read(
                        locationControllerProvider.notifier,
                      );
                      final s = ref.read(locationControllerProvider);
                      if (!s.permissionsGranted) {
                        await controller.requestPermissions();
                      }
                      await controller.refreshNow();
                      final p = ref
                          .read(locationControllerProvider)
                          .currentPosition;
                      if (p != null && _mapController != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLng(
                            LatLng(p.latitude, p.longitude),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FloatingActionButton.extended(
                    heroTag: 'trip_toggle',
                    icon: Icon(
                      tripState.activeTripId == null
                          ? Icons.play_arrow
                          : Icons.stop,
                    ),
                    label: Text(
                      tripState.activeTripId == null ? 'Start' : 'Stop',
                    ),
                    onPressed: () async {
                      print(
                        '🔘 Button pressed - current activeTripId: ${tripState.activeTripId}',
                      );
                      final ctrl = ref.read(tripControllerProvider.notifier);
                      final loc = ref.read(locationControllerProvider);
                      // Basic guardrails and UX feedback
                      if (!loc.permissionsGranted) {
                        await ref
                            .read(locationControllerProvider.notifier)
                            .requestPermissions();
                      }
                      if (!mounted) return;
                      try {
                        if (tripState.activeTripId == null) {
                          // Skip destination dialog - will be auto-detected

                          // Then prompt for other manual details
                          final result =
                              await showModalBottomSheet<
                                ({
                                  TripMode? mode,
                                  TripPurpose? purpose,
                                  String? destinationRegion,
                                  String? originRegion,
                                  int adults,
                                  int children,
                                  int seniors,
                                })
                              >(
                                context: context,
                                showDragHandle: true,
                                isScrollControlled: true,
                                builder: (context) {
                                  TripMode? selMode;
                                  TripPurpose? selPurpose;
                                  final destController =
                                      TextEditingController();
                                  final originController =
                                      TextEditingController();
                                  int adults = 0;
                                  int children = 0;
                                  int seniors = 0;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          MediaQuery.of(
                                            context,
                                          ).viewInsets.bottom +
                                          16,
                                      left: 16,
                                      right: 16,
                                      top: 16,
                                    ),
                                    child: StatefulBuilder(
                                      builder: (context, setSheetState) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Start trip',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 12),
                                            DropdownButtonFormField<TripMode?>(
                                              value: selMode,
                                              items: [
                                                const DropdownMenuItem(
                                                  value: null,
                                                  child: Text('None'),
                                                ),
                                                ...TripMode.values
                                                    .map(
                                                      (m) => DropdownMenuItem(
                                                        value: m,
                                                        child: Text(m.name),
                                                      ),
                                                    )
                                                    .toList(),
                                              ],
                                              onChanged: (v) => setSheetState(
                                                () => selMode = v,
                                              ),
                                              decoration: const InputDecoration(
                                                labelText: 'Mode (optional)',
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<
                                              TripPurpose?
                                            >(
                                              value: selPurpose,
                                              items: [
                                                const DropdownMenuItem(
                                                  value: null,
                                                  child: Text('None'),
                                                ),
                                                ...TripPurpose.values
                                                    .map(
                                                      (p) => DropdownMenuItem(
                                                        value: p,
                                                        child: Text(p.name),
                                                      ),
                                                    )
                                                    .toList(),
                                              ],
                                              onChanged: (v) => setSheetState(
                                                () => selPurpose = v,
                                              ),
                                              decoration: const InputDecoration(
                                                labelText: 'Purpose (optional)',
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: destController,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Destination region (optional)',
                                                hintText:
                                                    'e.g. Downtown, Sector 21, City Center',
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: originController,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Origin region (optional)',
                                                hintText:
                                                    'e.g. Home area, Sector 12',
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Passengers',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(child: Text('Adults')),
                                                IconButton(
                                                  onPressed: () =>
                                                      setSheetState(
                                                        () =>
                                                            adults = adults > 0
                                                            ? adults - 1
                                                            : 0,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                  ),
                                                ),
                                                Text('$adults'),
                                                IconButton(
                                                  onPressed: () =>
                                                      setSheetState(
                                                        () =>
                                                            adults = adults + 1,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text('Children'),
                                                ),
                                                IconButton(
                                                  onPressed: () =>
                                                      setSheetState(
                                                        () => children =
                                                            children > 0
                                                            ? children - 1
                                                            : 0,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                  ),
                                                ),
                                                Text('$children'),
                                                IconButton(
                                                  onPressed: () =>
                                                      setSheetState(
                                                        () => children =
                                                            children + 1,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text('Seniors'),
                                                ),
                                                IconButton(
                                                  onPressed: () =>
                                                      setSheetState(
                                                        () => seniors =
                                                            seniors > 0
                                                            ? seniors - 1
                                                            : 0,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                  ),
                                                ),
                                                Text('$seniors'),
                                                IconButton(
                                                  onPressed: () =>
                                                      setSheetState(
                                                        () => seniors =
                                                            seniors + 1,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                const SizedBox(width: 8),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop<
                                                        ({
                                                          TripMode? mode,
                                                          TripPurpose? purpose,
                                                          String?
                                                          destinationRegion,
                                                          String? originRegion,
                                                          int adults,
                                                          int children,
                                                          int seniors,
                                                        })
                                                      >(context, (
                                                        mode: selMode,
                                                        purpose: selPurpose,
                                                        destinationRegion:
                                                            destController.text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : destController
                                                                  .text
                                                                  .trim(),
                                                        originRegion:
                                                            originController
                                                                .text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : originController
                                                                  .text
                                                                  .trim(),
                                                        adults: adults,
                                                        children: children,
                                                        seniors: seniors,
                                                      )),
                                                  child: const Text('Start'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                          if (result == null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Trip start cancelled'),
                              ),
                            );
                            return;
                          }
                          await ctrl.startManual(
                            mode: result?.mode ?? TripMode.unknown,
                            purpose: result?.purpose ?? TripPurpose.unknown,
                            // Destination will be auto-detected from GPS
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trip started')),
                          );
                        } else {
                          // Add loading indicator and timeout for stop
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Stopping trip...'),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          try {
                            await ctrl.stopManual().timeout(
                              const Duration(seconds: 10),
                              onTimeout: () {
                                print(
                                  '⚠️ Stop trip timeout - forcing local stop',
                                );
                                return null;
                              },
                            );
                            if (!mounted) return;
                            print(
                              '🔘 After stop - activeTripId: ${ref.read(tripControllerProvider).activeTripId}',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trip stopped')),
                            );
                          } catch (e) {
                            print('❌ Stop trip error: $e');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trip stopped')),
                            );
                          }
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Action failed: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // No extra in-app permission banner; rely on OS dialog and Settings flow
        ],
      ),
    );
  }
}
