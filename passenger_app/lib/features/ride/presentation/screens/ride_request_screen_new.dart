import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/tigray_locations.dart';
import '../widgets/map_widget.dart';
import '../services/geocoding_service.dart';
import '../services/route_service.dart';
import '../../../../shared/domain/models/driver.dart';

enum RideStatus {
  home, // Initial state with bottom sheet
  searchingDestination, // User is searching for destination
  rideConfiguration, // Pickup and destination set, selecting vehicle
  findingDriver, // Searching for available driver
  driverAssigned, // Driver found and assigned
  driverArriving, // Driver on the way to pickup
  onTrip, // Trip in progress
  tripCompleted, // Trip finished, show rating
  canceled, // Ride was canceled
}

enum VehicleType {
  economy, // Bajaj
  standard, // Standard Car
  premium, // SUV
}

class VehicleOption {
  final VehicleType type;
  final String name;
  final String icon;
  final int minPrice;
  final int maxPrice;
  final int capacity;
  final String eta;

  const VehicleOption({
    required this.type,
    required this.name,
    required this.icon,
    required this.minPrice,
    required this.maxPrice,
    required this.capacity,
    required this.eta,
  });
}

class RideRequestScreen extends ConsumerStatefulWidget {
  const RideRequestScreen({super.key});

  @override
  ConsumerState<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends ConsumerState<RideRequestScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Location data
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  String _pickupAddress = 'Move map to set pickup';
  String _destinationAddress = '';

  // Ride configuration
  VehicleType _selectedVehicle = VehicleType.economy;
  String _selectedPayment = 'Cash';
  double? _estimatedFare;
  double? _distanceKm;
  String? _estimatedDuration;
  List<LatLng>? _routePoints;

  // Ride state
  RideStatus _currentStatus = RideStatus.home;
  Driver? _assignedDriver;
  int _currentNavigationIndex = 0;

  // Vehicle options (ETB - Ethiopian Birr)
  final List<VehicleOption> _vehicleOptions = const [
    VehicleOption(
      type: VehicleType.economy,
      name: 'Economy (Bajaj)',
      icon: '🛺',
      minPrice: 30,
      maxPrice: 50,
      capacity: 3,
      eta: '2 min',
    ),
    VehicleOption(
      type: VehicleType.standard,
      name: 'Standard Car',
      icon: '🚗',
      minPrice: 50,
      maxPrice: 80,
      capacity: 4,
      eta: '5 min',
    ),
    VehicleOption(
      type: VehicleType.premium,
      name: 'Premium (SUV)',
      icon: '🚙',
      minPrice: 80,
      maxPrice: 120,
      capacity: 6,
      eta: '8 min',
    ),
  ];

  // UI Controllers
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<TigrayLocation> _searchResults = [];

