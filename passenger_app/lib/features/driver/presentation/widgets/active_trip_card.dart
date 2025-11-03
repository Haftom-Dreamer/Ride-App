import 'package:flutter/material.dart';

class ActiveTripCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final VoidCallback? onViewDetails;
  final VoidCallback? onNavigate;

  const ActiveTripCard({
    super.key,
    required this.ride,
    this.onViewDetails,
    this.onNavigate,
  });

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

  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? 'Unknown';
    final passenger = ride['passenger'] as Map<String, dynamic>?;
    final passengerName = passenger?['name'] as String? ?? 'Passenger';
    final pickupAddress = ride['pickup_address'] as String? ?? 'Pickup location';
    final destAddress = ride['dest_address'] as String? ?? 'Destination';
    final fare = ride['fare'] as num?;
    final fareStr = fare != null ? 'ETB ${fare.toStringAsFixed(2)}' : 'N/A';

    return Card(
      color: _getStatusColor(status).withOpacity(0.1),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusLabel(status),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                      ),
                      Text(
                        passengerName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
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
            const Divider(height: 24),
            // Pickup
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.green, size: 20),
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
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Destination
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 20),
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
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                if (onNavigate != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (onNavigate != null && onViewDetails != null)
                  const SizedBox(width: 12),
                if (onViewDetails != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onViewDetails,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Manage Trip'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

