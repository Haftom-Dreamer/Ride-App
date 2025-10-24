import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../core/config/app_config.dart';

class RideTrackingRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> requestRide({
    required String pickupAddress,
    required String destinationAddress,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    required double estimatedFare,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConfig.baseUrl}/api/ride-request',
        data: {
          'pickup_address': pickupAddress,
          'destination_address': destinationAddress,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dest_lat': destLat,
          'dest_lng': destLng,
          'estimated_fare': estimatedFare,
          'vehicle_type': 'Bajaj', // Default vehicle type
          'payment_method': 'Cash', // Default payment method
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return {
            'status': responseData['status'] ?? 'Requested',
            'ride_id': responseData['ride_id'],
          };
        } else {
          throw Exception(
              'Request failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Request failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Request ride failed: $e');
    }
  }

  Future<Map<String, dynamic>> getRideStatus() async {
    try {
      final response = await _apiClient.get(
        '${AppConfig.baseUrl}/api/ride-status',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return {
            'status': responseData['status'] ?? 'Requested',
            'driver': responseData['driver'],
            'driver_location': responseData['driver_location'],
          };
        } else {
          throw Exception(
              'Get status failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Get status failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Get ride status failed: $e');
    }
  }

  Future<void> cancelRide() async {
    try {
      final response = await _apiClient.post(
        '${AppConfig.baseUrl}/api/cancel-ride',
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
              'Cancel failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Cancel failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Cancel ride failed: $e');
    }
  }
}
