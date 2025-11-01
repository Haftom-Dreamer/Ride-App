import 'package:latlong2/latlong.dart';
import '../../../shared/data/api_client.dart';
import '../../../shared/domain/models/ride.dart';
import '../../../shared/domain/models/saved_place.dart';
import '../../../shared/domain/models/fare_estimate.dart';

class RideRepository {
  final ApiClient _apiClient = ApiClient();

  Future<FareEstimate> estimateFare({
    required LatLng pickup,
    required LatLng destination,
    required String vehicleType,
  }) async {
    final response = await _apiClient.post(
      '/api/passenger/fare-estimate',
      data: {
        'pickup_lat': pickup.latitude,
        'pickup_lon': pickup.longitude,
        'dest_lat': destination.latitude,
        'dest_lon': destination.longitude,
        'vehicle_type': vehicleType,
      },
    );
    return FareEstimate.fromJson(response.data);
  }

  Future<Map<String, dynamic>> requestRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLon,
    required String destAddress,
    required double destLat,
    required double destLon,
    required double distanceKm,
    required double fare,
    required String vehicleType,
    required String paymentMethod,
    String? note,
  }) async {
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
        'fare': fare,
        'vehicle_type': vehicleType,
        'payment_method': paymentMethod,
        if (note != null) 'note': note,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> checkRideStatus(int rideId) async {
    final response = await _apiClient.get('/api/passenger/ride-status/$rideId');
    return response.data;
  }

  Future<void> cancelRide(int rideId, {String? reason}) async {
    await _apiClient.post(
      '/api/passenger/cancel-ride',
      data: {
        'ride_id': rideId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<void> rateRide({
    required int rideId,
    required int rating,
    String? comment,
  }) async {
    await _apiClient.post(
      '/api/passenger/rate-ride',
      data: {
        'ride_id': rideId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  Future<List<SavedPlace>> getSavedPlaces() async {
    final response = await _apiClient.get('/api/saved-places');
    final List<dynamic> places = response.data;
    return places.map((json) => SavedPlace.fromJson(json)).toList();
  }

  Future<SavedPlace> savePlaceAdd(SavedPlace place) async {
    final response = await _apiClient.post(
      '/api/saved-places',
      data: place.toJson(),
    );
    return SavedPlace.fromJson(response.data);
  }

  Future<void> deleteSavedPlace(int placeId) async {
    await _apiClient.delete('/api/saved-places/$placeId');
  }

  Future<Map<String, dynamic>> getRideHistory({
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page,
      'per_page': perPage,
    };
    if (status != null) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      '/api/passenger/ride-history',
      queryParameters: queryParams,
    );
    return response.data;
  }

  Future<Ride> getRideDetails(int rideId) async {
    final response = await _apiClient.get('/api/passenger/ride-details/$rideId');
    return Ride.fromJson(response.data);
  }

  Future<void> sendSOS({
    required int rideId,
    required LatLng location,
    String? message,
  }) async {
    await _apiClient.post(
      '/api/passenger/emergency-sos',
      data: {
        'ride_id': rideId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        if (message != null) 'message': message,
      },
    );
  }
}


