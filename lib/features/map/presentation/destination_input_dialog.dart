import 'package:flutter/material.dart';
import '../../location/service/place_search_service.dart';

class DestinationInputDialog extends StatefulWidget {
  final String? initialDestination;

  const DestinationInputDialog({super.key, this.initialDestination});

  @override
  State<DestinationInputDialog> createState() => _DestinationInputDialogState();
}

class _DestinationInputDialogState extends State<DestinationInputDialog> {
  final TextEditingController _controller = TextEditingController();
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialDestination ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await PlaceSearchService.searchPlaces(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Destination'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Type destination name or address',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _searchPlaces,
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(result.name),
                      subtitle: Text(result.formattedAddress),
                      onTap: () {
                        Navigator.of(context).pop({
                          'name': result.name,
                          'address': result.formattedAddress,
                          'latitude': result.latitude,
                          'longitude': result.longitude,
                          'placeId': result.placeId,
                        });
                      },
                    );
                  },
                ),
              )
            else if (_controller.text.isNotEmpty && !_isSearching)
              const Text(
                'No results found. Try a different search term.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop({
                'name': text,
                'address': text,
                'latitude': null,
                'longitude': null,
                'placeId': null,
              });
            }
          },
          child: const Text('Use Text'),
        ),
      ],
    );
  }
}












