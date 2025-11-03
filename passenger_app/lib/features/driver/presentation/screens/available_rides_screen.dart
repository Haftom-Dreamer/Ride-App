import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ride_offer_provider.dart';
import '../widgets/ride_offer_card.dart';

class AvailableRidesScreen extends ConsumerWidget {
  const AvailableRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideOfferState = ref.watch(rideOfferProvider);
    final rideOfferNotifier = ref.read(rideOfferProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => rideOfferNotifier.refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          rideOfferNotifier.refresh();
          // Wait a bit for the refresh to complete
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: rideOfferState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : rideOfferState.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading rides',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rideOfferState.error!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => rideOfferNotifier.refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : rideOfferState.availableRides.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_taxi,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No available rides',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ride requests will appear here when available',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: rideOfferState.availableRides.length,
                        itemBuilder: (context, index) {
                          final ride = rideOfferState.availableRides[index];
                          return RideOfferCard(
                            ride: ride,
                            onAccept: () async {
                              final rideId = ride['id'] as int?;
                              if (rideId == null) return;

                              final success = await rideOfferNotifier.acceptOffer(rideId);
                              if (context.mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ride accepted successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to accept ride. It may have been taken.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            onDecline: () async {
                              final rideId = ride['id'] as int?;
                              if (rideId == null) return;

                              await rideOfferNotifier.declineOffer(rideId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ride declined'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            onTap: () {
                              // Show detailed view
                              _showRideDetails(context, ride);
                            },
                          );
                        },
                      ),
      ),
    );
  }

  void _showRideDetails(BuildContext context, Map<String, dynamic> ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ride Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Fare', 'ETB ${(ride['fare'] as num?)?.toStringAsFixed(2) ?? 'N/A'}'),
              _buildDetailRow('Distance', '${(ride['distance_km'] as num?)?.toStringAsFixed(1) ?? 'N/A'} km'),
              _buildDetailRow('Vehicle Type', ride['vehicle_type'] as String? ?? 'Any'),
              _buildDetailRow('Pickup', ride['pickup_address'] as String? ?? 'N/A'),
              _buildDetailRow('Destination', ride['dest_address'] as String? ?? 'N/A'),
              if (ride['note'] != null && (ride['note'] as String).isNotEmpty)
                _buildDetailRow('Note', ride['note'] as String),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Accept logic here
                      },
                      child: const Text('Accept'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

