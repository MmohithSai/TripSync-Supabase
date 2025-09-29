import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../trips/domain/trip_models.dart';
import '../../trips/data/trip_repository.dart';
import '../data/history_repository.dart';
import '../../../common/providers.dart';

class BatchEditScreen extends ConsumerStatefulWidget {
  final List<String> selectedTripIds;
  final VoidCallback onTripsUpdated;

  const BatchEditScreen({
    super.key,
    required this.selectedTripIds,
    required this.onTripsUpdated,
  });

  @override
  ConsumerState<BatchEditScreen> createState() => _BatchEditScreenState();
}

class _BatchEditScreenState extends ConsumerState<BatchEditScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMode;
  String? _selectedPurpose;
  bool? _isRecurring;
  String? _destinationRegion;
  String? _originRegion;
  bool _isLoading = false;

  final List<String> _modes = [
    'walking',
    'cycling',
    'driving',
    'public_transport',
    'train',
    'bus',
    'motorcycle',
    'taxi',
  ];

  final List<String> _purposes = [
    'work',
    'education',
    'shopping',
    'leisure',
    'health',
    'personal',
  ];

  final List<String> _regions = [
    'North',
    'South',
    'East',
    'West',
    'Central',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Batch Edit ${widget.selectedTripIds.length} Trips'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You are editing ${widget.selectedTripIds.length} trips. Changes will be applied to all selected trips.',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Mode selection
              _buildSectionTitle('Transport Mode'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMode,
                decoration: const InputDecoration(
                  labelText: 'Mode (optional)',
                  hintText: 'Leave unchanged',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Leave unchanged'),
                  ),
                  ..._modes.map((mode) => DropdownMenuItem<String>(
                    value: mode,
                    child: Text(_formatModeName(mode)),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMode = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Purpose selection
              _buildSectionTitle('Trip Purpose'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPurpose,
                decoration: const InputDecoration(
                  labelText: 'Purpose (optional)',
                  hintText: 'Leave unchanged',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Leave unchanged'),
                  ),
                  ..._purposes.map((purpose) => DropdownMenuItem<String>(
                    value: purpose,
                    child: Text(_formatPurposeName(purpose)),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPurpose = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Recurring trips
              _buildSectionTitle('Recurring Trips'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      RadioListTile<bool?>(
                        title: const Text('Leave unchanged'),
                        value: null,
                        groupValue: _isRecurring,
                        onChanged: (value) {
                          setState(() {
                            _isRecurring = value;
                          });
                        },
                      ),
                      RadioListTile<bool>(
                        title: const Text('Mark as recurring'),
                        value: true,
                        groupValue: _isRecurring,
                        onChanged: (value) {
                          setState(() {
                            _isRecurring = value;
                          });
                        },
                      ),
                      RadioListTile<bool>(
                        title: const Text('Mark as non-recurring'),
                        value: false,
                        groupValue: _isRecurring,
                        onChanged: (value) {
                          setState(() {
                            _isRecurring = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Origin region
              _buildSectionTitle('Origin Region'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _originRegion,
                decoration: const InputDecoration(
                  labelText: 'Origin Region (optional)',
                  hintText: 'Leave unchanged',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Leave unchanged'),
                  ),
                  ..._regions.map((region) => DropdownMenuItem<String>(
                    value: region,
                    child: Text(region),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _originRegion = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Destination region
              _buildSectionTitle('Destination Region'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _destinationRegion,
                decoration: const InputDecoration(
                  labelText: 'Destination Region (optional)',
                  hintText: 'Leave unchanged',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Leave unchanged'),
                  ),
                  ..._regions.map((region) => DropdownMenuItem<String>(
                    value: region,
                    child: Text(region),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _destinationRegion = value;
                  });
                },
              ),
              const SizedBox(height: 32),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _applyChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Apply Changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
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

  String _formatPurposeName(String purpose) {
    return purpose.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Future<void> _applyChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final repository = ref.read(tripRepositoryProvider);
        
        // Create update map with only non-null values
        final updateData = <String, dynamic>{};
        
        if (_selectedMode != null) {
          updateData['mode'] = _selectedMode;
        }
        
        if (_selectedPurpose != null) {
          updateData['purpose'] = _selectedPurpose;
        }
        
        if (_isRecurring != null) {
          updateData['isRecurring'] = _isRecurring;
        }
        
        if (_originRegion != null) {
          updateData['originRegion'] = _originRegion;
        }
        
        if (_destinationRegion != null) {
          updateData['destinationRegion'] = _destinationRegion;
        }

        // Apply changes to all selected trips
        final user = ref.read(currentUserProvider);
        if (user != null) {
          await repository.batchUpdateTrips(
            uid: user.id,
            tripIds: widget.selectedTripIds,
            mode: _selectedMode != null ? TripMode.values.firstWhere((m) => m.toString() == _selectedMode) : null,
            purpose: _selectedPurpose != null ? TripPurpose.values.firstWhere((p) => p.toString() == _selectedPurpose) : null,
            companions: null, // Companions not implemented in this screen
            destinationRegion: _destinationRegion,
            originRegion: _originRegion,
            tripNumber: null, // Trip number not implemented in this screen
            chainId: null, // Chain ID not implemented in this screen
          );
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully updated ${widget.selectedTripIds.length} trips'),
              backgroundColor: Colors.green[600],
            ),
          );
          
          // Notify parent and close
          widget.onTripsUpdated();
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating trips: $e'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}



