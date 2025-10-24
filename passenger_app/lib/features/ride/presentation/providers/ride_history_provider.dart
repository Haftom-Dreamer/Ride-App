import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ride_history_repository.dart';
import '../screens/ride_history_screen.dart';

// Ride History state
class RideHistoryState {
  final List<RideHistory> rides;
  final List<RideHistory> filteredRides;
  final bool isLoading;
  final String? error;

  const RideHistoryState({
    this.rides = const [],
    this.filteredRides = const [],
    this.isLoading = false,
    this.error,
  });

  RideHistoryState copyWith({
    List<RideHistory>? rides,
    List<RideHistory>? filteredRides,
    bool? isLoading,
    String? error,
  }) {
    return RideHistoryState(
      rides: rides ?? this.rides,
      filteredRides: filteredRides ?? this.filteredRides,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Ride History notifier
class RideHistoryNotifier extends StateNotifier<RideHistoryState> {
  final RideHistoryRepository _rideHistoryRepository;

  RideHistoryNotifier(this._rideHistoryRepository)
      : super(const RideHistoryState());

  Future<void> loadRideHistory() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rides = await _rideHistoryRepository.getRideHistory();
      state = state.copyWith(
        rides: rides,
        filteredRides: rides,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        rides: [],
        filteredRides: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void filterRides(String filter) {
    List<RideHistory> filtered;

    switch (filter) {
      case 'Completed':
        filtered = state.rides
            .where((ride) => ride.status.toLowerCase() == 'completed')
            .toList();
        break;
      case 'Cancelled':
        filtered = state.rides
            .where((ride) => ride.status.toLowerCase() == 'cancelled')
            .toList();
        break;
      case 'In Progress':
        filtered = state.rides
            .where((ride) =>
                ride.status.toLowerCase() == 'in progress' ||
                ride.status.toLowerCase() == 'assigned' ||
                ride.status.toLowerCase() == 'requested')
            .toList();
        break;
      default: // 'All'
        filtered = state.rides;
    }

    state = state.copyWith(filteredRides: filtered);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final rideHistoryRepositoryProvider = Provider<RideHistoryRepository>((ref) {
  return RideHistoryRepository();
});

final rideHistoryProvider =
    StateNotifierProvider<RideHistoryNotifier, RideHistoryState>((ref) {
  final rideHistoryRepository = ref.watch(rideHistoryRepositoryProvider);
  return RideHistoryNotifier(rideHistoryRepository);
});
