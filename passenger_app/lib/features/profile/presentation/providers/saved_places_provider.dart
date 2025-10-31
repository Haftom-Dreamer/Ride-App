import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/saved_places_repository.dart';
import '../../../../shared/domain/models/saved_place.dart';

// Saved Places state
class SavedPlacesState {
  final List<SavedPlace> places;
  final bool isLoading;
  final String? error;

  const SavedPlacesState({
    this.places = const [],
    this.isLoading = false,
    this.error,
  });

  SavedPlacesState copyWith({
    List<SavedPlace>? places,
    bool? isLoading,
    String? error,
  }) {
    return SavedPlacesState(
      places: places ?? this.places,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Saved Places notifier
class SavedPlacesNotifier extends StateNotifier<SavedPlacesState> {
  final SavedPlacesRepository _savedPlacesRepository;

  SavedPlacesNotifier(this._savedPlacesRepository)
      : super(const SavedPlacesState()) {
    loadSavedPlaces();
  }

  Future<void> loadSavedPlaces() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final places = await _savedPlacesRepository.getSavedPlaces();
      state = state.copyWith(
        places: places,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        places: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> addSavedPlace({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final newPlace = await _savedPlacesRepository.saveOrUpdatePlace(
        label: label,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );

      state = state.copyWith(
        places: [...state.places, newPlace],
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

  Future<void> deleteSavedPlace(int placeId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _savedPlacesRepository.deleteSavedPlace(placeId);

      state = state.copyWith(
        places: state.places.where((place) => place.id != placeId).toList(),
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

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final savedPlacesRepositoryProvider = Provider<SavedPlacesRepository>((ref) {
  return SavedPlacesRepository();
});

final savedPlacesProvider =
    StateNotifierProvider<SavedPlacesNotifier, SavedPlacesState>((ref) {
  final savedPlacesRepository = ref.watch(savedPlacesRepositoryProvider);
  return SavedPlacesNotifier(savedPlacesRepository);
});
