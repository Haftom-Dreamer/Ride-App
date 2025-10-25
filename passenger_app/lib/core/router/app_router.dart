import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/ride/presentation/screens/ride_request_screen.dart';
import '../../features/ride/presentation/screens/ride_history_screen.dart';
import '../../features/ride/presentation/screens/ride_tracking_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/saved_places_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class AppRouter {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/';
  static const String profile = '/profile';
  static const String savedPlaces = '/saved-places';
  static const String rideHistory = '/ride-history';
  static const String settings = '/settings';
  static const String rideTracking = '/ride-tracking';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case signup:
        return MaterialPageRoute(
          builder: (_) => const SignupScreen(),
          settings: settings,
        );

      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );

      case home:
        return MaterialPageRoute(
          builder: (_) => const RideRequestScreen(),
          settings: settings,
        );

      case profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      case savedPlaces:
        return MaterialPageRoute(
          builder: (_) => const SavedPlacesScreen(),
          settings: settings,
        );

      case rideHistory:
        return MaterialPageRoute(
          builder: (_) => const RideHistoryScreen(),
          settings: settings,
        );

      case AppRouter.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );

      case rideTracking:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text('Invalid route arguments'),
              ),
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => RideTrackingScreen(
            pickupAddress: args['pickupAddress'] as String,
            destinationAddress: args['destinationAddress'] as String,
            pickupLat: args['pickupLat'] as double,
            pickupLng: args['pickupLng'] as double,
            destLat: args['destLat'] as double,
            destLng: args['destLng'] as double,
            estimatedFare: args['estimatedFare'] as double,
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
          settings: settings,
        );
    }
  }
}

class AuthGuard extends ConsumerWidget {
  final Widget child;
  final String redirectTo;

  const AuthGuard({
    super.key,
    required this.child,
    this.redirectTo = AppRouter.login,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show loading while checking auth status
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Redirect to login if not authenticated
    if (!authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(redirectTo);
      });
      return const Scaffold(
        body: Center(
          child: Text('Redirecting to login...'),
        ),
      );
    }

    return child;
  }
}

class GuestGuard extends ConsumerWidget {
  final Widget child;
  final String redirectTo;

  const GuestGuard({
    super.key,
    required this.child,
    this.redirectTo = AppRouter.home,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show loading while checking auth status
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Redirect to home if already authenticated
    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(redirectTo);
      });
      return const Scaffold(
        body: Center(
          child: Text('Redirecting to home...'),
        ),
      );
    }

    return child;
  }
}

// Route extensions for easier navigation
extension AppRouterExtensions on BuildContext {
  void pushNamed(String routeName, {Object? arguments}) {
    Navigator.of(this).pushNamed(routeName, arguments: arguments);
  }

  void pushReplacementNamed(String routeName, {Object? arguments}) {
    Navigator.of(this).pushReplacementNamed(routeName, arguments: arguments);
  }

  void pushNamedAndRemoveUntil(String routeName, {Object? arguments}) {
    Navigator.of(this).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  void pop() {
    Navigator.of(this).pop();
  }

  void popUntil(String routeName) {
    Navigator.of(this).popUntil(ModalRoute.withName(routeName));
  }
}
