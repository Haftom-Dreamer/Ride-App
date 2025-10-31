import 'dart:io';
import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../shared/domain/models/user.dart';

class ProfileRepository {
  final ApiClient _apiClient = ApiClient();

  Future<String> uploadProfilePicture(File file) async {
    try {
      final formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'profile.jpg',
        ),
      });

      final response = await _apiClient.post(
        '/api/passenger/profile-picture',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['profile_picture'] != null) {
          return data['profile_picture'] as String;
        }
        throw Exception('Unexpected response');
      }

      throw Exception('Upload failed: HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<User> updateProfile({
    required String username,
    required String email,
    required String phoneNumber,
    String? profilePicture,
  }) async {
    try {
      final response = await _apiClient.put(
        '/api/passenger/profile',
        data: {
          'username': username,
          'email': email,
          'phone_number': phoneNumber,
          if (profilePicture != null) 'profile_picture': profilePicture,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['user'] != null) {
          return User.fromJson(data['user']);
        }
        throw Exception('Unexpected response');
      }
      throw Exception('Update failed: HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Update profile failed: $e');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/passenger/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return;
      }
      throw Exception('Password change failed: HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Change password failed: $e');
    }
  }
}
