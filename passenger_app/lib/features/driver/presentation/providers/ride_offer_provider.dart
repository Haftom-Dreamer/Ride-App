import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/driver_repository.dart';

final rideOfferProvider = StateNotifierProvider<RideOfferNotifier, RideOfferState>((ref) {
  return RideOfferNotifier();
});

class RideOfferState {
  final List<Map<String, dynamic>> availableRides;
  final Map<String, dynamic>? currentOffer;
  final bool isLoading;
  final String? error;

  RideOfferState({
    this.availableRides = const [],
    this.currentOffer,
    this.isLoading = false,
    this.error,
  });

  RideOfferState copyWith({
    List<Map<String, dynamic>>? availableRides,
    Map<String, dynamic>? currentOffer,
    bool? isLoading,
    String? error,
  }) {
    return RideOfferState(
      availableRides: availableRides ?? this.availableRides,
      currentOffer: currentOffer ?? this.currentOffer,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class RideOfferNotifier extends StateNotifier<RideOfferState> {
  final DriverRepository _repo = DriverRepository();

  RideOfferNotifier() : super(RideOfferState()) {
    loadAvailableRides();
  }

  Future<void> loadAvailableRides() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rides = await _repo.getAvailableRides();
      state = state.copyWith(
        availableRides: rides,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setCurrentOffer(Map<String, dynamic>? offer) {
    state = state.copyWith(currentOffer: offer);
  }

  Future<bool> acceptOffer(int rideId) async {
    try {
      final success = await _repo.acceptRideOffer(rideId);
      if (success) {
        // Remove accepted ride from available list
        state = state.copyWith(
          availableRides: state.availableRides
              .where((ride) => ride['id'] != rideId)
              .toList(),
          currentOffer: null,
        );
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> declineOffer(int rideId) async {
    try {
      await _repo.declineRideOffer(rideId);
      // Remove declined ride from available list
      state = state.copyWith(
        availableRides: state.availableRides
            .where((ride) => ride['id'] != rideId)
            .toList(),
        currentOffer: null,
      );
    } catch (e) {
      // Ignore errors
    }
  }

  void refresh() {
    loadAvailableRides();
  }
}

