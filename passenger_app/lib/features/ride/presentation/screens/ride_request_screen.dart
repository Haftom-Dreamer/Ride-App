import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/map_widget.dart';
import '../widgets/address_autocomplete_widget.dart';
import '../services/geocoding_service.dart';
import '../../../../shared/domain/models/ride.dart';
import '../../../../shared/domain/models/driver.dart';

enum RideStatus {
  home, // New initial state
  searching, // When user is searching for destination
  rideConfirmation, // When pickup and destination are set
  waiting, // Finding driver
  assigned, // Driver found
  onTrip,
  completed,
  canceled,
}

class RideRequestScreen extends ConsumerStatefulWidget {
  const RideRequestScreen({super.key});

  @override
  ConsumerState<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends ConsumerState<RideRequestScreen> {
  final MapController _mapController = MapController();

  // Location data
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  String _pickupAddress = '';
  String _destinationAddress = '';

  // Ride configuration
  RideType _selectedRideType = RideType.standard;
  final String _selectedPayment = 'Cash';
  final String _rideNote = '';
  double? _estimatedFare;
  double? _distanceKm;

  // Ride state
  RideStatus _currentStatus = RideStatus.home;
  Driver? _assignedDriver;

  // Polling for ride status
  bool _isPolling = false;
  // Debounce timer for map center movement to avoid frequent reverse-geocoding
  Timer? _moveDebounce;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _stopPolling();
    _moveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _pickupLocation =
            _currentLocation; // Set pickup to current location by default
      });

      // Move map to current location
      _mapController.move(_currentLocation!, 15.0);

      // Get address for current location
      _updatePickupAddress(_currentLocation!);
    } catch (e) {
      print('Error getting current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not get your location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updatePickupAddress(LatLng location) async {
    final address = await GeocodingService.coordinatesToAddress(location);
          setState(() {
      _pickupAddress = address ?? 'Current Location';
          });
      }

  Future<void> _updateDestinationAddress(LatLng location) async {
      final address = await GeocodingService.coordinatesToAddress(location);
      setState(() {
      _destinationAddress = address ?? 'Selected Location';
    });
  }

  void _onLocationUpdate(LatLng location) {
      setState(() {
      _currentLocation = location;
      });
    }

  void _onMapMoved(LatLng center) {
    // Update pickup location as user pans the map (center-pin UX)
    setState(() {
      _pickupLocation = center;
    });

    // Debounce reverse-geocoding so we only query when user stops moving the map
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      try {
        await _updatePickupAddress(center);
      } catch (e) {
        // ignore geocoding errors silently
      }
    });
  }

  void _onPickupSelected(LatLng location) {
    setState(() {
      _pickupLocation = location;
    });
    _updatePickupAddress(location);
    _calculateFare();
  }

  void _onDestinationSelected(LatLng location) {
    setState(() {
      _destinationLocation = location;
    });
    _updateDestinationAddress(location);
    _calculateFare();
    // Move map to show destination clearly
    try {
      _mapController.move(location, 15.0);
    } catch (e) {
      // ignore if controller not ready
    }
  }

  Future<void> _onDestinationAddressChanged(String address) async {
      setState(() {
      _destinationAddress = address;
    });

    if (address.isNotEmpty) {
      final coordinates = await GeocodingService.addressToCoordinates(address);
      if (coordinates != null) {
      setState(() {
          _destinationLocation = coordinates;
        });
        _calculateFare();
        // center map on destination so user can see the red pin and route
        try {
          _mapController.move(coordinates, 15.0);
    } catch (e) {
          // controller may not be ready yet
        }
      }
    }
  }

  void _calculateFare() {
    if (_pickupLocation != null && _destinationLocation != null) {
      // Calculate distance between pickup and destination
      final distance = Geolocator.distanceBetween(
            _pickupLocation!.latitude,
            _pickupLocation!.longitude,
            _destinationLocation!.latitude,
            _destinationLocation!.longitude,
          ) /
          1000; // Convert to kilometers

      // Simple fare calculation (base fare + distance * rate)
      double baseFare = 50.0; // Base fare in ETB
      double ratePerKm = 15.0; // Rate per kilometer

      if (_selectedRideType == RideType.premium) {
        baseFare = 80.0;
        ratePerKm = 25.0;
      } else if (_selectedRideType == RideType.economy) {
        baseFare = 30.0;
        ratePerKm = 10.0;
      }

      setState(() {
        _estimatedFare = baseFare + (distance * ratePerKm);
      });
    }
  }

  void _onRideTypeChanged(RideType rideType) {
    setState(() {
      _selectedRideType = rideType;
    });
    _calculateFare();
  }

  Future<void> _requestRide() async {
    if (_pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pickup and destination locations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // TODO: Implement actual ride request API call
      final rideData = {
        'pickup_address': _pickupAddress,
        'pickup_lat': _pickupLocation!.latitude,
        'pickup_lon': _pickupLocation!.longitude,
        'dest_address': _destinationAddress,
        'dest_lat': _destinationLocation!.latitude,
        'dest_lon': _destinationLocation!.longitude,
        'distance_km': _distanceKm,
        'fare': _estimatedFare,
        'vehicle_type': _selectedRideType.name,
        'note': _rideNote,
        'payment_method': _selectedPayment,
      };

      // TODO: Send rideData to backend API
      print('Ride data: $rideData');

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _currentStatus = RideStatus.waiting;
        });

        _startPolling();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startPolling() {
    if (_isPolling) return;

    setState(() {
      _isPolling = true;
    });

    // Simulate polling for ride status
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isPolling || !mounted) {
        timer.cancel();
        return;
      }

      _checkRideStatus();
    });
  }

  void _stopPolling() {
    setState(() {
      _isPolling = false;
    });
  }

  Future<void> _checkRideStatus() async {
    // TODO: Implement actual API call to check ride status
    // For now, simulate status changes
    if (_currentStatus == RideStatus.waiting) {
      // Simulate driver assignment after 10 seconds
      await Future.delayed(const Duration(seconds: 10));
          if (mounted) {
            setState(() {
          _currentStatus = RideStatus.assigned;
          _assignedDriver = const Driver(
            id: 1,
            name: 'John Doe',
            phoneNumber: '+251912345678',
            vehicleType: 'Car',
            vehiclePlateNumber: 'ABC-1234',
            vehicleDetails: 'Toyota Corolla - ABC-1234',
            currentLat: 13.88,
            currentLon: 39.46,
            status: 'Available',
            totalRides: 150,
            rating: 4.8,
            profilePicture: 'https://via.placeholder.com/100',
          );
        });
      }
    } else if (_currentStatus == RideStatus.assigned) {
      // Simulate trip start after 5 seconds
      await Future.delayed(const Duration(seconds: 5));
          if (mounted) {
            setState(() {
          _currentStatus = RideStatus.onTrip;
        });
      }
    } else if (_currentStatus == RideStatus.onTrip) {
      // Simulate trip completion after 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _currentStatus = RideStatus.completed;
          _stopPolling();
        });
      }
    }
  }

  void _cancelRide() {
    setState(() {
      _currentStatus = RideStatus.canceled;
      _stopPolling();
    });
  }

  void _callDriver() async {
    if (_assignedDriver?.phoneNumber != null) {
      final Uri phoneUri =
          Uri(scheme: 'tel', path: _assignedDriver!.phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not make phone call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _activateSOS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency SOS'),
        content: const Text(
            'Are you in an emergency? This will alert our support team and share your location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement SOS functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency alert sent! Help is on the way.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Activate SOS'),
          ),
        ],
      ),
    );
  }

  void _submitRating(int rating, String comment) {
    // TODO: Implement rating submission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your feedback!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _newRide() {
        setState(() {
      _currentStatus = RideStatus.home;
      _assignedDriver = null;
      _pickupLocation = _currentLocation;
      _destinationLocation = null;
      _pickupAddress = 'Current Location';
      _destinationAddress = '';
      _estimatedFare = null;
      _distanceKm = null;
    });
  }

  void _done() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Image.asset(
                'assets/images/Selamawi-logo 1 png.png', // Add your logo path
                height: 32,
                width: 32,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to text logo if image not found
                  return Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'RIDE',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      body: _buildCurrentScreen(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStatus) {
      case RideStatus.home:
        return 'Select Address';
      case RideStatus.searching:
        return 'Search Destination';
      case RideStatus.rideConfirmation:
        return 'Confirm Ride';
      case RideStatus.waiting:
        return 'Finding Driver...';
      case RideStatus.assigned:
        return 'Driver Assigned';
      case RideStatus.onTrip:
        return 'On Trip';
      case RideStatus.completed:
        return 'Ride Completed';
      case RideStatus.canceled:
        return 'Ride Canceled';
    }
  }

  Widget _buildCurrentScreen() {
    switch (_currentStatus) {
      case RideStatus.home:
        return _buildHomeScreen();
      case RideStatus.searching:
        return _buildSearchingScreen();
      case RideStatus.rideConfirmation:
        return _buildRideConfirmationScreen();
      case RideStatus.waiting:
        return _buildWaitingScreen();
      case RideStatus.assigned:
        return _buildAssignedScreen();
      case RideStatus.onTrip:
        return _buildOnTripScreen();
      case RideStatus.completed:
        return _buildCompletedScreen();
      case RideStatus.canceled:
        return _buildCanceledScreen();
    }
  }

  Widget _buildHomeScreen() {
    return Stack(
      children: [
        // Map - 90% of screen
        MapWidget(
          mapController: _mapController,
          currentLocation: _currentLocation,
          pickupLocation: _pickupLocation,
          destinationLocation: _destinationLocation,
          onLocationUpdate: _onLocationUpdate,
          onPickupSelected: _onPickupSelected,
          onDestinationSelected: _onDestinationSelected,
          onMapMoved: _onMapMoved,
          enableTapSelection: false, // Disable tap selection for home screen
        ),

        // Fixed pickup pin in center
        Center(
      child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),

        // Pickup location text above map
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _pickupAddress.isEmpty
                  ? 'Move the map to set pickup'
                  : _pickupAddress,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
          ),
        ),
      ),
        ),

        // Initial bottom sheet (25% of screen)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildInitialBottomSheet(),
        ),
      ],
    );
  }

  Widget _buildSearchingScreen() {
    return Stack(
      children: [
        // Map
        MapWidget(
          mapController: _mapController,
          currentLocation: _currentLocation,
          pickupLocation: _pickupLocation,
          destinationLocation: _destinationLocation,
          onLocationUpdate: _onLocationUpdate,
          onPickupSelected: _onPickupSelected,
          onDestinationSelected: _onDestinationSelected,
        ),

        // Expanded bottom sheet covering map
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildSearchBottomSheet(),
        ),
      ],
    );
  }

  Widget _buildRideConfirmationScreen() {
    return Stack(
      children: [
        // Map with route line
        MapWidget(
          mapController: _mapController,
          currentLocation: _currentLocation,
          pickupLocation: _pickupLocation,
          destinationLocation: _destinationLocation,
          onLocationUpdate: _onLocationUpdate,
          onPickupSelected: _onPickupSelected,
          onDestinationSelected: _onDestinationSelected,
        ),

        // Ride confirmation bottom sheet (50% of screen)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildRideConfirmationBottomSheet(),
        ),
      ],
    );
  }

  Widget _buildInitialBottomSheet() {
    final screenHeight = MediaQuery.of(context).size.height;
        return Container(
      height: screenHeight * 0.25,
          decoration: const BoxDecoration(
            color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
              ),
            ],
          ),
      child: Column(
            children: [
          // Handle bar
          Container(
                  width: 40,
                  height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
              color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Main search bar
              InkWell(
                onTap: () {
                  setState(() {
                        _currentStatus = RideStatus.searching;
                  });
                },
                child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                  ),
                      child: Row(
                    children: [
                          Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                      Text(
                        'Where to?',
                        style: TextStyle(
                              color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                  const SizedBox(height: 16),

                  // Saved Places and Recent Trips
                  Row(
                    children: [
                      Expanded(
                        child: _buildShortcutItem(
                          icon: Icons.home,
                          title: 'Home',
                          subtitle: '705 Green Summit',
                          onTap: () => _useShortcut('705 Green Summit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildShortcutItem(
                          icon: Icons.work,
                          title: 'Work',
                          subtitle: 'Studio 08 Jake Stream',
                          onTap: () => _useShortcut('Studio 08 Jake Stream'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Recent trips
                  Row(
            children: [
                      Expanded(
                        child: _buildShortcutItem(
                          icon: Icons.history,
                          title: 'Recent',
                          subtitle: 'Studio 65Murphy Islands',
                          onTap: () => _useShortcut('Studio 65Murphy Islands'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                        child: _buildShortcutItem(
                          icon: Icons.history,
                          title: 'Recent',
                          subtitle: 'Mexicali Ct 13a',
                          onTap: () => _useShortcut('Mexicali Ct 13a'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
            Icon(
              icon,
              color: Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                    title,
                      style: const TextStyle(
                      fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }

  Widget _buildSearchBottomSheet() {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.8,
      decoration: const BoxDecoration(
      color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
        child: Column(
          children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

            // Header
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _currentStatus = RideStatus.home;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                const Text(
                  'Search Destination',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  ),
                ],
              ),
            ),

          // Search fields
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // FROM field
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                            _pickupAddress.isEmpty
                                ? 'Pickup Location'
                                : _pickupAddress,
                            style: TextStyle(
                              color: _pickupAddress.isEmpty
                                  ? Colors.grey.shade600
                                  : Colors.black,
                              fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // TO field with autocomplete
                  Row(
                    children: [
                      Expanded(
                        child: AddressAutocompleteWidget(
                            hintText: 'Where to?',
                          initialValue: _destinationAddress,
                          onAddressSelected: (address) {
                            setState(() {
                              _destinationAddress = address;
                            });
                            _onDestinationAddressChanged(address);
                          },
                        ),
                      ),
                      if (_destinationAddress.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _resetDestination,
                          icon: const Icon(Icons.clear, color: Colors.red),
                          tooltip: 'Clear destination',
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Search results or Next button
                  if (_destinationAddress.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentStatus = RideStatus.rideConfirmation;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildRideConfirmationBottomSheet() {
    final screenHeight = MediaQuery.of(context).size.height;
        return Container(
      height: screenHeight * 0.5,
          decoration: const BoxDecoration(
            color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
              ),
            ],
          ),
      child: Column(
            children: [
          // Handle bar
          Container(
                  width: 40,
                  height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
              color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                  // Ride options
                  Text(
                    'Choose Vehicle',
                          style: TextStyle(
                      color: Colors.grey.shade700,
                            fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                        child: _buildVehicleOption(
                          icon: Icons.motorcycle,
                          title: 'Bajaj',
                          price: 'ETB 30-40',
                          isSelected: _selectedRideType == RideType.economy,
                          onTap: () => _onRideTypeChanged(RideType.economy),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildVehicleOption(
                          icon: Icons.directions_car,
                          title: 'Standard Car',
                          price: 'ETB 50-60',
                          isSelected: _selectedRideType == RideType.standard,
                          onTap: () => _onRideTypeChanged(RideType.standard),
                        ),
                      ),
                      const SizedBox(width: 12),
                        Expanded(
                        child: _buildVehicleOption(
                          icon: Icons.directions_car_filled,
                          title: 'Minibus',
                          price: 'ETB 80-100',
                          isSelected: _selectedRideType == RideType.premium,
                          onTap: () => _onRideTypeChanged(RideType.premium),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Price estimate
                  if (_estimatedFare != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                      children: [
                          Icon(
                            Icons.attach_money,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        Text(
                            'Price Estimate: ',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                            'ETB ${_estimatedFare!.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

                  // Payment method
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                        Icon(
                          Icons.payment,
                          color: Colors.grey.shade600,
                        size: 20,
                    ),
                    const SizedBox(width: 12),
                              Text(
                          'Payment: $_selectedPayment',
                                style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            // TODO: Show payment options
                          },
                          child: const Text('Change'),
                        ),
                  ],
                ),
              ),

                  const SizedBox(height: 20),

                  // Confirm booking button
                  SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestRide,
                  style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Booking',
                        style: TextStyle(
                            fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                          ),
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

  Widget _buildVehicleOption({
    required IconData icon,
    required String title,
    required String price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
            border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 8),
              Text(
              title,
                style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
              price,
                style: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                ),
              ),
            ],
        ),
      ),
    );
  }

  void _useShortcut(String destination) {
    setState(() {
      _destinationAddress = destination;
      _currentStatus = RideStatus.rideConfirmation;
    });
    _onDestinationAddressChanged(destination);
  }

  void _resetDestination() {
    setState(() {
      _destinationAddress = '';
      _destinationLocation = null;
      _estimatedFare = null;
    });
  }

  Widget _buildWaitingScreen() {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          const SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '🚗',
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Finding your driver...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
            const Text(
            'Connecting you with a nearby professional.',
              style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              ),
            ),
          const SizedBox(height: 30),
            TextButton(
              onPressed: _cancelRide,
              child: const Text(
                'Cancel Request',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildAssignedScreen() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🚗',
                  style: TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your driver is on the way!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Road animation container
                Container(
                  width: double.infinity,
                  height: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('🚗', style: TextStyle(fontSize: 40)),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Driver info card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade300,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _assignedDriver?.name ?? 'Driver Name',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Your Driver',
                          style: TextStyle(
                                fontSize: 14,
                            color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Vehicle: ${_assignedDriver?.vehicleDetails ?? 'N/A'}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Contact: ${_assignedDriver?.phoneNumber ?? 'N/A'}'),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _callDriver,
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _activateSOS,
                      icon: const Icon(Icons.warning, color: Colors.red),
                      label: const Text('SOS',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnTripScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🚗',
            style: TextStyle(fontSize: 60),
          ),
          SizedBox(height: 20),
          Text(
            'On Trip',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Enjoy your ride!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedScreen() {
    return Center(
        child: Padding(
        padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Text(
              '🎉',
              style: TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ride Completed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      const Text('Destination:'),
                      Text(_destinationAddress),
                    ],
                  ),
                  const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      const Text('Final Fare:'),
                      Text('ETB ${_estimatedFare?.toStringAsFixed(0) ?? '0'}'),
                    ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 30),
                        const Text(
              'How was your ride?',
                          style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            // Rating stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                  onPressed: () => _submitRating(index + 1, ''),
                  icon: const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 40,
                  ),
                  );
                }),
              ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                child: ElevatedButton(
                    onPressed: _newRide,
                    child: const Text('Request New Ride'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                child: OutlinedButton(
                    onPressed: _done,
                    child: const Text('Done'),
                ),
              ),
            ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanceledScreen() {
    return Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
          const Text(
            '❌',
            style: TextStyle(fontSize: 60),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ride Canceled',
              style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _newRide,
            child: const Text('Request a New Ride'),
          ),
          ],
      ),
    );
  }
}
