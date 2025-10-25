import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/map_widget.dart';
import '../widgets/ride_request_bottom_sheet.dart';
import '../widgets/location_search_widget.dart';
import '../../../../shared/domain/models/ride.dart';
import '../../../../shared/domain/models/driver.dart';

enum RideStatus {
  booking,
  waiting,
  assigned,
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
  RideStatus _currentStatus = RideStatus.booking;
  bool _isRequestingRide = false;
  Driver? _assignedDriver;

  // Polling for ride status
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _stopPolling();
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

  void _updatePickupAddress(LatLng location) {
    // TODO: Implement reverse geocoding to get address
    setState(() {
      _pickupAddress = 'Current Location';
    });
  }

  void _updateDestinationAddress(LatLng location) {
    // TODO: Implement reverse geocoding to get address
    setState(() {
      _destinationAddress = 'Selected Location';
    });
  }

  void _onLocationUpdate(LatLng location) {
    setState(() {
      _currentLocation = location;
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

    setState(() {
      _isRequestingRide = true;
    });

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
          _isRequestingRide = false;
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
        setState(() {
          _isRequestingRide = false;
        });
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
      _currentStatus = RideStatus.booking;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildCurrentScreen(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStatus) {
      case RideStatus.booking:
        return 'Request Ride';
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
      case RideStatus.booking:
        return _buildBookingScreen();
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

  Widget _buildBookingScreen() {
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

        // Top location search bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: LocationSearchWidget(
            pickupAddress: _pickupAddress,
            destinationAddress: _destinationAddress,
            onPickupChanged: (address) {
              // TODO: Implement geocoding to get coordinates from address
            },
            onDestinationChanged: (address) {
              // TODO: Implement geocoding to get coordinates from address
            },
          ),
        ),

        // Bottom ride details and request button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: RideRequestBottomSheet(
            pickupLocation: _pickupLocation,
            destinationLocation: _destinationLocation,
            selectedRideType: _selectedRideType,
            estimatedFare: _estimatedFare,
            isRequestingRide: _isRequestingRide,
            onRideTypeChanged: _onRideTypeChanged,
            onRequestRide: _requestRide,
          ),
        ),
      ],
    );
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
