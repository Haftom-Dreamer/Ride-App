import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../core/config/app_config.dart';

class PasswordResetRepository {
  final ApiClient _apiClient = ApiClient();

  Future<void> requestPasswordReset(String email) async {
    try {
      final response = await _apiClient.post(
        '${AppConfig.baseUrl}/api/passenger/password-reset/request',
        data: {
          'email': email,
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
              'Request failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Request failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Request password reset failed: $e');
    }
  }

  Future<void> verifyPasswordReset({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConfig.baseUrl}/api/passenger/password-reset/verify',
        data: {
          'email': email,
          'reset_code': resetCode,
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
              'Verification failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Verification failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Verify password reset failed: $e');
    }
  }
}
