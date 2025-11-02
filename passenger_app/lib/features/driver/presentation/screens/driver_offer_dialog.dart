import 'dart:async';
import 'package:flutter/material.dart';

class DriverOfferDialog extends StatefulWidget {
  final Map<String, dynamic> offer;
  final Future<bool> Function(int rideId) onAccept;
  final VoidCallback onDecline;

  const DriverOfferDialog({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> offer,
    required Future<bool> Function(int rideId) onAccept,
    required VoidCallback onDecline,
  }) async {
    // ignore: use_build_context_synchronously
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DriverOfferDialog(offer: offer, onAccept: onAccept, onDecline: onDecline),
    );
  }

  @override
  State<DriverOfferDialog> createState() => _DriverOfferDialogState();
}

class _DriverOfferDialogState extends State<DriverOfferDialog> {
  int _secondsLeft = 25;
  Timer? _timer;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final rideId = widget.offer['ride_id'] as int? ?? 0;
    final pickup = widget.offer['pickup_address'] as String? ?? 'Pickup';
    final dest = widget.offer['dest_address'] as String? ?? 'Destination';
    final fare = widget.offer['fare']?.toString() ?? '-';

    return AlertDialog(
      title: Text('New Trip Offer ($_secondsLeft s)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pickup, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('→ $dest'),
          const SizedBox(height: 8),
          Text('Fare: ETB $fare'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onDecline();
                },
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: _submitting
              ? null
              : () async {
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
                      setState(() => _error = 'Offer already taken');
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _error = 'Failed: $e');
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accept'),
        ),
      ],
    );
  }
}




