import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../domain/itinerary_models.dart';
import '../data/itinerary_repository.dart';
import 'trip_suggestions_screen.dart';

class ItineraryScreen extends ConsumerWidget {
  final String? tripId;

  const ItineraryScreen({
    super.key,
    this.tripId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view itineraries')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Itineraries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateItineraryDialog(context, ref),
          ),
        ],
      ),
      body: tripId != null
          ? _buildTripItineraries(context, ref, user.uid)
          : _buildAllItineraries(context, ref, user.uid),
    );
  }

  Widget _buildTripItineraries(BuildContext context, WidgetRef ref, String uid) {
    final itinerariesStream = ref.watch(itineraryRepositoryProvider).getTripItineraries(uid, tripId!);
    
    return StreamBuilder<List<TripItinerary>>(
      stream: itinerariesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final itineraries = snapshot.data ?? [];
        
        if (itineraries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.route, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No itineraries for this trip yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create an itinerary to plan your trip',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateItineraryDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Itinerary'),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: itineraries.length,
          itemBuilder: (context, index) {
            final itinerary = itineraries[index];
            return _buildItineraryCard(context, ref, itinerary);
          },
        );
      },
    );
  }

  Widget _buildAllItineraries(BuildContext context, WidgetRef ref, String uid) {
    final itinerariesStream = ref.watch(itineraryRepositoryProvider).getUserItineraries(uid);
    
    return StreamBuilder<List<TripItinerary>>(
      stream: itinerariesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final itineraries = snapshot.data ?? [];
        
        if (itineraries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.route, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No itineraries yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first itinerary to start planning',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateItineraryDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Itinerary'),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: itineraries.length,
          itemBuilder: (context, index) {
            final itinerary = itineraries[index];
            return _buildItineraryCard(context, ref, itinerary);
          },
        );
      },
    );
  }

  Widget _buildItineraryCard(BuildContext context, WidgetRef ref, TripItinerary itinerary) {
    final completedItems = itinerary.items.where((item) => item.isCompleted).length;
    final totalItems = itinerary.items.length;
    final progress = totalItems > 0 ? completedItems / totalItems : 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itinerary.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itinerary.description,
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (itinerary.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.route, color: Colors.blue[600], size: 16),
                const SizedBox(width: 4),
                Text('${totalItems} places'),
                const SizedBox(width: 16),
                Icon(Icons.access_time, color: Colors.orange[600], size: 16),
                const SizedBox(width: 4),
                Text('${itinerary.estimatedDuration} min'),
                const SizedBox(width: 16),
                Icon(Icons.straighten, color: Colors.green[600], size: 16),
                const SizedBox(width: 4),
                Text('${(itinerary.totalDistance / 1000).toStringAsFixed(1)} km'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completedItems of $totalItems completed',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewItineraryDetails(context, ref, itinerary),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addMorePlaces(context, ref),
                    icon: const Icon(Icons.add_location),
                    label: const Text('Add Places'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateItineraryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Itinerary'),
        content: const Text('Would you like to discover nearby places to add to your itinerary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _discoverPlaces(context, ref);
            },
            child: const Text('Discover Places'),
          ),
        ],
      ),
    );
  }

  void _discoverPlaces(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TripSuggestionsScreen(
          tripId: tripId,
        ),
      ),
    );
  }

  void _viewItineraryDetails(BuildContext context, WidgetRef ref, TripItinerary itinerary) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ItineraryDetailsScreen(itinerary: itinerary),
      ),
    );
  }

  void _addMorePlaces(BuildContext context, WidgetRef ref) {
    _discoverPlaces(context, ref);
  }
}

class ItineraryDetailsScreen extends ConsumerWidget {
  final TripItinerary itinerary;

  const ItineraryDetailsScreen({
    super.key,
    required this.itinerary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(itinerary.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TripSuggestionsScreen(
                    tripId: itinerary.tripId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: itinerary.items.length,
        itemBuilder: (context, index) {
          final item = itinerary.items[index];
          return _buildItineraryItemCard(context, ref, item);
        },
      ),
    );
  }

  Widget _buildItineraryItemCard(BuildContext context, WidgetRef ref, ItineraryItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isCompleted ? Colors.green : Colors.blue,
          child: Icon(
            item.isCompleted ? Icons.check : Icons.place,
            color: Colors.white,
          ),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${item.rating.toStringAsFixed(1)}'),
                const SizedBox(width: 16),
                Icon(Icons.access_time, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text('${item.estimatedDuration} min'),
              ],
            ),
          ],
        ),
        trailing: Checkbox(
          value: item.isCompleted,
          onChanged: (value) {
            // Mark item as completed
            final user = ref.read(firebaseAuthProvider).currentUser;
            if (user != null) {
              ref.read(itineraryRepositoryProvider).markItemCompleted(
                uid: user.uid,
                itineraryId: itinerary.id,
                itemId: item.id,
                isCompleted: value ?? false,
              );
            }
          },
        ),
        onTap: () {
          // Show item details or navigate to location
        },
      ),
    );
  }
}


