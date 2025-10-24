import 'package:dio/dio.dart';
import '../../../shared/data/api_client.dart';
import '../../../core/config/app_config.dart';

class SettingsRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getSettings() async {
    try {
      // First try to get from local storage
      final localSettings = await _getLocalSettings();
      if (localSettings.isNotEmpty) {
        return localSettings;
      }

      // If no local settings, try to get from server
      final response = await _apiClient.get(
        '${AppConfig.baseUrl}/api/passenger/settings',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true &&
            responseData['settings'] != null) {
          final settings = responseData['settings'] as Map<String, dynamic>;
          await _saveLocalSettings(settings);
          return settings;
        } else {
          throw Exception(
              'Get settings failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Get settings failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // If server fails, return default settings
      return _getDefaultSettings();
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      // Update local storage immediately
      await _saveLocalSettings(settings);

      // Try to update server
      final response = await _apiClient.put(
        '${AppConfig.baseUrl}/api/passenger/settings',
        data: settings,
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
              'Update failed: ${responseData['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            'Update failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Settings are still saved locally, so this is not a critical error
      print('Settings update failed: $e');
    }
  }

  Future<Map<String, dynamic>> _getLocalSettings() async {
    try {
      // This would be implemented with SharedPreferences
      // For now, return empty map
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveLocalSettings(Map<String, dynamic> settings) async {
    try {
      // This would be implemented with SharedPreferences
      // For now, do nothing
    } catch (e) {
      print('Failed to save local settings: $e');
    }
  }

  Map<String, dynamic> _getDefaultSettings() {
    return {
      'push_notifications': true,
      'email_notifications': true,
      'sms_notifications': false,
      'language': 'English',
      'theme': 'System',
      'default_vehicle_type': 'Bajaj',
    };
  }
}
