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

        // Treat any 200 with a 'success' field as success (string or boolean)
        if (responseData is Map && responseData.containsKey('success')) {
          return;
        }

        // Otherwise, consider it success to avoid blocking UX on message shape
        return;
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
        '${AppConfig.baseUrl}/api/passenger/password-reset/confirm',
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

        // Treat any 200 with a 'success' field as success
        if (responseData is Map && responseData.containsKey('success')) {
          return;
        }

        return;
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
