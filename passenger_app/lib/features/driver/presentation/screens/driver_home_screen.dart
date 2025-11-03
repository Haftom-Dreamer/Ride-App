import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/driver_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/driver_stats_widget.dart';
import '../widgets/today_earnings_widget.dart';
import '../widgets/ride_offer_card.dart';
import '../providers/ride_offer_provider.dart';
import '../screens/driver_offer_dialog.dart';
import '../screens/available_rides_screen.dart';

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
  
  // Today's stats (will be fetched from earnings API)
  int _todayRides = 0;
  double _todayEarnings = 0.0;
  double? _rating;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTodayStats();
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

  Future<void> _toggleOnline(bool v) async {
    setState(() => _updating = true);
    try {
      await _repo.setAvailability(v);
      setState(() => _online = v);
      _startOrStopLocation();
      
      // Refresh profile to get updated status
      await _loadProfile();
      
      // If going online, refresh available rides
      if (v && mounted) {
        ref.read(rideOfferProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
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
        title: Text('Hi, $driverName'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadProfile(),
            _loadTodayStats(),
          ]);
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

              // Active Trip Section (placeholder - will be implemented in Task 4)
              if (_profile != null && _profile!['status'] == 'On Trip')
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.directions_car, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Active Trip',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Trip details will be shown here'),
                        // Will be replaced with ActiveTripCard in Task 4
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),

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




