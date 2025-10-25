import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/domain/models/ride.dart';

class RideHistoryRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<Ride>> getRideHistory() async {
    try {
      final response = await _apiClient.get(
        '${AppConfig.baseUrl}/api/passenger/ride-history',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true && responseData['rides'] != null) {
          final ridesList = responseData['rides'] as List;
          return ridesList.map((rideData) => Ride.fromJson(rideData)).toList();
        } else {
          throw Exception(
              'Get ride history failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Get ride history failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Get ride history failed: $e');
    }
  }
}
