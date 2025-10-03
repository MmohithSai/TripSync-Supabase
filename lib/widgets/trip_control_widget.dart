import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/backend_service.dart';
import 'location_permission_guide.dart';

class TripControlWidget extends StatefulWidget {
  const TripControlWidget({super.key});

  @override
  State<TripControlWidget> createState() => _TripControlWidgetState();
}

class _TripControlWidgetState extends State<TripControlWidget> {
  final BackendService _backendService = BackendService();
  bool _isLoading = false;
  bool _isExpanded = false;
  bool _isConnected = false;
  String _currentState = 'idle';
  bool _hasBackgroundAccess = false;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    // Check location permissions
    await _checkLocationPermissions();

    // First check if user is authenticated
    if (!_backendService.isAuthenticated) {
      setState(() {
        _isConnected = false;
      });
      return;
    }

    try {
      final result = await _backendService.testConnection();
      setState(() {
        _isConnected = result != null;
      });
      if (_isConnected) {
        _refreshState();
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _checkLocationPermissions() async {
    try {
      final permission = await Geolocator.checkPermission();
      setState(() {
        _hasBackgroundAccess = permission == LocationPermission.always;
      });
    } catch (e) {
      setState(() {
        _hasBackgroundAccess = false;
      });
    }
  }

  Future<void> _refreshState() async {
    if (!_isConnected) return;

    try {
      final tripState = await _backendService.getTripState();
      setState(() {
        _currentState = tripState?['state']?['state'] ?? 'idle';
      });
    } catch (e) {
      // Silently handle errors - don't show intrusive messages
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _startTrip() async {
    if (!_isConnected) {
      _showMessage('Backend not connected', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _backendService.startTrip();
      if (result != null && result['success'] == true) {
        _showMessage('Trip started successfully!', isError: false);
        _refreshState();
      } else {
        _showMessage('Could not start trip. Try again.', isError: true);
      }
    } catch (e) {
      _showMessage('Failed to start trip', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _stopTrip() async {
    if (!_isConnected) {
      _showMessage('Backend not connected', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _backendService.stopTrip();
      if (result != null && result['success'] == true) {
        _showMessage('Trip stopped successfully!', isError: false);
        _refreshState();
      } else {
        _showMessage('Could not stop trip. Try again.', isError: true);
      }
    } catch (e) {
      _showMessage('Failed to stop trip', isError: true);
    }
    setState(() => _isLoading = false);
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Login Required'),
        content: const Text(
          'You need to be logged in to use the trip recording features. Please log in through the app first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionGuide() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: LocationPermissionGuide(
          onDismiss: () {
            Navigator.pop(context);
            _checkLocationPermissions(); // Refresh permission status
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If not authenticated, show login prompt
    if (!_backendService.isAuthenticated) {
      return Positioned(
        top: 16,
        right: 16,
        child: GestureDetector(
          onTap: () => _showLoginPrompt(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'Login Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If not connected, show a minimal floating button
    if (!_isConnected) {
      return Positioned(
        top: 16,
        right: 16,
        child: FloatingActionButton.small(
          onPressed: _initializeConnection,
          backgroundColor: Colors.grey,
          child: const Icon(Icons.cloud_off, color: Colors.white),
        ),
      );
    }

    // If connected but collapsed, show a small trip status indicator
    if (!_isExpanded) {
      return Positioned(
        top: 16,
        right: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Location permission warning banner
            if (!_hasBackgroundAccess)
              GestureDetector(
                onTap: _showLocationPermissionGuide,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Limited Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Main status indicator
            GestureDetector(
              onTap: () => setState(() => _isExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _currentState == 'active' ? Colors.green : Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentState == 'active'
                          ? Icons.play_circle
                          : Icons.pause_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentState == 'active' ? 'Recording' : 'Ready',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Expanded view with controls
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                children: [
                  Icon(
                    _currentState == 'active'
                        ? Icons.play_circle
                        : Icons.pause_circle,
                    color: _currentState == 'active'
                        ? Colors.green
                        : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentState == 'active' ? 'Trip Recording' : 'Trip Ready',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _isExpanded = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Control buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _currentState == 'active'
                          ? null
                          : _startTrip,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _currentState != 'active'
                          ? null
                          : _stopTrip,
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
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
}
