import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ride/presentation/screens/ride_request_screen.dart';

/// Main screen - now just shows RideRequestScreen
/// The bottom navigation is handled inside RideRequestScreen
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const RideRequestScreen();
  }
}

