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
      'status': online ? 'Online' : 'Offline',
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
}


