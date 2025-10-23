import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../shared/domain/models/user.dart';
import '../../../core/config/app_config.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        AppConfig.loginEndpoint,
        data: {
          'phone_number': email, // Backend expects phone_number, not email
          'password': password,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          validateStatus: (status) =>
              status! < 400, // Accept 200, 201, 302 as success
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 302) {
        // For now, create a mock user since the backend doesn't return JSON
        final user = User(
          id: 1,
          username: 'User',
          email: email,
          phoneNumber: email,
        );

        // Set a mock token
        await _apiClient.setAuthToken(
            'mock_token_${DateTime.now().millisecondsSinceEpoch}');

        return user;
      } else {
        throw Exception('Login failed: ${response.data['error']}');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<User> signup({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
    String? verificationCode,
  }) async {
    try {
      // If no verification code, this is the initial signup request
      if (verificationCode == null) {
        final response = await _apiClient.post(
          AppConfig.signupEndpoint,
          data: {
            'username': username,
            'email': email,
            'phone_number': phoneNumber,
            'password': password,
          },
          options: Options(
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            validateStatus: (status) => status! < 400,
          ),
        );

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 302) {
          print('✅ Initial signup successful! Status: ${response.statusCode}');
          print('✅ Response data: ${response.data}');

          // Return a mock user to trigger verification step
          final user = User(
            id: 1,
            username: username,
            email: email,
            phoneNumber: phoneNumber,
          );
          return user;
        } else {
          print('Initial signup failed with status: ${response.statusCode}');
          print('Response data: ${response.data}');
          throw Exception('Signup failed: ${response.data}');
        }
      } else {
        // This is the verification step
        final response = await _apiClient.post(
          AppConfig.signupEndpoint,
          data: {
            'username': username,
            'email': email,
            'phone_number': phoneNumber,
            'password': password,
            'verification_code': verificationCode,
          },
          options: Options(
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            validateStatus: (status) => status! < 400,
          ),
        );

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 302) {
          print(
              '✅ Email verification successful! Status: ${response.statusCode}');
          print('✅ Response data: ${response.data}');

          // Create final user and set token
          final user = User(
            id: 1,
            username: username,
            email: email,
            phoneNumber: phoneNumber,
          );

          await _apiClient.setAuthToken(
              'mock_token_${DateTime.now().millisecondsSinceEpoch}');

          return user;
        } else {
          print(
              'Email verification failed with status: ${response.statusCode}');
          print('Response data: ${response.data}');
          throw Exception('Email verification failed: ${response.data}');
        }
      }
    } catch (e) {
      throw Exception('Signup failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(AppConfig.logoutEndpoint);
    } catch (e) {
      // Continue with logout even if API call fails
      print('Logout API call failed: $e');
    } finally {
      // Clear local token
      await _apiClient.clearAuthToken();
    }
  }

  Future<User?> getCurrentUser() async {
    // For now, return null since we don't have a profile endpoint
    // In a real app, you'd store user data locally or call a profile endpoint
    return null;
  }

  Future<bool> isLoggedIn() async {
    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
    }
  }
}