  // Animation controllers
  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initializeApp();
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Use Mekelle as default
        setState(() {
          _currentLocation = TigrayLocations.defaultCenter;
          _pickupLocation = TigrayLocations.defaultCenter;
        });
        _mapController.move(
            TigrayLocations.defaultCenter, TigrayLocations.defaultZoom);
        await _updatePickupAddress(TigrayLocations.defaultCenter);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _pickupLocation = _currentLocation;
      });

      _mapController.move(_currentLocation!, 15.0);
      await _updatePickupAddress(_currentLocation!);
    } catch (e) {
      // Fallback to Mekelle
      setState(() {
        _currentLocation = TigrayLocations.defaultCenter;
        _pickupLocation = TigrayLocations.defaultCenter;
      });
      _mapController.move(
          TigrayLocations.defaultCenter, TigrayLocations.defaultZoom);
      await _updatePickupAddress(TigrayLocations.defaultCenter);
    }
  }

  Future<void> _updatePickupAddress(LatLng location) async {
    try {
      // Check if near a known location
      final closestLocation = TigrayLocations.findClosestLocation(location);
      if (closestLocation != null) {
        final Distance distance = Distance();
        final distanceMeters = distance.as(
            LengthUnit.Meter, location, closestLocation.coordinates);

        if (distanceMeters < 500) {
          // Within 500 meters
          setState(() {
            _pickupAddress = closestLocation.name;
          });
          return;
        }
      }

      // Fallback to geocoding
      final address = await GeocodingService.coordinatesToAddress(location);
      setState(() {
        _pickupAddress = address ?? 'Unknown location';
      });
    } catch (e) {
      setState(() {
        _pickupAddress = 'Mekelle, Tigray';
      });
    }
  }

  void _onMapMoved(LatLng newCenter) {
    if (_currentStatus == RideStatus.home) {
      setState(() {
        _pickupLocation = newCenter;
      });

      // Debounce address updates
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        _updatePickupAddress(newCenter);
      });
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = TigrayLocations.popularLocations;
      });
      return;
    }

    setState(() {
      _searchResults = TigrayLocations.searchLocations(query);
    });
  }

  void _selectDestination(TigrayLocation location) {
    setState(() {
      _destinationLocation = location.coordinates;
      _destinationAddress = location.name;
      _currentStatus = RideStatus.rideConfiguration;
    });
    _calculateRoute();
  }

  void _selectSavedPlace(SavedPlace place) {
    setState(() {
      _destinationLocation = place.coordinates;
      _destinationAddress = place.name;
      _currentStatus = RideStatus.rideConfiguration;
    });
    _calculateRoute();
  }

  void _selectRecentTrip(RecentTrip trip) {
    setState(() {
      _destinationLocation = trip.destinationCoordinates;
      _destinationAddress = trip.destinationName;
      _currentStatus = RideStatus.rideConfiguration;
    });
    _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    if (_pickupLocation == null || _destinationLocation == null) return;

    try {
      final route =
          await RouteService.getRoute(_pickupLocation!, _destinationLocation!);

      setState(() {
        _routePoints = route;
      });

      // Calculate distance and fare
      final Distance distance = Distance();
      final distanceMeters = distance.as(
        LengthUnit.Meter,
        _pickupLocation!,
        _destinationLocation!,
      );

      setState(() {
        _distanceKm = distanceMeters / 1000;
        _estimatedDuration = _calculateDuration(_distanceKm!);
        _estimatedFare = _calculateFare(_distanceKm!);
      });

      // Fit map to show both markers
      _fitMapToBounds();
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  String _calculateDuration(double distanceKm) {
    // Simple estimation: 30 km/h average speed in city
    final minutes = (distanceKm / 30 * 60).round();
    return '$minutes min';
  }

  double _calculateFare(double distanceKm) {
    final vehicle =
        _vehicleOptions.firstWhere((v) => v.type == _selectedVehicle);
    final baseFare = vehicle.minPrice.toDouble();
    final perKmRate = (vehicle.maxPrice - vehicle.minPrice) /
        10; // Assuming 10km max distance
    return baseFare + (distanceKm * perKmRate);
  }

  void _fitMapToBounds() {
    if (_pickupLocation != null && _destinationLocation != null) {
      final bounds = LatLngBounds(
        _pickupLocation!,
        _destinationLocation!,
      );

      // Add padding
      final centerLat = (bounds.north + bounds.south) / 2;
      final centerLng = (bounds.east + bounds.west) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 12.0);
    }
  }

  void _requestRide() {
    setState(() {
      _currentStatus = RideStatus.findingDriver;
    });

    // Simulate finding driver after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _currentStatus == RideStatus.findingDriver) {
        setState(() {
          _assignedDriver = Driver(
            id: 1,
            name: 'Tekle Haile',
            phoneNumber: '+251912345678',
            vehicleType: 'Bajaj',
            vehicleDetails: 'RE Auto',
            vehiclePlateNumber: 'ት-12345',
            profilePicture: null,
            currentLat: _pickupLocation?.latitude ?? 13.4967,
            currentLon: _pickupLocation?.longitude ?? 39.4753,
            status: 'Available',
            rating: 4.8,
            totalRides: 1234,
          );
          _currentStatus = RideStatus.driverAssigned;
        });
      }
    });
  }

  void _cancelRide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStatus = RideStatus.home;
                _destinationLocation = null;
                _destinationAddress = '';
                _routePoints = null;
                _estimatedFare = null;
                _assignedDriver = null;
              });
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Layer
          _buildMap(),

          // Top Bar
          if (_currentStatus != RideStatus.searchingDestination) _buildTopBar(),

          // Fixed Pickup Pin (only in home state)
          if (_currentStatus == RideStatus.home) _buildFixedPickupPin(),

          // Bottom Sheet or Full Screen Content
          _buildBottomContent(),

          // Bottom Navigation Bar
          if (_shouldShowBottomNav()) _buildBottomNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return MapWidget(
      mapController: _mapController,
      currentLocation: _currentLocation,
      pickupLocation:
          _currentStatus != RideStatus.home ? _pickupLocation : null,
      destinationLocation: _destinationLocation,
      routePoints: _routePoints,
      onLocationUpdate: (location) {},
      onPickupSelected: (location) {},
      onDestinationSelected: (location) {},
      onMapMoved: _onMapMoved,
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Profile Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.lightBlue,
                child:
                    Icon(Icons.person, color: AppColors.primaryBlue, size: 24),
              ),

              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Text(
                  'Ride',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(width: 12),

              // Notification Icon
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedPickupPin() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Address label above pin
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _pickupAddress,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Green pickup pin
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.pickupGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pickupGreen.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 30,
            ),
          ),

          // Pin shadow
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent() {
    switch (_currentStatus) {
      case RideStatus.home:
        return _buildHomeBottomSheet();
      case RideStatus.searchingDestination:
        return _buildSearchDestinationScreen();
      case RideStatus.rideConfiguration:
        return _buildRideConfigurationSheet();
      case RideStatus.findingDriver:
        return _buildFindingDriverSheet();
      case RideStatus.driverAssigned:
      case RideStatus.driverArriving:
        return _buildDriverAssignedSheet();
      case RideStatus.onTrip:
        return _buildOnTripSheet();
      case RideStatus.tripCompleted:
        return _buildTripCompletedScreen();
      case RideStatus.canceled:
        return _buildHomeBottomSheet();
    }
  }

  Widget _buildHomeBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.3,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.3, 0.5, 0.9],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Where to? Search Bar
              InkWell(
                onTap: () {
                  setState(() {
                    _currentStatus = RideStatus.searchingDestination;
                    _searchResults = TigrayLocations.popularLocations;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textTertiary),
                      const SizedBox(width: 12),
                      Text(
                        'Where to?',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Saved Places
              Text(
                'Saved Places',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 12),

              ...SampleSavedPlaces.defaultSavedPlaces
                  .map((place) => _buildSavedPlaceCard(place)),

              const SizedBox(height: 24),

              // Recent Trips
              Text(
                'Recent Trips',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 12),

              ...SampleRecentTrips.defaultRecentTrips
                  .map((trip) => _buildRecentTripCard(trip)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedPlaceCard(SavedPlace place) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectSavedPlace(place),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: place.icon == 'home'
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  place.icon == 'home' ? Icons.home : Icons.work,
                  color: place.icon == 'home'
                      ? AppColors.success
                      : AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTripCard(RecentTrip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectRecentTrip(trip),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.schedule,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destinationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.destinationAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchDestinationScreen() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _currentStatus = RideStatus.home;
                        _searchController.clear();
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Destination',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),

            // Search Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // FROM field
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.pickupGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _pickupAddress,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // TO field
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.destinationRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Where to?',
                            filled: true,
                            fillColor: AppColors.gray50,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),

            // Search Results
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final location = _searchResults[index];
                  return _buildLocationResultCard(location);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationResultCard(TigrayLocation location) {
    IconData icon;
    Color iconColor;

    switch (location.category) {
      case 'transport':
        icon = Icons.local_taxi;
        iconColor = AppColors.warning;
        break;
      case 'hospital':
        icon = Icons.local_hospital;
        iconColor = AppColors.error;
        break;
      case 'education':
        icon = Icons.school;
        iconColor = AppColors.primaryBlue;
        break;
      case 'landmark':
        icon = Icons.location_city;
        iconColor = AppColors.darkBlue;
        break;
      default:
        icon = Icons.place;
        iconColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectDestination(location),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (location.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        location.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideConfigurationSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Trip Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle,
                            color: AppColors.pickupGreen, size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickupAddress,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.circle,
                            color: AppColors.destinationRed, size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _destinationAddress,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _estimatedDuration ?? '-',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.straighten,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _distanceKm != null
                              ? '${_distanceKm!.toStringAsFixed(1)} km'
                              : '-',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Vehicle Selection
              Text(
                'Select Vehicle',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 12),

              ..._vehicleOptions.map((vehicle) => _buildVehicleCard(vehicle)),

              const SizedBox(height: 24),

              // Payment Method
              Row(
                children: [
                  Icon(Icons.payment, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Payment: ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    _selectedPayment,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Change'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Request Ride Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestRide,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Request ${_vehicleOptions.firstWhere((v) => v.type == _selectedVehicle).name} - ETB ${_estimatedFare?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehicleCard(VehicleOption vehicle) {
    final isSelected = _selectedVehicle == vehicle.type;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedVehicle = vehicle.type;
            if (_distanceKm != null) {
              _estimatedFare = _calculateFare(_distanceKm!);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.lightBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.gray200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                vehicle.icon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vehicle.capacity} seats • ${vehicle.eta} away',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'ETB ${vehicle.minPrice}-${vehicle.maxPrice}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindingDriverSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(32),
      height: MediaQuery.of(context).size.height * 0.4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated pulse indicator
          AnimatedBuilder(
            animation: _pulseAnimationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse
                  Container(
                    width: 100 + (_pulseAnimationController.value * 40),
                    height: 100 + (_pulseAnimationController.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryBlue.withOpacity(
                          0.1 - (_pulseAnimationController.value * 0.1)),
                    ),
                  ),
                  // Inner circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryBlue,
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          Text(
            'Finding nearby drivers...',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'This may take a few moments',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          TextButton(
            onPressed: _cancelRide,
            child: Text(
              'Cancel Request',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAssignedSheet() {
    if (_assignedDriver == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status
              Text(
                'Driver Arriving',
                style: Theme.of(context).textTheme.displaySmall,
              ),

              const SizedBox(height: 8),

              Text(
                'Arriving in 5 min',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // Driver Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.lightBlue,
                    child: Text(
                      _assignedDriver!.name[0],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _assignedDriver!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: AppColors.warning, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_assignedDriver!.rating} • ${_assignedDriver!.totalRides} trips',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_assignedDriver!.vehicleType} ${_assignedDriver!.vehicleDetails} • ${_assignedDriver!.vehiclePlateNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ETB ${_estimatedFare?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelRide,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Call driver
                      },
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
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

  Widget _buildOnTripSheet() {
    return _buildDriverAssignedSheet(); // Similar UI for now
  }

  Widget _buildTripCompletedScreen() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 80,
              ),

              const SizedBox(height: 24),

              Text(
                'Trip Completed!',
                style: Theme.of(context).textTheme.displayMedium,
              ),

              const SizedBox(height: 32),

              // Trip Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distance'),
                        Text(
                          '${_distanceKm?.toStringAsFixed(1) ?? '0'} km',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Duration'),
                        Text(
                          _estimatedDuration ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Fare',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ETB ${_estimatedFare?.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Rating
              Text(
                'Rate Your Ride',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.star_border),
                    iconSize: 40,
                    color: AppColors.warning,
                  );
                }),
              ),

              const Spacer(),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentStatus = RideStatus.home;
                      _destinationLocation = null;
                      _destinationAddress = '';
                      _routePoints = null;
                      _estimatedFare = null;
                      _assignedDriver = null;
                    });
                  },
                  child: const Text('Done'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStatus = RideStatus.home;
                      _destinationLocation = null;
                      _destinationAddress = '';
                      _routePoints = null;
                      _estimatedFare = null;
                      _assignedDriver = null;
                    });
                  },
                  child: const Text('Request Another Ride'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowBottomNav() {
    return _currentStatus == RideStatus.home;
  }

  Widget _buildBottomNavigationBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, 'Home', 0),
                _buildNavItem(Icons.receipt_long, 'My Trips', 1),
                _buildNavItem(Icons.message, 'Messages', 2),
                _buildNavItem(Icons.person, 'Profile', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentNavigationIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _currentNavigationIndex = index;
        });
        // TODO: Navigate to respective screens
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primaryBlue : AppColors.gray400,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppColors.primaryBlue : AppColors.gray400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
