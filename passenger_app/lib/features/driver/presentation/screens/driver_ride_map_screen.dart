import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverRideMapScreen extends StatefulWidget {
  final double pickupLat;
  final double pickupLon;
  final String pickupAddress;
  final double? destLat;
  final double? destLon;
  final String? destAddress;
  final double? driverLat;
  final double? driverLon;

  const DriverRideMapScreen({
    super.key,
    required this.pickupLat,
    required this.pickupLon,
    required this.pickupAddress,
    this.destLat,
    this.destLon,
    this.destAddress,
    this.driverLat,
    this.driverLon,
  });

  @override
  State<DriverRideMapScreen> createState() => _DriverRideMapScreenState();
}

class _DriverRideMapScreenState extends State<DriverRideMapScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Center map on pickup location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(LatLng(widget.pickupLat, widget.pickupLon), 15.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    
    // Pickup marker
    markers.add(
      Marker(
        point: LatLng(widget.pickupLat, widget.pickupLon),
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );

    // Destination marker (if provided)
    if (widget.destLat != null && widget.destLon != null) {
      markers.add(
        Marker(
          point: LatLng(widget.destLat!, widget.destLon!),
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
    }

    // Driver location marker (if provided)
    if (widget.driverLat != null && widget.driverLon != null) {
      markers.add(
        Marker(
          point: LatLng(widget.driverLat!, widget.driverLon!),
          width: 60,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Map'),
      ),
      body: Column(
        children: [
          // Address Info Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.pickupAddress,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (widget.destAddress != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.destAddress!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(widget.pickupLat, widget.pickupLon),
                initialZoom: 15.0,
                minZoom: 10.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.selamawi.ride',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

