import 'dart:async';
import 'package:flutter/material.dart';

class DriverOfferDialog extends StatefulWidget {
  final Map<String, dynamic> offer;
  final Future<bool> Function(int rideId) onAccept;
  final VoidCallback onDecline;
  final int expirationSeconds;

  const DriverOfferDialog({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
    this.expirationSeconds = 25,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> offer,
    required Future<bool> Function(int rideId) onAccept,
    required VoidCallback onDecline,
    int expirationSeconds = 25,
  }) async {
    // ignore: use_build_context_synchronously
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DriverOfferDialog(
        offer: offer,
        onAccept: onAccept,
        onDecline: onDecline,
        expirationSeconds: expirationSeconds,
      ),
    );
  }

  @override
  State<DriverOfferDialog> createState() => _DriverOfferDialogState();
}

class _DriverOfferDialogState extends State<DriverOfferDialog> {
  late int _secondsLeft;
  Timer? _timer;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.expirationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        Navigator.of(context).pop();
        widget.onDecline();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDistance(double? distanceKm) {
    if (distanceKm == null) return 'N/A';
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)}m';
    }
    return '${distanceKm.toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final rideId = widget.offer['ride_id'] as int? ?? widget.offer['id'] as int? ?? 0;
    final pickup = widget.offer['pickup_address'] as String? ?? 'Pickup location';
    final dest = widget.offer['dest_address'] as String? ?? 'Destination';
    final fare = widget.offer['fare'] as num?;
    final fareStr = fare != null ? 'ETB ${fare.toStringAsFixed(2)}' : 'N/A';
    final distanceKm = widget.offer['distance_km'] as num?;
    final vehicleType = widget.offer['vehicle_type'] as String? ?? 'Any';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.local_taxi, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'New Ride Offer',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _secondsLeft <= 5 ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$_secondsLeft s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fare highlight
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fare',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      Text(
                        fareStr,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  if (distanceKm != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Distance',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        Text(
                          _formatDistance(distanceKm.toDouble()),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                ],
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
                  child: const Icon(Icons.location_on, color: Colors.green, size: 20),
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
                        pickup,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: Colors.red, size: 20),
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
                        dest,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (vehicleType != 'Any') ...[
              const SizedBox(height: 12),
              Chip(
                label: Text(vehicleType),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  _timer?.cancel();
                  Navigator.of(context).pop();
                  widget.onDecline();
                },
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: _submitting
              ? null
              : () async {
                  _timer?.cancel();
                  setState(() {
                    _submitting = true;
                    _error = null;
                  });
                  try {
                    final ok = await widget.onAccept(rideId);
                    if (!mounted) return;
                    if (ok) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _error = 'Offer already taken or expired');
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _error = 'Failed to accept: ${e.toString()}');
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Accept'),
        ),
      ],
    );
  }
}




