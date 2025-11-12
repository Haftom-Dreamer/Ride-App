import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ride/presentation/screens/ride_request_screen.dart';
import '../../../ride/presentation/screens/ride_history_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

/// Main screen with bottom navigation for passenger app
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const RideRequestScreen(),
    const RideHistoryScreen(),
    const ProfileScreen(),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      // Bottom navigation removed - using the 4-button nav from RideRequestScreen instead
    );
  }
}

