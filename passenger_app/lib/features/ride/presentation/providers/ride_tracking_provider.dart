import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/ride_tracking_repository.dart';
import '../screens/ride_tracking_screen.dart';

// Ride Tracking state
class RideTrackingState {
  final String status;
  final Driver? driver;
  final LatLng? driverLocation;
  final bool isLoading;
  final String? error;

  const RideTrackingState({
    this.status = 'Requested',
    this.driver,
    this.driverLocation,
    this.isLoading = false,
    this.error,
  });

  RideTrackingState copyWith({
    String? status,
    Driver? driver,
    LatLng? driverLocation,
    bool? isLoading,
    String? error,
  }) {
    return RideTrackingState(
      status: status ?? this.status,
      driver: driver ?? this.driver,
      driverLocation: driverLocation ?? this.driverLocation,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Ride Tracking notifier
class RideTrackingNotifier extends StateNotifier<RideTrackingState> {
  final RideTrackingRepository _rideTrackingRepository;

  RideTrackingNotifier(this._rideTrackingRepository)
      : super(const RideTrackingState());

  Future<void> requestRide({
    required String pickupAddress,
    required String destinationAddress,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    required double estimatedFare,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rideData = await _rideTrackingRepository.requestRide(
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        destLat: destLat,
        destLng: destLng,
        estimatedFare: estimatedFare,
      );

      state = state.copyWith(
        status: rideData['status'] as String,
        isLoading: false,
        error: null,
      );

      // Start polling for updates
      _startPolling();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> cancelRide() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _rideTrackingRepository.cancelRide();
      state = state.copyWith(
        status: 'Cancelled',
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _startPolling() async {
    // Poll for ride updates every 5 seconds
    while (state.status != 'Completed' && state.status != 'Cancelled') {
      await Future.delayed(const Duration(seconds: 5));

      try {
        final rideData = await _rideTrackingRepository.getRideStatus();

        state = state.copyWith(
          status: rideData['status'] as String,
          driver: rideData['driver'] != null
              ? Driver.fromJson(rideData['driver'] as Map<String, dynamic>)
              : null,
          driverLocation: rideData['driver_location'] != null
              ? LatLng(
                  (rideData['driver_location']['latitude'] as num).toDouble(),
                  (rideData['driver_location']['longitude'] as num).toDouble(),
                )
              : null,
        );

        // Stop polling if ride is completed or cancelled
        if (state.status == 'Completed' || state.status == 'Cancelled') {
          break;
        }
      } catch (e) {
        // Continue polling even if there's an error
        print('Polling error: $e');
      }
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final rideTrackingRepositoryProvider = Provider<RideTrackingRepository>((ref) {
  return RideTrackingRepository();
});

final rideTrackingProvider =
    StateNotifierProvider<RideTrackingNotifier, RideTrackingState>((ref) {
  final rideTrackingRepository = ref.watch(rideTrackingRepositoryProvider);
  return RideTrackingNotifier(rideTrackingRepository);
});
