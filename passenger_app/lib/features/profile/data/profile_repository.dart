import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../shared/domain/models/user.dart';
import '../../../core/config/app_config.dart';

class ProfileRepository {
  final ApiClient _apiClient = ApiClient();

  Future<User> updateProfile({
    required String username,
    required String email,
    required String phoneNumber,
    String? profilePicture,
  }) async {
    try {
      final response = await _apiClient.put(
        '${AppConfig.baseUrl}/api/passenger/profile',
        data: {
          'username': username,
          'email': email,
          'phone_number': phoneNumber,
          if (profilePicture != null) 'profile_picture': profilePicture,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true && responseData['user'] != null) {
          final userData = responseData['user'];

          // Create user from backend response
          final user = User(
            id: userData['id'],
            username: userData['username'],
            email: userData['email'],
            phoneNumber: userData['phone_number'],
            passengerUid: userData['passenger_uid'],
            profilePicture: userData['profile_picture'],
          );

          return user;
        } else {
          throw Exception(
              'Update failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Update failed: ${errorData['error'] ?? 'Unknown error'}');
      }
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
        '${AppConfig.baseUrl}/api/passenger/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
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
              'Password change failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Password change failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Change password failed: $e');
    }
  }

  Future<User> getProfile() async {
    try {
      final response = await _apiClient.get(
        '${AppConfig.baseUrl}/api/passenger/profile',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true && responseData['user'] != null) {
          final userData = responseData['user'];

          // Create user from backend response
          final user = User(
            id: userData['id'],
            username: userData['username'],
            email: userData['email'],
            phoneNumber: userData['phone_number'],
            passengerUid: userData['passenger_uid'],
            profilePicture: userData['profile_picture'],
          );

          return user;
        } else {
          throw Exception(
              'Get profile failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Get profile failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Get profile failed: $e');
    }
  }
}
