import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../../shared/domain/models/saved_place.dart';
import '../../../../features/profile/data/saved_places_repository.dart';

import '../../../auth/presentation/screens/login_screen.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../support/presentation/screens/support_center_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

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

  // Stats
  int _totalTrips = 0;
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
                hintText: 'Enter full address',
              ),
              onChanged: (value) => _newPlaceAddress = value,
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
              if (_newPlaceName.isNotEmpty && _newPlaceAddress.isNotEmpty) {
                // For now, add locally; backend add can be wired with real coords
                setState(() {
                  _savedPlaces.add(SavedPlace(
                    label: _newPlaceName,
                    address: _newPlaceAddress,
                    latitude: 0.0,
                    longitude: 0.0,
                  ));
                });

                Navigator.pop(context);

                _newPlaceName = '';

                _newPlaceAddress = '';
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
                    onPressed: () {
                      Navigator.pop(context);

                      // TODO: Open map to select location

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Map selection coming soon')),
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Set on Map'),
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
      backgroundColor: AppColors.backgroundGray,
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
                                  backgroundImage: _profilePicture !=
                                          'assets/images/default_avatar.png'
                                      ? NetworkImage(_profilePicture)
                                      : null,
                                  child: _profilePicture ==
                                          'assets/images/default_avatar.png'
                                      ? Text(
                                          _userName.isNotEmpty
                                              ? _userName[0]
                                              : 'U',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                        )
                                      : null,
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
                      color: Colors.white,
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
                      color: Colors.white,
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
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
                                icon: Icons.location_on,
                                title: 'Addresses',
                                color: AppColors.secondaryGreen,
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.support_agent,
                                title: 'Support',
                                color: AppColors.warning,
                                onTap: () => _showContactSupport(),
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
                      color: Colors.white,
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
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update your profile details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
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
                      color: Colors.white,
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

                  // Settings and Support - Simplified to buttons
                  Row(
                    children: [
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
                          icon: Icons.help_outline,
                          title: 'Support',
                          color: AppColors.secondaryGreen,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SupportCenterScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

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
    final Color iconColor = AppColors.primaryBlue;

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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
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
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.add, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add New Place',
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

  Widget _buildSettingItem(IconData icon, String title, String subtitle,
      {Color? iconColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ??
          () {
            // TODO: Navigate to setting screen
          },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: iconColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
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

  void _toggleDarkMode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dark Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode, color: AppColors.warning),
              title: const Text('Light Mode'),
              subtitle: const Text('Default theme'),
              trailing: Radio<bool>(
                value: false,

                groupValue: false, // TODO: Get from theme provider

                onChanged: (value) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Light mode selected')),
                  );
                },
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.dark_mode, color: AppColors.primaryBlue),
              title: const Text('Dark Mode'),
              subtitle: const Text('Dark theme'),
              trailing: Radio<bool>(
                value: true,

                groupValue: false, // TODO: Get from theme provider

                onChanged: (value) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dark mode selected')),
                  );
                },
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.brightness_auto, color: AppColors.success),
              title: const Text('System Default'),
              subtitle: const Text('Follow system setting'),
              trailing: Radio<bool?>(
                value: null,

                groupValue: null, // TODO: Get from theme provider

                onChanged: (value) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('System default selected')),
                  );
                },
              ),
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

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & Security'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.email, color: AppColors.primaryBlue),
                title: Text('Email Verification'),
                subtitle: Text('Required for sensitive changes'),
                trailing: Switch(
                  value: true, // Always enabled for security

                  onChanged: null, // Cannot be disabled
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.location_on, color: AppColors.primaryBlue),
                title: const Text('Location Sharing'),
                subtitle: const Text('Share location during rides'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: Implement location sharing toggle
                  },
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.visibility, color: AppColors.primaryBlue),
                title: const Text('Profile Visibility'),
                subtitle: const Text('Show profile to drivers'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: Implement profile visibility toggle
                  },
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.security, color: AppColors.primaryBlue),
                title: const Text('Two-Factor Authentication'),
                subtitle: const Text('Add extra security'),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {
                    // TODO: Implement 2FA toggle

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('2FA feature coming soon')),
                    );
                  },
                ),
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
              onTap: () {
                Navigator.pop(context);

                // TODO: Implement camera

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);

                // TODO: Implement gallery

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gallery feature coming soon')),
                );
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

  void _showFAQ() {
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

  void _showReportIssue() {
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

  void _showLostItemReport() {
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

  void _showContactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.primaryBlue),
              title: const Text('Call Support'),
              subtitle: const Text('+251 911 234 567'),
              onTap: () {
                Navigator.pop(context);

                // TODO: Implement phone call
              },
            ),
            ListTile(
              leading: const Icon(Icons.email, color: AppColors.primaryBlue),
              title: const Text('Email Support'),
              subtitle: const Text('selamawiride@gmail.com'),
              onTap: () {
                Navigator.pop(context);

                // TODO: Implement email
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: AppColors.primaryBlue),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 24/7'),
              onTap: () {
                Navigator.pop(context);

                // TODO: Implement live chat
              },
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
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryBlue,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
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
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
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
