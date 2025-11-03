import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/driver_repository.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> ride;

  const ActiveTripScreen({
    super.key,
    required this.ride,
  });

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  final DriverRepository _repo = DriverRepository();
  bool _loading = false;
  Map<String, dynamic>? _currentRide;

  @override
  void initState() {
    super.initState();
    _currentRide = widget.ride;
    _refreshRide();
  }

  Future<void> _refreshRide() async {
    try {
      final activeRide = await _repo.getActiveRide();
      if (mounted && activeRide != null) {
        setState(() {
          _currentRide = activeRide;
        });
      } else if (mounted && activeRide == null) {
        // Trip completed or cancelled
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _openNavigation(double lat, double lon, String? address) async {
    // Try Google Maps first
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&destination_place_id=$address',
    );
    
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to generic maps URL
      final mapsUrl = Uri.parse('geo:$lat,$lon?q=$lat,$lon($address)');
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open navigation app'),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleAction(String action) async {
    if (_currentRide == null) return;
    
    final rideId = _currentRide!['id'] as int?;
    if (rideId == null) return;

    setState(() => _loading = true);
    
    try {
      switch (action) {
        case 'arrived':
          await _repo.markArrived(rideId);
          break;
        case 'start':
          await _repo.startTrip(rideId);
          break;
        case 'end':
          // Confirm before ending trip
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Complete Trip'),
              content: const Text('Are you sure you want to complete this trip?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Complete'),
                ),
              ],
            ),
          );
          
          if (confirmed == true) {
            await _repo.endTrip(rideId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip completed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            }
            return;
          }
          break;
      }
      
      // Refresh ride status
      await _refreshRide();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action successful'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: _loading ? null : onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    } else {
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: _loading ? null : onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _currentRide ?? widget.ride;
    final status = ride['status'] as String? ?? 'Unknown';
    final passenger = ride['passenger'] as Map<String, dynamic>?;
    final passengerName = passenger?['name'] as String? ?? 'Passenger';
    final passengerPhone = passenger?['phone'] as String?;
    final pickupAddress = ride['pickup_address'] as String? ?? 'Pickup location';
    final destAddress = ride['dest_address'] as String? ?? 'Destination';
    final pickupLat = ride['pickup_lat'] as num?;
    final pickupLon = ride['pickup_lon'] as num?;
    final destLat = ride['dest_lat'] as num?;
    final destLon = ride['dest_lon'] as num?;
    final fare = ride['fare'] as num?;
    final fareStr = fare != null ? 'ETB ${fare.toStringAsFixed(2)}' : 'N/A';
    final distanceKm = ride['distance_km'] as num?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRide,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && _currentRide == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusLabel(status),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                    ),
                              ),
                              if (status == 'On Trip')
                                Text(
                                  'Drop off passenger at destination',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Passenger Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            child: Text(
                              passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passengerName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                if (passengerPhone != null)
                                  TextButton.icon(
                                    onPressed: () async {
                                      final uri = Uri.parse('tel:$passengerPhone');
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    },
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: Text(passengerPhone),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            fareStr,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trip Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          // Pickup
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on, color: Colors.green, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pickup',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                    Text(
                                      pickupAddress,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (pickupLat != null && pickupLon != null)
                                      TextButton.icon(
                                        onPressed: () => _openNavigation(
                                          pickupLat.toDouble(),
                                          pickupLon.toDouble(),
                                          pickupAddress,
                                        ),
                                        icon: const Icon(Icons.navigation, size: 16),
                                        label: const Text('Navigate'),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Destination
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on, color: Colors.red, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Destination',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                    Text(
                                      destAddress,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (destLat != null && destLon != null)
                                      TextButton.icon(
                                        onPressed: () => _openNavigation(
                                          destLat.toDouble(),
                                          destLon.toDouble(),
                                          destAddress,
                                        ),
                                        icon: const Icon(Icons.navigation, size: 16),
                                        label: const Text('Navigate'),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (distanceKm != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Distance',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons based on status
                  if (status == 'Assigned') ...[
                    Row(
                      children: [
                        _buildActionButton(
                          label: 'Navigate to Pickup',
                          icon: Icons.navigation,
                          onPressed: () {
                            if (pickupLat != null && pickupLon != null) {
                              _openNavigation(
                                pickupLat.toDouble(),
                                pickupLon.toDouble(),
                                pickupAddress,
                              );
                            }
                          },
                          color: Colors.blue,
                          isPrimary: false,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          label: 'Mark Arrived',
                          icon: Icons.check_circle,
                          onPressed: () => _handleAction('arrived'),
                          color: Colors.orange,
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ] else if (status == 'Driver Arriving') ...[
                    Row(
                      children: [
                        _buildActionButton(
                          label: 'Start Trip',
                          icon: Icons.play_arrow,
                          onPressed: () => _handleAction('start'),
                          color: Colors.green,
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ] else if (status == 'On Trip') ...[
                    Row(
                      children: [
                        _buildActionButton(
                          label: 'Navigate to Destination',
                          icon: Icons.navigation,
                          onPressed: () {
                            if (destLat != null && destLon != null) {
                              _openNavigation(
                                destLat.toDouble(),
                                destLon.toDouble(),
                                destAddress,
                              );
                            }
                          },
                          color: Colors.blue,
                          isPrimary: false,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          label: 'End Trip',
                          icon: Icons.check_circle,
                          onPressed: () => _handleAction('end'),
                          color: Colors.green,
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'Assigned':
        return 'Pickup Passenger';
      case 'Driver Arriving':
        return 'Arrived at Pickup';
      case 'On Trip':
        return 'On Trip to Destination';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Assigned':
        return Icons.navigation;
      case 'Driver Arriving':
        return Icons.location_on;
      case 'On Trip':
        return Icons.directions_car;
      default:
        return Icons.local_taxi;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Assigned':
        return Colors.blue;
      case 'Driver Arriving':
        return Colors.orange;
      case 'On Trip':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

