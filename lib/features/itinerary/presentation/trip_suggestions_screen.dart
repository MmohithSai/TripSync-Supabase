import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../common/providers.dart';
import '../../location/service/location_controller.dart';
import '../domain/itinerary_models.dart';
import '../service/places_service.dart';
import '../data/itinerary_repository.dart';

class TripSuggestionsScreen extends ConsumerStatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? tripId;

  const TripSuggestionsScreen({
    super.key,
    this.latitude,
    this.longitude,
    this.tripId,
  });

  @override
  ConsumerState<TripSuggestionsScreen> createState() => _TripSuggestionsScreenState();
}

class _TripSuggestionsScreenState extends ConsumerState<TripSuggestionsScreen> {
  List<TripSuggestion> _suggestions = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  double _radius = 5.0;

  final List<String> _categories = [
    'All',
    'attraction',
    'restaurant',
    'shopping',
    'museum',
  ];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    
    try {
      final currentPosition = widget.latitude != null && widget.longitude != null
          ? Position(
              latitude: widget.latitude!,
              longitude: widget.longitude!,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            )
          : ref.read(locationControllerProvider).currentPosition;

      if (currentPosition != null) {
        final suggestions = PlacesService.getTripSuggestions(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          radiusKm: _radius,
        );

        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading suggestions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Suggestions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuggestions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(),
          // Suggestions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _suggestions.isEmpty
                    ? const Center(
                        child: Text('No suggestions found. Try adjusting your filters.'),
                      )
                    : ListView.builder(
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return _buildSuggestionCard(suggestion);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Category filter
          Row(
            children: [
              const Text('Category: '),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category == 'All' ? 'All Categories' : category.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                    _loadSuggestions();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Radius slider
          Row(
            children: [
              const Text('Radius: '),
              Expanded(
                child: Slider(
                  value: _radius,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: '${_radius.toStringAsFixed(1)} km',
                  onChanged: (value) {
                    setState(() {
                      _radius = value;
                    });
                    _loadSuggestions();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(TripSuggestion suggestion) {
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
                        suggestion.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (suggestion.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      suggestion.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.place),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${suggestion.rating.toStringAsFixed(1)}'),
                const SizedBox(width: 8),
                Icon(Icons.people, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Text('${suggestion.reviewCount}'),
                const SizedBox(width: 8),
                Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Text('${(suggestion.distanceFromUser / 1000).toStringAsFixed(1)} km'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.reason,
              style: TextStyle(
                color: Colors.blue[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addToItinerary(suggestion),
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Itinerary'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewOnMap(suggestion),
                    icon: const Icon(Icons.map),
                    label: const Text('View on Map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addToItinerary(TripSuggestion suggestion) async {
    if (widget.tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active trip to add to itinerary')),
      );
      return;
    }

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) return;

      final repository = ref.read(itineraryRepositoryProvider);
      
      // Create itinerary item
      final item = ItineraryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        placeId: suggestion.id,
        name: suggestion.title,
        description: suggestion.description,
        latitude: suggestion.latitude,
        longitude: suggestion.longitude,
        category: suggestion.category,
        order: 0, // Will be updated when adding to itinerary
        estimatedDuration: suggestion.estimatedVisitDuration,
        isCompleted: false,
        rating: suggestion.rating,
        imageUrl: suggestion.imageUrl,
      );

      // For now, create a new itinerary for each suggestion
      // In a real app, you might want to add to an existing itinerary
      await repository.createItinerary(
        uid: user.uid,
        tripId: widget.tripId!,
        title: 'Trip to ${suggestion.title}',
        description: 'Visit ${suggestion.title}',
        items: [item],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${suggestion.title} to itinerary')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to itinerary: $e')),
        );
      }
    }
  }

  void _viewOnMap(TripSuggestion suggestion) {
    // Navigate to map screen with the suggestion location
    Navigator.of(context).pop({
      'latitude': suggestion.latitude,
      'longitude': suggestion.longitude,
      'title': suggestion.title,
    });
  }
}
