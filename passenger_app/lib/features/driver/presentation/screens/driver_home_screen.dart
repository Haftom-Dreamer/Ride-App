import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/driver_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/driver_stats_widget.dart';
import '../widgets/today_earnings_widget.dart';
import '../widgets/ride_offer_card.dart';
import '../widgets/active_trip_card.dart';
import '../providers/ride_offer_provider.dart';
import '../screens/driver_offer_dialog.dart';
import '../screens/available_rides_screen.dart';
import '../screens/active_trip_screen.dart';
import '../screens/driver_dispatcher_chat_screen.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final DriverRepository _repo = DriverRepository();
  bool _online = false;
  Timer? _locationTimer;
  bool _updating = false;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _activeRide;
  
  // Today's stats (will be fetched from earnings API)
  int _todayRides = 0;
  double _todayEarnings = 0.0;
  double? _rating;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTodayStats();
    _loadActiveRide();
    
    // Refresh active ride periodically
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadActiveRide();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _repo.getProfile();
      if (mounted) {
        setState(() {
          _profile = p;
        });
        // Check if driver status from profile matches online state
        final status = p['status'] as String?;
        if (status != null) {
          _online = status == 'Available' || status == 'On Trip';
          _startOrStopLocation();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadTodayStats() async {
    try {
      final earnings = await _repo.getEarnings();
      if (mounted) {
        setState(() {
          _todayRides = earnings['count'] as int? ?? 0;
          _todayEarnings = (earnings['total_earnings'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {
      // Ignore errors for now
    }
  }

  Future<void> _loadActiveRide() async {
    try {
      final activeRide = await _repo.getActiveRide();
      if (mounted) {
        setState(() {
          _activeRide = activeRide;
        });
      }
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> _toggleOnline(bool v) async {
    setState(() => _updating = true);
    try {
      await _repo.setAvailability(v);
      // Update local state immediately
      setState(() {
        _online = v;
      });
      _startOrStopLocation();
      
      // If going online, refresh available rides
      if (v && mounted) {
        ref.read(rideOfferProvider.notifier).refresh();
      }
      
      // Only refresh profile status if toggle failed (to sync)
      // Don't override the local state we just set
      try {
        final p = await _repo.getProfile();
        if (mounted && p['status'] != null) {
          final status = p['status'] as String;
          final shouldBeOnline = status == 'Available' || status == 'On Trip';
          // Only update if there's a mismatch (server changed it)
          if (shouldBeOnline != v) {
            setState(() => _online = shouldBeOnline);
            _startOrStopLocation();
          }
        }
      } catch (_) {
        // Ignore profile refresh errors - we already set the state
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() => _online = !v);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _startOrStopLocation() {
    _locationTimer?.cancel();
    if (_online) {
      _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pushLocation());
      _pushLocation();
    }
  }

  Future<void> _pushLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _repo.updateLocation(lat: pos.latitude, lon: pos.longitude);
    } catch (_) {}
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

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final driverName = authState.user?.username ?? _profile?['name'] ?? 'Driver';
    
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/Selamawi-logo 1 png.png',
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if logo not found
              return const Icon(Icons.local_taxi);
            },
          ),
        ),
        title: Row(
          children: [
            if (driverName.isNotEmpty) ...[
              const Icon(Icons.local_taxi, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  driverName,
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Text('Driver Dashboard'),
          ],
        ),
        actions: [
          // Chat with dispatcher button
          IconButton(
            icon: const Icon(Icons.message),
            tooltip: 'Chat with Dispatcher',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DriverDispatcherChatScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadProfile(),
            _loadTodayStats(),
            _loadActiveRide(),
          ]);
          // Also refresh ride offers if online
          if (_online && mounted) {
            ref.read(rideOfferProvider.notifier).refresh();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with rating (if available)
              if (_profile != null && _profile!['rating'] != null)
                Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Rating',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                (_profile!['rating'] as num).toStringAsFixed(1),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Today's Earnings Widget
              TodayEarningsWidget(
                earnings: _todayEarnings,
                rideCount: _todayRides,
              ),
              const SizedBox(height: 16),

              // Stats Widget
              DriverStatsWidget(
                todayRides: _todayRides,
                todayEarnings: _todayEarnings,
                rating: _rating ?? _profile?['rating'] as double?,
              ),
              const SizedBox(height: 16),

              // Availability Toggle
              Card(
                child: ListTile(
                  leading: Icon(
                    _online ? Icons.toggle_on : Icons.toggle_off,
                    color: _online ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  title: const Text('Availability'),
                  subtitle: Text(_online ? 'Online - Receiving ride offers' : 'Offline'),
                  trailing: _updating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _online,
                          onChanged: _toggleOnline,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'When Online, your location is sent every 5s so dispatch can offer trips.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 24),

              // Active Trip Section
              if (_activeRide != null) ...[
                ActiveTripCard(
                  ride: _activeRide!,
                  onViewDetails: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActiveTripScreen(ride: _activeRide!),
                      ),
                    );
                  },
                  onNavigate: () {
                    final status = _activeRide!['status'] as String?;
                    final pickupLat = _activeRide!['pickup_lat'] as num?;
                    final pickupLon = _activeRide!['pickup_lon'] as num?;
                    final destLat = _activeRide!['dest_lat'] as num?;
                    final destLon = _activeRide!['dest_lon'] as num?;
                    final pickupAddress = _activeRide!['pickup_address'] as String?;
                    final destAddress = _activeRide!['dest_address'] as String?;
                    
                    if (status == 'Assigned' || status == 'Driver Arriving') {
                      // Navigate to pickup
                      if (pickupLat != null && pickupLon != null) {
                        _openNavigation(
                          pickupLat.toDouble(),
                          pickupLon.toDouble(),
                          pickupAddress ?? 'Pickup',
                        );
                      }
                    } else if (status == 'On Trip') {
                      // Navigate to destination
                      if (destLat != null && destLon != null) {
                        _openNavigation(
                          destLat.toDouble(),
                          destLon.toDouble(),
                          destAddress ?? 'Destination',
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Available Rides Section
              Consumer(
                builder: (context, ref, child) {
                  final rideOfferState = ref.watch(rideOfferProvider);
                  final rideOfferNotifier = ref.read(rideOfferProvider.notifier);
                  
                  // Show first 2-3 rides on home screen
                  final displayedRides = rideOfferState.availableRides.take(2).toList();
                  
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Available Rides',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (rideOfferState.availableRides.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const AvailableRidesScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.arrow_forward, size: 16),
                                  label: const Text('View All'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!_online)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.power_settings_new,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Go online to see available rides',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (rideOfferState.isLoading)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (displayedRides.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.local_taxi,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No available rides at the moment',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ride offers will appear here',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                ...displayedRides.map((ride) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: RideOfferCard(
                                      ride: ride,
                                      onAccept: () async {
                                        final rideId = ride['id'] as int?;
                                        if (rideId == null) return;
                                        
                                        // Show notification dialog first for urgent offers
                                        await DriverOfferDialog.show(
                                          context,
                                          offer: ride,
                                          onAccept: (id) => rideOfferNotifier.acceptOffer(id),
                                          onDecline: () => rideOfferNotifier.declineOffer(rideId),
                                          expirationSeconds: 25,
                                        );
                                        
                                        // Refresh available rides after accepting
                                        rideOfferNotifier.refresh();
                                      },
                                      onDecline: () async {
                                        final rideId = ride['id'] as int?;
                                        if (rideId == null) return;
                                        await rideOfferNotifier.declineOffer(rideId);
                                      },
                                    ),
                                  );
                                }),
                                if (rideOfferState.availableRides.length > displayedRides.length)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Center(
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const AvailableRidesScreen(),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'View ${rideOfferState.availableRides.length - displayedRides.length} more rides',
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}




