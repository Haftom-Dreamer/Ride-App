import 'dart:developer';
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
    required double distanceKm,
    required double estimatedFare,
    String paymentMethod = 'Cash',
    String? note,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/passenger/ride-request',
        data: {
          'pickup_address': pickupAddress,
          'pickup_lat': pickupLat,
          'pickup_lon': pickupLon,
          'dest_address': destAddress,
          'dest_lat': destLat,
          'dest_lon': destLon,
          'distance_km': distanceKm,
          'fare': estimatedFare,
          'vehicle_type': vehicleType,
          'payment_method': paymentMethod,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      log('Error requesting ride: $e', name: 'RideApiService');
      throw RideApiException('Failed to request ride: ${e.toString()}');
    }
  }

  /// Get ride status
  Future<Map<String, dynamic>> getRideStatus(int rideId) async {
    try {
      final response = await _apiClient.get('/api/passenger/ride-status/$rideId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      log('Error getting ride status: $e', name: 'RideApiService');
      throw RideApiException('Failed to get ride status: ${e.toString()}');
    }
  }

  /// Cancel a ride
  Future<void> cancelRide(int rideId, String reason) async {
    try {
      await _apiClient.post(
        '/api/passenger/cancel-ride',
        data: {
          'ride_id': rideId,
          'cancellation_reason': reason,
        },
      );
    } catch (e) {
      log('Error cancelling ride: $e', name: 'RideApiService');
      throw RideApiException('Failed to cancel ride: ${e.toString()}');
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
        '/api/passenger/rate-ride',
        data: {
          'ride_id': rideId,
          'rating': rating,
          'feedback': feedback,
          'tip': tip,
        },
      );
    } catch (e) {
      log('Error rating ride: $e', name: 'RideApiService');
      throw RideApiException('Failed to rate ride: ${e.toString()}');
    }
  }
}

/// Custom exception for ride API errors
class RideApiException implements Exception {
  final String message;
  RideApiException(this.message);

  @override
  String toString() => 'RideApiException: $message';
}
