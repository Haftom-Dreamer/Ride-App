import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../../shared/domain/models/saved_place.dart';
import '../../../../features/profile/data/saved_places_repository.dart';

import '../../../auth/presentation/screens/login_screen.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

// import '../../../support/presentation/screens/support_center_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../support/presentation/screens/support_screen.dart';
import '../../../profile/data/profile_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'map_selection_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/config/app_config.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/geocoding_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Real user data - will be loaded from API

  String _userName = 'Loading...';

  String _userPhone = 'Loading...';

  String _userEmail = 'Loading...';

  String _profilePicture = 'assets/images/default_avatar.png';

  List<SavedPlace> _savedPlaces = [];
  final SavedPlacesRepository _savedPlacesRepository = SavedPlacesRepository();

  String _newPlaceName = '';

  String _newPlaceAddress = '';
  final ProfileRepository _profileRepository = ProfileRepository();
  final ImagePicker _imagePicker = ImagePicker();

  // Stats
  final int _totalTrips = 0;
  DateTime? _memberSince;

  @override
  void initState() {
    super.initState();

    _loadUserData();
    _fetchSavedPlaces();
  }

  Future<void> _loadUserData() async {
    // Load actual user data from auth provider

    final authState = ref.read(authProvider);

    final user = authState.user;

    if (user != null) {
      setState(() {
        _userName = user.username;
        _userPhone = user.phoneNumber;
        _userEmail = user.email;
        _profilePicture =
            user.profilePicture ?? 'assets/images/default_avatar.png';
        _memberSince = user.createdAt;
      });
    } else {
      // Fallback if no user data

      setState(() {
        _userName = 'Guest User';

        _userPhone = 'No phone number';

        _userEmail = 'No email provided';

        _savedPlaces = [];
      });
    }
  }

  Future<void> _fetchSavedPlaces() async {
    try {
      final places = await _savedPlacesRepository.getSavedPlaces();
      if (mounted) {
        setState(() {
          _savedPlaces = places;
        });
      }
    } catch (_) {
      // Silently ignore for now; UI shows empty list
    }
  }

  void _addSavedPlace() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Saved Place'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Place Name',
                hintText: 'e.g., Home, Work',
              ),
              onChanged: (value) => _newPlaceName = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter full address or pin on map',
              ),
              onChanged: (value) => _newPlaceAddress = value,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first

                // Open map selection screen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MapSelectionScreen(),
                  ),
                );

                if (result != null && mounted) {
                  final location = result['location'] as LatLng;
                  final address = result['address'] as String;

                  try {
                    await _savedPlacesRepository.saveOrUpdatePlace(
                      label: _newPlaceName.isNotEmpty
                          ? _newPlaceName
                          : 'New Place',
                      address: address,
                      latitude: location.latitude,
                      longitude: location.longitude,
                    );
                    await _fetchSavedPlaces();
                    _newPlaceName = '';
                    _newPlaceAddress = '';
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Place saved successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save place: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.map),
              label: const Text('Pin on Map'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_newPlaceName.isEmpty || _newPlaceAddress.isEmpty) return;
              try {
                await _savedPlacesRepository.saveOrUpdatePlace(
                  label: _newPlaceName,
                  address: _newPlaceAddress,
                  latitude: 0.0,
                  longitude: 0.0,
                );
                if (mounted) {
                  Navigator.pop(context);
                  await _fetchSavedPlaces();
                  _newPlaceName = '';
                  _newPlaceAddress = '';
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add place: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editSavedPlace(SavedPlace place) {
    final nameController = TextEditingController(text: place.label);

    final addressController = TextEditingController(text: place.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${place.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Place Name',
                hintText: 'e.g., Home, Work',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter full address',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context); // Close dialog first

                      // Open map selection screen
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapSelectionScreen(
                            placeLabel: place.label,
                            initialLocation:
                                place.latitude != 0.0 && place.longitude != 0.0
                                    ? LatLng(place.latitude, place.longitude)
                                    : null,
                          ),
                        ),
                      );

                      if (result != null && mounted) {
                        final location = result['location'] as LatLng;
                        final address = result['address'] as String;

                        // Update the place with new location
                        setState(() {
                          final index =
                              _savedPlaces.indexWhere((p) => p.id == place.id);
                          if (index != -1) {
                            _savedPlaces[index] = SavedPlace(
                              id: place.id,
                              label: nameController.text.trim().isNotEmpty
                                  ? nameController.text.trim()
                                  : place.label,
                              address: address,
                              latitude: location.latitude,
                              longitude: location.longitude,
                            );
                          }
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Location updated successfully')),
                        );
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Pin on Map'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();

              final newAddress = addressController.text.trim();

              if (newName.isNotEmpty && newAddress.isNotEmpty) {
                setState(() {
                  final index =
                      _savedPlaces.indexWhere((p) => p.id == place.id);
                  if (index != -1) {
                    _savedPlaces[index] = SavedPlace(
                      id: place.id,
                      label: newName,
                      address: newAddress,
                      latitude: place.latitude,
                      longitude: place.longitude,
                    );
                  }
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Place updated successfully')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    final nameController = TextEditingController(text: _userName);

    final phoneController = TextEditingController(text: _userPhone);

    final emailController = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Changing phone number or email will require email verification for security.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();

              final newPhone = phoneController.text.trim();

              final newEmail = emailController.text.trim();

              if (newName.isEmpty || newPhone.isEmpty || newEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );

                return;
              }

              // Check if phone or email changed

              final phoneChanged = newPhone != _userPhone;

              final emailChanged = newEmail != _userEmail;

              if (phoneChanged || emailChanged) {
                _showEmailVerificationDialog(newName, newPhone, newEmail);
              } else {
                // Only name changed, update directly

                setState(() {
                  _userName = newName;
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEmailVerificationDialog(String name, String phone, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Verification Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.email,
              size: 48,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 16),
            const Text(
              'For security reasons, we need to verify your email address before updating your phone number or email.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Verification email will be sent to: $email',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              Navigator.pop(context); // Close edit dialog too

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Verification email sent! Please check your inbox.'),
                  backgroundColor: AppColors.success,
                ),
              );

              // TODO: Implement actual email verification
            },
            child: const Text('Send Verification'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            centerTitle: false,
            title: const Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              // Remove title here to avoid overlap with header content
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryBlue, AppColors.darkBlue],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Profile Photo with status indicator
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _changeProfilePicture(),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundColor: AppColors.lightBlue,
                                  child: _buildProfileAvatarChild(),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Name
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Phone
                        Text(
                          _userPhone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Quick Stats
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickStat(
                            'Trips', '$_totalTrips', Icons.directions_car),
                        _buildQuickStat(
                          'Member',
                          _memberSince == null
                              ? '—'
                              : '${_memberSince!.year}-${_memberSince!.month.toString().padLeft(2, '0')}',
                          Icons.calendar_today,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.payment,
                                title: 'Payment',
                                color: AppColors.primaryBlue,
                                onTap: () => _showPaymentOptions(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.settings,
                                title: 'Settings',
                                color: AppColors.primaryBlue,
                                onTap: () => _showSettingsDialog(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.support_agent,
                                title: 'Support',
                                color: AppColors.warning,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SupportScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // User Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person,
                                color: AppColors.primaryBlue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Personal Information',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update your profile details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _editProfile,
                              icon: const Icon(Icons.edit,
                                  color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildInfoRow(Icons.phone, 'Phone', _userPhone),
                        _buildInfoRow(Icons.email, 'Email', _userEmail),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Member Since',
                          _memberSince == null
                              ? '—'
                              : '${_memberSince!.year}-${_memberSince!.month.toString().padLeft(2, '0')}-${_memberSince!.day.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Saved Places Section

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Saved Places',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Home/Work placeholders
                        if (!_savedPlaces
                            .any((p) => p.label.toLowerCase() == 'home'))
                          _buildSavedPlacePlaceholder('Home'),
                        if (!_savedPlaces
                            .any((p) => p.label.toLowerCase() == 'work'))
                          _buildSavedPlacePlaceholder('Work'),
                        ..._savedPlaces
                            .map((place) => _buildSavedPlaceItem(place)),
                        _buildAddPlaceItem(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Methods Section

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Payment Methods',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildPaymentMethodItem(
                          icon: Icons.money,
                          title: 'Cash',
                          subtitle: 'Default payment method',
                          isDefault: true,
                          onTap: () => _showPaymentOptions(),
                        ),
                        _buildDivider(),
                        _buildAddPaymentItem(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const SizedBox(height: 32),

                  // Logout Button

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showLogoutDialog();
                      },
                      icon: const Icon(Icons.logout, color: AppColors.error),
                      label: const Text('Logout',
                          style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App Version

                  const Center(
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32), // Extra bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlaceItem(SavedPlace place) {
    const IconData icon = Icons.place;
    const Color iconColor = AppColors.primaryBlue;

    return InkWell(
      onTap: () => _editSavedPlace(place),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPlaceItem() {
    return InkWell(
      onTap: _addSavedPlace,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add,
                  color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Add New Place',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlacePlaceholder(String label) {
    return InkWell(
      onTap: () => _addSavedPlaceWithLabel(label),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_location_alt,
                  color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set $label address',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enter manually or pin on the map',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _addSavedPlaceWithLabel(String label) {
    _newPlaceName = label;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '$label Name',
                hintText: label,
              ),
              controller: TextEditingController(text: label),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter full address or pin on map',
              ),
              onChanged: (value) => _newPlaceAddress = value,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first

                // Open map selection screen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapSelectionScreen(placeLabel: label),
                  ),
                );

                if (result != null && mounted) {
                  final location = result['location'] as LatLng;
                  final address = result['address'] as String;

                  try {
                    await _savedPlacesRepository.saveOrUpdatePlace(
                      label: label,
                      address: address,
                      latitude: location.latitude,
                      longitude: location.longitude,
                    );
                    await _fetchSavedPlaces();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$label saved')),
                      );
                    }
                    _newPlaceAddress = '';
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save place: $e')),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.map),
              label: const Text('Pin on Map'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_newPlaceAddress.isNotEmpty) {
                try {
                  final coords = await GeocodingService.addressToCoordinates(
                      _newPlaceAddress);
                  if (coords == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Could not locate that address. Please pin on map.')),
                      );
                    }
                    return;
                  }
                  await _savedPlacesRepository.saveOrUpdatePlace(
                    label: label,
                    address: _newPlaceAddress,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    await _fetchSavedPlaces();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$label saved')),
                    );
                  }
                  _newPlaceAddress = '';
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save place: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDefault,
    VoidCallback? onTap,
    bool isComingSoon = false,
  }) {
    return InkWell(
      onTap: isComingSoon ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isComingSoon
                    ? AppColors.gray100
                    : AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color:
                      isComingSoon ? AppColors.gray400 : AppColors.primaryBlue,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isComingSoon
                              ? AppColors.gray400
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                      if (isComingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Coming Soon',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isComingSoon
                          ? AppColors.gray400
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isComingSoon ? AppColors.gray300 : AppColors.gray400),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPaymentItem() {
    return InkWell(
      onTap: () {
        // TODO: Add payment method
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.add, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await _performLogout();
            },
            child:
                const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _changeProfilePicture() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                // Request camera permission
                final camStatus = await Permission.camera.request();
                if (!camStatus.isGranted) return;
                final XFile? photo =
                    await _imagePicker.pickImage(source: ImageSource.camera);
                if (photo != null) {
                  await _uploadProfileImage(File(photo.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                // Request photos/storage permission
                var granted = true;
                if (await Permission.photos.isDenied &&
                    await Permission.storage.isDenied) {
                  final p1 = await Permission.photos.request();
                  final p2 = await Permission.storage.request();
                  granted = p1.isGranted || p2.isGranted;
                }
                if (!granted) return;
                final XFile? image =
                    await _imagePicker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  await _uploadProfileImage(File(image.path));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadProfileImage(File file) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final newUrl = await _profileRepository.uploadProfilePicture(file);

      // Update local state; auth provider refresh will pick it up if needed

      if (mounted) Navigator.pop(context);
      if (mounted) {
        setState(() {
          _profilePicture = newUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Widget _buildProfileAvatarChild() {
    // Default avatar with initial
    if (_profilePicture.isEmpty ||
        _profilePicture == 'assets/images/default_avatar.png') {
      return Text(
        _userName.isNotEmpty ? _userName[0] : 'U',
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryBlue,
        ),
      );
    }

    String url = _profilePicture;
    if (!url.startsWith('http')) {
      if (url.startsWith('/')) {
        url = '${AppConfig.baseUrl}$url';
      } else {
        url = '${AppConfig.baseUrl}/$url';
      }
    }

    if (url.toLowerCase().endsWith('.svg')) {
      return ClipOval(
        child: SvgPicture.network(
          url,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        url,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Text(
            _userName.isNotEmpty ? _userName[0] : 'U',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          );
        },
      ),
    );
  }

  /* Removed unused _showFAQ */
  /* Removed unused _buildFAQItem */
  /* Removed unused _showReportIssue */
  /* Removed unused _showLostItemReport */
  /* Keeping _changeProfilePicture and others that are used */

  /* void _showFAQ() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFAQItem(
                'How do I request a ride?',
                'Tap "Where to?" on the home screen, select your destination, choose a vehicle type, and tap "Request Ride".',
              ),
              _buildFAQItem(
                'How much does a ride cost?',
                'Prices vary by vehicle type: Bajaj (ETB 30-50), Car (ETB 50-80), SUV (ETB 80-120). Exact fare is calculated based on distance.',
              ),
              _buildFAQItem(
                'How do I pay for my ride?',
                'Currently, we only accept cash payments. Digital payment options like Telebirr are coming soon.',
              ),
              _buildFAQItem(
                'What if I need to cancel my ride?',
                'You can cancel your ride before the driver arrives. Tap "Cancel Request" in the app.',
              ),
              _buildFAQItem(
                'How do I contact my driver?',
                'Once your driver is assigned, you can call them directly using the "Call Driver" button.',
              ),
              _buildFAQItem(
                'Is the service available 24/7?',
                'Yes, our ride service is available 24 hours a day, 7 days a week in Mekelle and Adigrat.',
              ),
              _buildFAQItem(
                'What if I lost an item in the vehicle?',
                'Contact our support team immediately with your ride details. We will help you connect with the driver.',
              ),
              _buildFAQItem(
                'How do I report a problem?',
                'Use the "Report Issue" option in the app or contact support directly. We take all reports seriously.',
              ),
              _buildFAQItem(
                'Can I schedule a ride in advance?',
                'Currently, we only support on-demand rides. Scheduled rides will be available soon.',
              ),
              _buildFAQItem(
                'What if my driver doesn\'t show up?',
                'Contact support immediately. We will find you another driver or provide a refund if appropriate.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Removed unused _showReportIssue
    final issueController = TextEditingController();

    String selectedCategory = 'General';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'General', child: Text('General')),
                  DropdownMenuItem(
                      value: 'Driver', child: Text('Driver Issue')),
                  DropdownMenuItem(
                      value: 'Payment', child: Text('Payment Issue')),
                  DropdownMenuItem(value: 'App', child: Text('App Problem')),
                  DropdownMenuItem(
                      value: 'Safety', child: Text('Safety Concern')),
                ],
                onChanged: (value) => selectedCategory = value!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: issueController,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                  hintText: 'Please provide details about the problem...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (issueController.text.trim().isNotEmpty) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Issue reported successfully. We will investigate.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  // Removed unused _showLostItemReport
    final itemController = TextEditingController();

    final descriptionController = TextEditingController();

    String selectedRide = 'Recent Ride';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Lost Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Phone, Wallet, Keys',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the item in detail...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRide,
                decoration: const InputDecoration(
                  labelText: 'Which ride?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Recent Ride', child: Text('Recent Ride')),
                  DropdownMenuItem(
                      value: 'Yesterday', child: Text('Yesterday')),
                  DropdownMenuItem(
                      value: 'This Week', child: Text('This Week')),
                ],
                onChanged: (value) => selectedRide = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (itemController.text.trim().isNotEmpty) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Lost item reported. We will contact the driver.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Report Item'),
          ),
        ],
      ),
    );
  }
  */

  // Support handled via SupportScreen navigation

  void _showPaymentOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Methods'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money, color: AppColors.success),
              title: const Text('Cash'),
              subtitle: const Text('Pay with cash to driver'),
              trailing:
                  const Icon(Icons.check_circle, color: AppColors.success),
              onTap: () => Navigator.pop(context),
            ),
            const ListTile(
              leading: Icon(Icons.phone_android, color: AppColors.gray400),
              title: Text('Telebirr'),
              subtitle: Text('Coming soon'),
              enabled: false,
              onTap: null,
            ),
            const ListTile(
              leading: Icon(Icons.credit_card, color: AppColors.gray400),
              title: Text('Bank Card'),
              subtitle: Text('Coming soon'),
              enabled: false,
              onTap: null,
            ),
            const ListTile(
              leading:
                  Icon(Icons.account_balance_wallet, color: AppColors.gray400),
              title: Text('Mobile Wallet'),
              subtitle: Text('Coming soon'),
              enabled: false,
              onTap: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Use the auth provider to logout properly

      final authNotifier = ref.read(authProvider.notifier);

      await authNotifier.logout();

      // Close loading dialog

      if (mounted) Navigator.pop(context);

      // Navigate to login screen and clear navigation stack

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,

          MaterialPageRoute(builder: (context) => const LoginScreen()),

          (route) => false, // Remove all previous routes
        );
      }

      // Show success message

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open

      if (mounted) Navigator.pop(context);

      // Show error message

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
