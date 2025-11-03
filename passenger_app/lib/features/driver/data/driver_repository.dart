import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/data/api_client.dart';

class DriverRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _apiClient.get('/api/driver/profile');
    return res.data as Map<String, dynamic>;
  }

  Future<void> setAvailability(bool online) async {
    await _apiClient.post('/api/driver/availability', data: {
      'status': online ? 'Available' : 'Offline',
    });
  }

  Future<void> updateLocation({required double lat, required double lon, double? heading}) async {
    await _apiClient.post('/api/driver/location', data: {
      'lat': lat,
      'lon': lon,
      if (heading != null) 'heading': heading,
    });
  }

  Future<Map<String, dynamic>> getEarnings({String? from, String? to}) async {
    final res = await _apiClient.get('/api/driver/earnings', queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loginDriver({
    required String identifier, // phone or driver_id
    required String password,
  }) async {
    final res = await _apiClient.post('/api/driver/login', data: {
      'identifier': identifier,
      'password': password,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signupDriver({
    required String name,
    required String phoneNumber,
    required String password,
    required String vehicleType,
    required String vehicleDetails,
    String? email,
    String? plateNumber,
    String? licenseInfo,
    XFile? profilePicture,
    XFile? licenseDocument,
    XFile? vehicleDocument,
    XFile? platePhoto,
    XFile? idDocument,
  }) async {
    // Use FormData if files are provided, otherwise JSON
    final hasFiles = profilePicture != null ||
        licenseDocument != null ||
        vehicleDocument != null ||
        platePhoto != null ||
        idDocument != null;

    if (hasFiles) {
      final formData = FormData.fromMap({
        'name': name,
        'phone_number': phoneNumber,
        'password': password,
        'vehicle_type': vehicleType,
        'vehicle_details': vehicleDetails,
        if (email != null && email.isNotEmpty) 'email': email,
        if (plateNumber != null && plateNumber.isNotEmpty)
          'vehicle_plate_number': plateNumber,
        if (licenseInfo != null && licenseInfo.isNotEmpty)
          'license_info': licenseInfo,
        if (profilePicture != null)
          'profile_picture': await MultipartFile.fromFile(
            profilePicture.path,
            filename: profilePicture.name,
          ),
        if (licenseDocument != null)
          'license_document': await MultipartFile.fromFile(
            licenseDocument.path,
            filename: licenseDocument.name,
          ),
        if (vehicleDocument != null)
          'vehicle_document': await MultipartFile.fromFile(
            vehicleDocument.path,
            filename: vehicleDocument.name,
          ),
        if (platePhoto != null)
          'plate_photo': await MultipartFile.fromFile(
            platePhoto.path,
            filename: platePhoto.name,
          ),
        if (idDocument != null)
          'id_document': await MultipartFile.fromFile(
            idDocument.path,
            filename: idDocument.name,
          ),
      });

      final res = await _apiClient.post(
        '/api/driver/signup',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return res.data as Map<String, dynamic>;
    } else {
      final res = await _apiClient.post('/api/driver/signup', data: {
        'name': name,
        'phone_number': phoneNumber,
        'password': password,
        'vehicle_type': vehicleType,
        'vehicle_details': vehicleDetails,
        if (email != null && email.isNotEmpty) 'email': email,
        if (plateNumber != null && plateNumber.isNotEmpty)
          'vehicle_plate_number': plateNumber,
        if (licenseInfo != null && licenseInfo.isNotEmpty)
          'license_info': licenseInfo,
      });
      return res.data as Map<String, dynamic>;
    }
  }

  /// Get available rides that need drivers
  Future<List<Map<String, dynamic>>> getAvailableRides() async {
    try {
      final res = await _apiClient.get('/api/driver/available-rides');
      if (res.data is List) {
        return (res.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      // If endpoint doesn't exist or fails, return empty list
      return [];
    }
  }

  /// Accept a ride offer
  Future<bool> acceptRideOffer(int rideId) async {
    try {
      final res = await _apiClient.post('/api/driver/accept-ride', data: {
        'ride_id': rideId,
      });
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Decline a ride offer
  Future<void> declineRideOffer(int rideId) async {
    try {
      await _apiClient.post('/api/driver/decline-offer', data: {
        'ride_id': rideId,
      });
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get active ride for the current driver
  Future<Map<String, dynamic>?> getActiveRide() async {
    try {
      final res = await _apiClient.get('/api/driver/active-ride');
      if (res.data != null && res.data is Map && res.data['ride'] != null) {
        return res.data['ride'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mark driver as arrived at pickup
  Future<void> markArrived(int rideId) async {
    await _apiClient.post('/api/driver/ride/arrived', data: {
      'ride_id': rideId,
    });
  }

  /// Start the trip (passenger picked up)
  Future<void> startTrip(int rideId) async {
    await _apiClient.post('/api/driver/ride/start', data: {
      'ride_id': rideId,
    });
  }

  /// End the trip (passenger dropped off)
  Future<void> endTrip(int rideId) async {
    await _apiClient.post('/api/driver/ride/end', data: {
      'ride_id': rideId,
    });
  }

  /// Get chat messages for a ride
  Future<List<Map<String, dynamic>>> getRideChat(int rideId) async {
    try {
      final res = await _apiClient.get('/api/driver/ride/$rideId/chat');
      if (res.data is List) {
        return (res.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Send a chat message for a ride
  Future<Map<String, dynamic>> sendRideChatMessage(int rideId, String message) async {
    final res = await _apiClient.post('/api/driver/ride/$rideId/chat', data: {
      'message': message,
    });
    return res.data as Map<String, dynamic>;
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture(String imagePath) async {
    final formData = FormData.fromMap({
      'profile_picture': await MultipartFile.fromFile(imagePath),
    });
    final res = await _apiClient.post(
      '/api/driver/profile-picture',
      data: formData,
    );
    return res.data['profile_picture'] as String;
  }

  /// Submit support request or report
  Future<void> submitSupportRequest({
    required String subject,
    required String message,
    String? type,
  }) async {
    await _apiClient.post('/api/driver/support', data: {
      'subject': subject,
      'message': message,
      'type': type ?? 'support',
    });
  }

  /// Get messages from dispatcher
  Future<List<Map<String, dynamic>>> getDispatcherMessages() async {
    try {
      final res = await _apiClient.get('/api/driver/dispatcher-messages');
      if (res.data is List) {
        return (res.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Send message to dispatcher
  Future<void> sendToDispatcher(String message) async {
    await _apiClient.post('/api/driver/dispatcher-messages', data: {
      'message': message,
    });
  }
}


