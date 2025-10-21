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
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'] as Map<String, dynamic>;
        final token = response.data['token'] as String;
        
        // Save token
        await _apiClient.setAuthToken(token);
        
        return User.fromJson(userData);
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
  }) async {
    try {
      final response = await _apiClient.post(
        AppConfig.signupEndpoint,
        data: {
          'username': username,
          'email': email,
          'phone_number': phoneNumber,
          'password': password,
        },
      );

      if (response.statusCode == 201) {
        final userData = response.data['user'] as Map<String, dynamic>;
        final token = response.data['token'] as String;
        
        // Save token
        await _apiClient.setAuthToken(token);
        
        return User.fromJson(userData);
      } else {
        throw Exception('Signup failed: ${response.data['error']}');
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
    try {
      final response = await _apiClient.get('/passenger/profile');
      
      if (response.statusCode == 200) {
        return User.fromJson(response.data['user'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Failed to get current user: $e');
      return null;
    }
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
