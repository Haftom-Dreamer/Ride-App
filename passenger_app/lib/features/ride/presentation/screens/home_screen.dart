import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/ride_request_bottom_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          MapWidget(
            mapController: _mapController,
            currentLocation: _currentLocation,
            pickupLocation: _pickupLocation,
            destinationLocation: _destinationLocation,
            onLocationUpdate: (location) {
              setState(() {
                _currentLocation = location;
              });
            },
            onPickupSelected: (location) {
              setState(() {
                _pickupLocation = location;
              });
            },
            onDestinationSelected: (location) {
              setState(() {
                _destinationLocation = location;
              });
            },
          ),
          
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      user?.username.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.username ?? 'User'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Where would you like to go?',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Show profile or settings
                      _showProfileMenu(context);
                    },
                    icon: const Icon(Icons.menu),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RideRequestBottomSheet(
              pickupLocation: _pickupLocation,
              destinationLocation: _destinationLocation,
              onRequestRide: () {
                // Handle ride request
                _handleRideRequest();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ride History'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to ride history
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleRideRequest() {
    if (_pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pickup and destination locations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // TODO: Implement ride request logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ride request functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
