import '../../../shared/data/api_client.dart';

class RideApiService {
  final ApiClient _apiClient = ApiClient();

  /// Request a new ride
  Future<Map<String, dynamic>> requestRide({
    required double pickupLat,
    required double pickupLon,
    required String pickupAddress,
    required double destLat,
    required double destLon,
    required String destAddress,
    required String vehicleType,
    required double estimatedFare,
    String paymentMethod = 'Cash',
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/ride-request',
        data: {
          'pickup_latitude': pickupLat,
          'pickup_longitude': pickupLon,
          'pickup_address': pickupAddress,
          'destination_latitude': destLat,
          'destination_longitude': destLon,
          'destination_address': destAddress,
          'vehicle_type': vehicleType,
          'estimated_fare': estimatedFare,
          'payment_method': paymentMethod,
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Error requesting ride: $e');
      rethrow;
    }
  }

  /// Get ride status
  Future<Map<String, dynamic>> getRideStatus(int rideId) async {
    try {
      final response = await _apiClient.get('/api/ride-status/$rideId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Error getting ride status: $e');
      rethrow;
    }
  }

  /// Cancel a ride
  Future<void> cancelRide(int rideId, String reason) async {
    try {
      await _apiClient.post(
        '/api/cancel-ride',
        data: {
          'ride_id': rideId,
          'cancellation_reason': reason,
        },
      );
    } catch (e) {
      print('Error cancelling ride: $e');
      rethrow;
    }
  }

  /// Rate a completed ride
  Future<void> rateRide({
    required int rideId,
    required double rating,
    String? feedback,
    double? tip,
  }) async {
    try {
      await _apiClient.post(
        '/api/rate-ride',
        data: {
          'ride_id': rideId,
          'rating': rating,
          'feedback': feedback,
          'tip': tip,
        },
      );
    } catch (e) {
      print('Error rating ride: $e');
      rethrow;
    }
  }
}
