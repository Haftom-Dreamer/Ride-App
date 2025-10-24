import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../core/config/app_config.dart';
import '../presentation/screens/saved_places_screen.dart';

class SavedPlacesRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<SavedPlace>> getSavedPlaces() async {
    try {
      final response = await _apiClient.get(
        '${AppConfig.baseUrl}/api/passenger/saved-places',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true && responseData['places'] != null) {
          final placesList = responseData['places'] as List;
          return placesList
              .map((placeData) => SavedPlace.fromJson(placeData))
              .toList();
        } else {
          throw Exception(
              'Get saved places failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Get saved places failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Get saved places failed: $e');
    }
  }

  Future<SavedPlace> addSavedPlace({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConfig.baseUrl}/api/passenger/saved-places',
        data: {
          'label': label,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 201) {
        final responseData = response.data;

        if (responseData['success'] == true && responseData['place'] != null) {
          return SavedPlace.fromJson(responseData['place']);
        } else {
          throw Exception(
              'Add saved place failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Add saved place failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Add saved place failed: $e');
    }
  }

  Future<void> deleteSavedPlace(int placeId) async {
    try {
      final response = await _apiClient.delete(
        '${AppConfig.baseUrl}/api/passenger/saved-places/$placeId',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return; // Success
        } else {
          throw Exception(
              'Delete saved place failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Delete saved place failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Delete saved place failed: $e');
    }
  }
}
