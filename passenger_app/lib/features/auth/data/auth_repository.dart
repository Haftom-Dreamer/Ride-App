import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../shared/domain/models/user.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/storage_service.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<User> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        AppConfig.loginEndpoint,
        data: {
          'phone_number': phoneNumber,
          'password': password,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          validateStatus: (status) => status! < 400,
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

          // Set auth token and save user data
          final token = 'auth_token_${DateTime.now().millisecondsSinceEpoch}';
          await _apiClient.setAuthToken(token);
          await StorageService.saveToken(token);
          await StorageService.saveUser(user);
          await _apiClient.setUserId(user.id);

          return user;
        } else {
          throw Exception(
              'Login failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Login failed: ${errorData['error'] ?? 'Invalid credentials'}');
      }
    } catch (e) {
      // Prefer mapped AuthException messages from ApiClient
      if (e is AuthException) {
        throw Exception(e.message);
      }
      // Handle DioError specifically for better error messages
      if (e is DioException) {
        if (e.response != null) {
          final statusCode = e.response!.statusCode;
          final responseData = e.response!.data;

          if (statusCode == 401) {
            throw Exception('Invalid phone number or password');
          } else if (statusCode == 400) {
            if (responseData is Map && responseData['error'] != null) {
              throw Exception(responseData['error']);
            }
            throw Exception('Please check your input and try again');
          } else {
            throw Exception('Login failed. Please try again.');
          }
        } else {
          throw Exception('Network error. Please check your connection.');
        }
      }
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
      // Call logout API endpoint
      await _apiClient.post(
        AppConfig.logoutEndpoint,
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );
    } catch (e) {
      // Even if API call fails, clear local data
      print('Logout API call failed: $e');
    } finally {
      // Always clear local data
      await _apiClient.clearAuthToken();
      await StorageService.clearAll();
    }
  }

  Future<User?> getCurrentUser() async {
    return await StorageService.getUser();
  }

  Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      final response = await _apiClient.post(
        '/auth/passenger/password-reset/request',
        data: {'email': email},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 400,
        ),
      );

      if (response.statusCode == 200) {
        // Success - password reset email sent
        return;
      } else {
        final errorData = response.data;
        throw Exception(
            'Password reset failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Handle DioError specifically for better error messages
      if (e is DioException) {
        if (e.response != null) {
          final statusCode = e.response!.statusCode;
          final responseData = e.response!.data;

          if (statusCode == 400) {
            if (responseData is Map && responseData['error'] != null) {
              throw Exception(responseData['error']);
            }
            throw Exception('Please check your email address and try again');
          } else {
            throw Exception('Password reset failed. Please try again.');
          }
        } else {
          throw Exception('Network error. Please check your connection.');
        }
      }
      throw Exception('Password reset failed: $e');
    }
  }
}
