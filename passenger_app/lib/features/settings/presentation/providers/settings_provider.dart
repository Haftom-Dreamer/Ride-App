import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/settings_repository.dart';

// Settings state
class SettingsState {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final String language;
  final String theme;
  final String defaultVehicleType;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.language = 'English',
    this.theme = 'System',
    this.defaultVehicleType = 'Bajaj',
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    String? language,
    String? theme,
    String? defaultVehicleType,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      defaultVehicleType: defaultVehicleType ?? this.defaultVehicleType,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Settings notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _settingsRepository;

  SettingsNotifier(this._settingsRepository) : super(const SettingsState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final settings = await _settingsRepository.getSettings();
      state = state.copyWith(
        pushNotifications: settings['push_notifications'] ?? true,
        emailNotifications: settings['email_notifications'] ?? true,
        smsNotifications: settings['sms_notifications'] ?? false,
        language: settings['language'] ?? 'English',
        theme: settings['theme'] ?? 'System',
        defaultVehicleType: settings['default_vehicle_type'] ?? 'Bajaj',
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updatePushNotifications(bool value) async {
    state = state.copyWith(pushNotifications: value);
    await _settingsRepository.updateSettings({'push_notifications': value});
  }

  Future<void> updateEmailNotifications(bool value) async {
    state = state.copyWith(emailNotifications: value);
    await _settingsRepository.updateSettings({'email_notifications': value});
  }

  Future<void> updateSmsNotifications(bool value) async {
    state = state.copyWith(smsNotifications: value);
    await _settingsRepository.updateSettings({'sms_notifications': value});
  }

  Future<void> updateLanguage(String language) async {
    state = state.copyWith(language: language);
    await _settingsRepository.updateSettings({'language': language});
  }

  Future<void> updateTheme(String theme) async {
    state = state.copyWith(theme: theme);
    await _settingsRepository.updateSettings({'theme': theme});
  }

  Future<void> updateDefaultVehicleType(String vehicleType) async {
    state = state.copyWith(defaultVehicleType: vehicleType);
    await _settingsRepository
        .updateSettings({'default_vehicle_type': vehicleType});
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(settingsRepository);
});
