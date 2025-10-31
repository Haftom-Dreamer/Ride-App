import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../shared/domain/models/saved_place.dart';

class SavedPlacesRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<SavedPlace>> getSavedPlaces() async {
    try {
      final response = await _apiClient.get(
        '/api/passenger/saved-places',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        // API returns a plain list of places
        final data = response.data;
        if (data is List) {
          return data.map((e) => SavedPlace.fromJson(e)).toList();
        }
        throw Exception('Unexpected response format');
      }
      throw Exception('Get saved places failed: HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Get saved places failed: $e');
    }
  }

  Future<SavedPlace> saveOrUpdatePlace({
    int? id,
    required String label,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/passenger/saved-places',
        data: {
          if (id != null) 'id': id,
          'label': label,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // API returns saved place object directly
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return SavedPlace.fromJson(data);
        }
        throw Exception('Unexpected response format');
      }
      throw Exception('Save place failed: HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Save place failed: $e');
    }
  }

  Future<void> deleteSavedPlace(int placeId) async {
    try {
      final response = await _apiClient.delete(
        '/api/passenger/saved-places/$placeId',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        return;
      }
      throw Exception('Delete saved place failed: HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Delete saved place failed: $e');
    }
  }
}
