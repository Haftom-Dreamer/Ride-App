import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/map_widget.dart';
import '../services/geocoding_service.dart';

class MapSelectionScreen extends StatefulWidget {
  final String? placeLabel;
  final LatLng? initialLocation;

  const MapSelectionScreen({
    super.key,
    this.placeLabel,
    this.initialLocation,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  String _selectedAddress = 'Loading address...';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
        _selectedLocation = widget.initialLocation ?? location;
      });

      // Get address for selected location
      if (_selectedLocation != null) {
        _updateAddress(_selectedLocation!);
      }
    } catch (e) {
      setState(() {
        _currentLocation = const LatLng(13.4969, 39.4697); // Mekelle default
        _selectedLocation = widget.initialLocation ?? _currentLocation;
      });
      if (_selectedLocation != null) {
        _updateAddress(_selectedLocation!);
      }
    }

    // Center map on selected location after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_selectedLocation != null && mounted) {
        _mapController.move(_selectedLocation!, 15);
      }
    });
  }

  Future<void> _updateAddress(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final address = await GeocodingService.coordinatesToAddress(location);
      if (mounted) {
        setState(() {
          _selectedAddress = address ?? 'Unknown location';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = 'Unable to get address';
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onMapMoved(LatLng center) {
    setState(() {
      _selectedLocation = center;
    });
    _updateAddress(center);
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _updateAddress(location);
  }

  void _saveLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, {
        'location': _selectedLocation,
        'address': _selectedAddress,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.placeLabel != null
            ? 'Set ${widget.placeLabel} location'
            : 'Select location'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Stack(
        children: [
          // Map
          MapWidget(
            mapController: _mapController,
            currentLocation: _currentLocation,
            pickupLocation: null,
            destinationLocation: _selectedLocation,
            onLocationUpdate: (location) {},
            onPickupSelected: (location) {},
            onDestinationSelected: _onMapTapped,
            onMapMoved: _onMapMoved,
          ),

          // Instructions overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap on map or move to select location',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (_selectedLocation != null)
                          const SizedBox(height: 4),
                        if (_selectedLocation != null)
                          Text(
                            _isLoadingAddress
                                ? 'Loading address...'
                                : _selectedAddress,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center pin indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.destinationRed,
                  size: 48,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.destinationRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Bottom sheet with address and save button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Location',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            _isLoadingAddress
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    _selectedAddress,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _selectedLocation != null ? _saveLocation : null,
                      icon: Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary),
                      label: Text(
                        'Save Location',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
}

