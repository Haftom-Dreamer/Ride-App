import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/ride_tracking_provider.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final double estimatedFare;

  const RideTrackingScreen({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.estimatedFare,
  });

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  late MapController _mapController;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Request ride when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestRide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideTrackingState = ref.watch(rideTrackingProvider);
    final rideTrackingNotifier = ref.read(rideTrackingProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Tracking'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelDialog(rideTrackingNotifier),
        ),
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 2,
            child: _buildMap(rideTrackingState),
          ),

          // Ride details
          Expanded(
            flex: 1,
            child: _buildRideDetails(rideTrackingState, rideTrackingNotifier),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(RideTrackingState state) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.pickupLat, widget.pickupLng),
        initialZoom: 15.0,
        minZoom: 10.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.selamawi.ride',
        ),
        MarkerLayer(
          markers: [
            // Pickup marker
            Marker(
              point: LatLng(widget.pickupLat, widget.pickupLng),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.radio_button_checked,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            // Destination marker
            Marker(
              point: LatLng(widget.destLat, widget.destLng),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.radio_button_checked,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            // Driver marker (if assigned)
            if (state.driverLocation != null)
              Marker(
                point: LatLng(state.driverLocation!.latitude,
                    state.driverLocation!.longitude),
                width: 50,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRideDetails(
      RideTrackingState state, RideTrackingNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          _buildStatusIndicator(state),

          const SizedBox(height: 16),

          // Route information
          _buildRouteInfo(),

          const SizedBox(height: 16),

          // Driver information (if assigned)
          if (state.driver != null) ...[
            _buildDriverInfo(state.driver!),
            const SizedBox(height: 16),
          ],

          // Action buttons
          _buildActionButtons(state, notifier),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(RideTrackingState state) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (state.status) {
      case 'Requested':
        statusText = 'Looking for driver...';
        statusColor = Colors.orange;
        statusIcon = Icons.search;
        break;
      case 'Assigned':
        statusText = 'Driver assigned';
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle;
        break;
      case 'In Progress':
        statusText = 'Driver on the way';
        statusColor = Colors.green;
        statusIcon = Icons.directions_car;
        break;
      case 'Completed':
        statusText = 'Ride completed';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Cancelled':
        statusText = 'Ride cancelled';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusText = 'Requesting ride...';
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Route',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.pickupAddress,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.destinationAddress,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.attach_money, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              '${widget.estimatedFare.toStringAsFixed(2)} ETB',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverInfo(Driver driver) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: driver.profilePicture != null
                  ? NetworkImage(driver.profilePicture!)
                  : null,
              child: driver.profilePicture == null
                  ? Icon(Icons.person, color: Colors.blue.shade700)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${driver.vehicleType} • ${driver.licensePlate}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  driver.rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () => _callDriver(driver.phoneNumber),
              style: IconButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: () => _messageDriver(driver.phoneNumber),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade700,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.sos),
              onPressed: () => _showSOSDialog(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      RideTrackingState state, RideTrackingNotifier notifier) {
    return Row(
      children: [
        if (state.status == 'Requested' || state.status == 'Assigned') ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCancelDialog(notifier),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Ride'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        if (state.status == 'Completed') ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _rateRide(notifier),
              icon: const Icon(Icons.star),
              label: const Text('Rate Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _requestRide() {
    if (!_isRequesting) {
      _isRequesting = true;
      ref.read(rideTrackingProvider.notifier).requestRide(
            pickupAddress: widget.pickupAddress,
            destinationAddress: widget.destinationAddress,
            pickupLat: widget.pickupLat,
            pickupLng: widget.pickupLng,
            destLat: widget.destLat,
            destLng: widget.destLng,
            estimatedFare: widget.estimatedFare,
          );
    }
  }

  void _showCancelDialog(RideTrackingNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.cancelRide();
              Navigator.of(context).pop(); // Go back to home screen
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _callDriver(String phoneNumber) {
    // TODO: Implement phone call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $phoneNumber')),
    );
  }

  void _messageDriver(String phoneNumber) {
    // TODO: Implement messaging functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Messaging $phoneNumber')),
    );
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency SOS'),
        content: const Text(
            'This will send an emergency alert to authorities and your emergency contacts.'),
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
                  content: Text('Emergency alert sent'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child:
                const Text('Send Alert', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _rateRide(RideTrackingNotifier notifier) {
    // TODO: Implement rating functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating functionality coming soon')),
    );
  }
}

// Driver model
class Driver {
  final int id;
  final String name;
  final String phoneNumber;
  final String vehicleType;
  final String licensePlate;
  final double rating;
  final String? profilePicture;
  final LatLng? location;

  const Driver({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.vehicleType,
    required this.licensePlate,
    required this.rating,
    this.profilePicture,
    this.location,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      licensePlate: json['license_plate'] as String,
      rating: (json['rating'] as num).toDouble(),
      profilePicture: json['profile_picture'] as String?,
      location: json['location'] != null
          ? LatLng(
              (json['location']['latitude'] as num).toDouble(),
              (json['location']['longitude'] as num).toDouble(),
            )
          : null,
    );
  }
}
