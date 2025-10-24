import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/password_reset_repository.dart';

// Password Reset state
class PasswordResetState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const PasswordResetState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  PasswordResetState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return PasswordResetState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

// Password Reset notifier
class PasswordResetNotifier extends StateNotifier<PasswordResetState> {
  final PasswordResetRepository _passwordResetRepository;

  PasswordResetNotifier(this._passwordResetRepository)
      : super(const PasswordResetState());

  Future<void> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      await _passwordResetRepository.requestPasswordReset(email);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Reset code sent to your email',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        successMessage: null,
      );
    }
  }

  Future<void> verifyPasswordReset({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      await _passwordResetRepository.verifyPasswordReset(
        email: email,
        resetCode: resetCode,
        newPassword: newPassword,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage:
            'Password reset successfully! You can now log in with your new password.',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        successMessage: null,
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }
}

// Providers
final passwordResetRepositoryProvider =
    Provider<PasswordResetRepository>((ref) {
  return PasswordResetRepository();
});

final passwordResetProvider =
    StateNotifierProvider<PasswordResetNotifier, PasswordResetState>((ref) {
  final passwordResetRepository = ref.watch(passwordResetRepositoryProvider);
  return PasswordResetNotifier(passwordResetRepository);
});
