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
import '../../../../shared/domain/models/ride_models.dart';
import 'my_trips_screen.dart';
import 'profile_screen.dart';
import '../../data/ride_api_service.dart';

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
  LatLng? _tempPinLocation; // For map pin selection
  String _pickupAddress = 'Move map to set pickup';
  String _destinationAddress = '';

  // Ride configuration
  VehicleType _selectedVehicle = VehicleType.economy;
  final String _selectedPayment = 'Cash';
  double? _estimatedFare;
  double? _distanceKm;
  String? _estimatedDuration;
  List<LatLng>? _routePoints;

  // Ride state
  RideStatus _currentStatus = RideStatus.home;
  Driver? _assignedDriver;
  int _currentNavigationIndex = 0;
  bool _isMapSelectionMode = false;

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

  // API Service
  final RideApiService _rideApiService = RideApiService();
  int? _currentRideId;

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
        const Distance distance = Distance();
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

  void _selectDestination(TigrayLocation location) async {
    setState(() {
      _destinationLocation = location.coordinates;
      _destinationAddress = location.name;
    });
    await _calculateRoute();
    setState(() {
      _currentStatus = RideStatus.rideConfiguration;
    });
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
      const Distance distance = Distance();
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
    // Use average of min and max price for exact fare
    final avgPrice = (vehicle.minPrice + vehicle.maxPrice) / 2;
    return avgPrice;
  }

  void _fitMapToBounds() {
    if (_pickupLocation != null && _destinationLocation != null) {
      const Distance distance = Distance();
      final distanceMeters = distance.as(
        LengthUnit.Meter,
        _pickupLocation!,
        _destinationLocation!,
      );

      // Calculate center point
      final centerLat =
          (_pickupLocation!.latitude + _destinationLocation!.latitude) / 2;
      final centerLng =
          (_pickupLocation!.longitude + _destinationLocation!.longitude) / 2;

      // Calculate appropriate zoom level based on distance
      double zoom;
      if (distanceMeters < 500) {
        zoom = 15.0; // Very close
      } else if (distanceMeters < 1000) {
        zoom = 14.5; // Close
      } else if (distanceMeters < 2000) {
        zoom = 14.0; // Medium
      } else if (distanceMeters < 5000) {
        zoom = 13.0; // Far
      } else {
        zoom = 12.0; // Very far
      }

      _mapController.move(LatLng(centerLat, centerLng), zoom);
    }
  }

  Future<void> _requestRide() async {
    if (_pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and destination')),
      );
      return;
    }

    setState(() {
      _currentStatus = RideStatus.findingDriver;
    });

    try {
      // Convert vehicle type enum to string
      String vehicleTypeStr;
      switch (_selectedVehicle) {
        case VehicleType.economy:
          vehicleTypeStr = 'Bajaj';
          break;
        case VehicleType.standard:
          vehicleTypeStr = 'Car';
          break;
        case VehicleType.premium:
          vehicleTypeStr = 'SUV';
          break;
      }

      // Request ride from backend
      final response = await _rideApiService.requestRide(
        pickupLat: _pickupLocation!.latitude,
        pickupLon: _pickupLocation!.longitude,
        pickupAddress: _pickupAddress,
        destLat: _destinationLocation!.latitude,
        destLon: _destinationLocation!.longitude,
        destAddress: _destinationAddress,
        vehicleType: vehicleTypeStr,
        estimatedFare: _estimatedFare ?? 0.0,
        paymentMethod: _selectedPayment,
      );

      // Save ride ID
      _currentRideId = response['ride_id'] as int?;

      // Poll for driver assignment
      _pollForDriverAssignment();
    } catch (e) {
      print('Error requesting ride: $e');
      if (mounted) {
        setState(() {
          _currentStatus = RideStatus.rideConfiguration;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request ride: $e')),
        );
      }
    }
  }

  void _pollForDriverAssignment() {
    if (_currentRideId == null) return;

    // Poll every 3 seconds for driver assignment
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _currentStatus != RideStatus.findingDriver) {
        timer.cancel();
        return;
      }

      try {
        final status = await _rideApiService.getRideStatus(_currentRideId!);

        // Check if driver is assigned
        if (status['status'] == 'Assigned' && status['driver'] != null) {
          timer.cancel();

          final driverData = status['driver'];
          if (mounted) {
            setState(() {
              _assignedDriver = Driver(
                id: driverData['id'],
                name: driverData['name'],
                phoneNumber: driverData['phone_number'],
                vehicleType: driverData['vehicle_type'],
                vehicleDetails: driverData['vehicle_details'] ?? '',
                vehiclePlateNumber: driverData['vehicle_plate_number'] ?? '',
                profilePicture: driverData['profile_picture'],
                currentLat:
                    driverData['current_lat'] ?? _pickupLocation!.latitude,
                currentLon:
                    driverData['current_lon'] ?? _pickupLocation!.longitude,
                status: driverData['status'] ?? 'Available',
                rating: (driverData['rating'] ?? 4.5).toDouble(),
                totalRides: driverData['total_rides'] ?? 0,
              );
              _currentStatus = RideStatus.driverAssigned;
            });
          }
        } else if (status['status'] == 'Cancelled') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _currentStatus = RideStatus.home;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ride was cancelled')),
            );
          }
        }
      } catch (e) {
        print('Error polling ride status: $e');
        // Continue polling even if there's an error
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
      appBar: _shouldShowAppBar() ? _buildAppBar() : null,
      body: Stack(
        children: [
          // Map Layer
          _buildMap(),

          // Top Bar
          if (_currentStatus != RideStatus.searchingDestination &&
              !_shouldShowAppBar())
            _buildTopBar(),

          // Bottom Sheet or Full Screen Content
          _buildBottomContent(),

          // Bottom Navigation Bar
          if (_shouldShowBottomNav()) _buildBottomNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        MapWidget(
          mapController: _mapController,
          currentLocation: _currentLocation,
          pickupLocation: _pickupLocation,
          destinationLocation: _currentStatus == RideStatus.pinDestination
              ? _tempPinLocation
              : _destinationLocation,
          routePoints: _routePoints,
          onLocationUpdate: (location) {},
          onPickupSelected: (location) {
            setState(() {
              _pickupLocation = location;
            });
            _updatePickupAddress(location);
          },
          onDestinationSelected: (location) {
            // Handle map pin selection
            if (_currentStatus == RideStatus.pinDestination) {
              setState(() {
                _tempPinLocation = location;
              });
            } else if (_isMapSelectionMode) {
              setState(() {
                _destinationLocation = location;
                _destinationAddress = 'Selected Location';
                _currentStatus = RideStatus.rideConfiguration;
                _isMapSelectionMode = false;
              });
              _calculateRoute();
            }
          },
          onMapMoved: _currentStatus == RideStatus.pinDestination
              ? (center) {
                  // Update pin location when map moves in pin mode
                  setState(() {
                    _tempPinLocation = center;
                  });
                }
              : null,
        ),
        // Map selection overlay
        if (_isMapSelectionMode)
          Container(
            color: Colors.black.withOpacity(0.1),
            child: Stack(
              children: [
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.primaryBlue,
                        size: 60,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tap on the map to select destination',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Or use the suggestions below',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Cancel button
                Positioned(
                  top: 50,
                  right: 20,
                  child: SafeArea(
                    child: FloatingActionButton(
                      onPressed: _cancelMapSelection,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryBlue,
                      mini: true,
                      child: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool _shouldShowAppBar() {
    return _currentStatus == RideStatus.searchingDestination ||
        _currentStatus == RideStatus.pinDestination ||
        _currentStatus == RideStatus.rideConfiguration ||
        _currentStatus == RideStatus.findingDriver ||
        _currentStatus == RideStatus.driverAssigned ||
        _currentStatus == RideStatus.driverArriving ||
        _currentStatus == RideStatus.onTrip;
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _goBack,
      ),
      title: Text(
        _getScreenTitle(),
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: AppColors.primaryBlue,
      elevation: 0,
    );
  }

  String _getScreenTitle() {
    switch (_currentStatus) {
      case RideStatus.searchingDestination:
        return 'Select Destination';
      case RideStatus.pinDestination:
        return 'Pin on Map';
      case RideStatus.rideConfiguration:
        return 'Choose Vehicle';
      case RideStatus.findingDriver:
        return 'Finding Driver';
      case RideStatus.driverAssigned:
        return 'Driver Assigned';
      case RideStatus.driverArriving:
        return 'Driver Arriving';
      case RideStatus.onTrip:
        return 'On Trip';
      default:
        return 'Ride';
    }
  }

  void _goBack() {
    switch (_currentStatus) {
      case RideStatus.searchingDestination:
        setState(() {
          _currentStatus = RideStatus.home;
        });
        break;
      case RideStatus.pinDestination:
        setState(() {
          _currentStatus = RideStatus.searchingDestination;
          _tempPinLocation = null;
          _isMapSelectionMode = false;
        });
        break;
      case RideStatus.rideConfiguration:
        setState(() {
          _currentStatus = RideStatus.searchingDestination;
        });
        break;
      case RideStatus.findingDriver:
        setState(() {
          _currentStatus = RideStatus.rideConfiguration;
        });
        break;
      case RideStatus.driverAssigned:
      case RideStatus.driverArriving:
      case RideStatus.onTrip:
        // Can't go back during active ride
        break;
      default:
        Navigator.of(context).pop();
    }
  }

  void _cancelMapSelection() {
    setState(() {
      _isMapSelectionMode = false;
    });
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue,
              AppColors.darkBlue,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Image.asset(
                'assets/images/Selamawi-logo 1 png.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomContent() {
    switch (_currentStatus) {
      case RideStatus.home:
        return _buildHomeBottomSheet();
      case RideStatus.searchingDestination:
        return _buildSearchDestinationScreen();
      case RideStatus.pinDestination:
        return _buildPinDestinationScreen();
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
      minChildSize: 0.15, // Allow dragging to see more map
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.15, 0.3, 0.6, 0.9], // Better snap points
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
              GestureDetector(
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
                      const Icon(
                        Icons.search,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _destinationAddress.isEmpty
                              ? 'Where to?'
                              : _destinationAddress,
                          style: TextStyle(
                            fontSize: 16,
                            color: _destinationAddress.isEmpty
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_destinationAddress.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _destinationAddress = '';
                              _destinationLocation = null;
                              _routePoints = null;
                            });
                          },
                          child: const Icon(
                            Icons.clear,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Suggestions Section
              Text(
                'Suggestions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: 12),

              // Quick suggestions grid
              _buildSuggestionsGrid(),

              const SizedBox(height: 24),

              // Saved Places
              Text(
                'Saved Places',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: 12),

              ...SampleSavedPlaces.defaultSavedPlaces
                  .map((place) => _buildSavedPlaceCard(place)),

              const SizedBox(height: 24),

              // Recent Trips
              Text(
                'Recent Trips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsGrid() {
    final suggestions = [
      {
        'name': 'Home',
        'address': 'Hawelti, Mekelle',
        'icon': Icons.home,
        'color': AppColors.success,
        'bgColor': AppColors.green100,
      },
      {
        'name': 'Work',
        'address': 'Kedamay Weyane, Mekelle',
        'icon': Icons.work,
        'color': AppColors.primaryBlue,
        'bgColor': AppColors.blue100,
      },
      {
        'name': 'Ayder Hospital',
        'address': 'Ayder, Mekelle',
        'icon': Icons.local_hospital,
        'color': AppColors.error,
        'bgColor': AppColors.red100,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        childAspectRatio: 3.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return InkWell(
          onTap: () {
            // Create a temporary location for the suggestion
            final location = TigrayLocation(
              id: 'suggestion_${suggestion['name']}',
              name: suggestion['name'] as String,
              city: 'Mekelle',
              coordinates:
                  const LatLng(13.4967, 39.4753), // Default coordinates
              category: 'suggestion',
              description: suggestion['address'] as String,
            );
            _selectDestination(location);
          },
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
                    color: suggestion['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    suggestion['icon'] as IconData,
                    color: suggestion['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        suggestion['name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        suggestion['address'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.gray400),
              ],
            ),
          ),
        );
      },
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
                child: const Icon(
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray400),
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
                  Expanded(
                    child: Text(
                      'Select Destination',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  // Map Pin Button with clearer label
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isMapSelectionMode = true;
                        _currentStatus = RideStatus.pinDestination;
                      });
                    },
                    icon: const Icon(Icons.location_on,
                        color: AppColors.secondaryGreen),
                    label: const Text(
                      'Pin on map',
                      style: TextStyle(color: AppColors.secondaryGreen),
                    ),
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
                        style: const TextStyle(
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

  Widget _buildPinDestinationScreen() {
    // Initialize temp pin to map center if not set
    if (_tempPinLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final center = _mapController.camera.center;
        setState(() {
          _tempPinLocation = center;
        });
      });
    }

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
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Instructions
                const Text(
                  'Tap on the map or move the map to adjust the pin',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Next Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _tempPinLocation != null
                        ? () async {
                            // Get address for the pinned location
                            try {
                              final address =
                                  await GeocodingService.coordinatesToAddress(
                                      _tempPinLocation!);
                              setState(() {
                                _destinationLocation = _tempPinLocation;
                                _destinationAddress =
                                    address ?? 'Selected Location';
                                _tempPinLocation = null;
                                _currentStatus = RideStatus.rideConfiguration;
                              });
                              await _calculateRoute();
                            } catch (e) {
                              // If geocoding fails, use generic address
                              setState(() {
                                _destinationLocation = _tempPinLocation;
                                _destinationAddress = 'Selected Location';
                                _tempPinLocation = null;
                                _currentStatus = RideStatus.rideConfiguration;
                              });
                              await _calculateRoute();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _tempPinLocation != null
                          ? AppColors.primaryBlue
                          : AppColors.gray300,
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
      ),
    );
  }

  Widget _buildRideConfigurationSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.3, // Enough to still see button
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.3, 0.6, 0.9, 0.95], // Snap with larger default
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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

              // Trip Summary with Change Destination Option
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Trip Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentStatus = RideStatus.searchingDestination;
                            });
                          },
                          icon: const Icon(Icons.edit,
                              size: 16, color: AppColors.primaryBlue),
                          label: const Text(
                            'Change',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                        const Icon(Icons.access_time,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _estimatedDuration ?? '-',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.straighten,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _distanceKm != null
                              ? '${_distanceKm!.toStringAsFixed(1)} km'
                              : '-',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
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

              // Horizontal vehicle selection
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _vehicleOptions.length,
                  itemBuilder: (context, index) {
                    final vehicle = _vehicleOptions[index];
                    return _buildVehicleCard(vehicle);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Payment Method - Fancier Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                _selectedPayment == 'Cash'
                                    ? Icons.money
                                    : Icons.phone_android,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedPayment,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.gray400),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Request Ride Button - Fancier with gradient and icon
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.darkBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _requestRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_taxi,
                          size: 24, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text(
                        'Request Ride',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ETB ${_estimatedFare?.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8), // Ensure button is fully visible
              const SafeArea(top: false, child: SizedBox.shrink()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehicleCard(VehicleOption vehicle) {
    final isSelected = _selectedVehicle == vehicle.type;

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.gray200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vehicle.icon,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                vehicle.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'ETB ${((vehicle.minPrice + vehicle.maxPrice) / 2).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.primaryBlue,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.primaryGradient,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(32),
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.4,
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated pulse indicator with multiple circles
            AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Multiple pulsing circles
                    for (int i = 0; i < 3; i++)
                      Container(
                        width: 120 + (_pulseAnimationController.value * 60),
                        height: 120 + (_pulseAnimationController.value * 60),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                              0.3 - (_pulseAnimationController.value * 0.3)),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                    // Inner circle with icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            Text(
              'Finding nearby drivers...',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Connecting you with the closest available ride',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Cancel button with better styling
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextButton(
                onPressed: _cancelRide,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cancel Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

              const Text(
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
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_assignedDriver!.vehicleType} ${_assignedDriver!.vehicleDetails} • ${_assignedDriver!.vehiclePlateNumber}',
                          style: const TextStyle(
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
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 80,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Trip Completed!',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 32),

                  // Trip Summary with better styling
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Fare',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ETB ${_estimatedFare?.toStringAsFixed(0) ?? '0'}',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Paid with Cash',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Spacer(),

                  // Action Buttons
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Request Another Ride'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

        // Navigate to respective screens
        if (index == 1) {
          // My Trips
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyTripsScreen()),
          );
        } else if (index == 2) {
          // Messages (placeholder for now)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Messages feature coming soon!')),
          );
        } else if (index == 3) {
          // Profile
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        }
        // Index 0 (Home) - do nothing, already on home
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
