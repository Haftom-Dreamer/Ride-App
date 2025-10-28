import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapWidget extends StatefulWidget {
  final MapController mapController;
  final LatLng? currentLocation;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final List<LatLng>? routePoints;
  final Function(LatLng) onLocationUpdate;
  final Function(LatLng) onPickupSelected;
  final Function(LatLng) onDestinationSelected;
  final Function(LatLng)? onMapMoved; // Callback for when map moves

  const MapWidget({
    super.key,
    required this.mapController,
    this.currentLocation,
    this.pickupLocation,
    this.destinationLocation,
    this.routePoints,
    required this.onLocationUpdate,
    required this.onPickupSelected,
    required this.onDestinationSelected,
    this.onMapMoved,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  bool _isLocationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();
      if (newPermission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    setState(() {
      _isLocationPermissionGranted = true;
    });

    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    if (!_isLocationPermissionGranted) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final location = LatLng(position.latitude, position.longitude);

      widget.onLocationUpdate(location);

      // Move map to current location
      widget.mapController.move(location, 15.0);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: widget.currentLocation ??
            const LatLng(9.0192, 38.7525), // Addis Ababa
        initialZoom: 12.0,
        minZoom: 8.0,
        maxZoom: 18.0,
        rotationThreshold: 0.0, // Disable rotation
        // Notify parent when map position changes (user pans/zooms)
        onPositionChanged: (position, hasGesture) {
          if (position.center != null && widget.onMapMoved != null) {
            try {
              widget.onMapMoved!(position.center!);
            } catch (e) {
              // swallow errors from callbacks
            }
          }
        },
        onTap: (tapPosition, point) {
          _handleMapTap(point);
        },
      ),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.passenger_app',
        ),

        // Current location marker
        if (widget.currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.currentLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

        // Pickup location marker
        if (widget.pickupLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.pickupLocation!,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

        // Destination location marker
        if (widget.destinationLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.destinationLocation!,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.place,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

        // Route polyline
        if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints!,
                color: const Color(0xFF2563EB), // Use blue brand color
                strokeWidth: 4.0,
              ),
            ],
          ),
      ],
    );
  }

  void _handleMapTap(LatLng point) {
    // If no pickup is selected, set pickup
    if (widget.pickupLocation == null) {
      widget.onPickupSelected(point);
    }
    // If pickup is selected but no destination, set destination
    else if (widget.destinationLocation == null) {
      widget.onDestinationSelected(point);
    }
    // If both are selected, replace destination
    else {
      widget.onDestinationSelected(point);
    }
  }
}
