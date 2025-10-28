import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/tigray_locations.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
  String _newPlaceName = '';
  String _newPlaceAddress = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        _profilePicture = user.profilePicture ?? 'assets/images/default_avatar.png';
        _savedPlaces = [
          SavedPlace(
            id: '1',
            name: 'Home',
            address: 'Ayder, Mekelle',
            coordinates: const LatLng(13.4967, 39.4753),
            icon: 'home',
          ),
          SavedPlace(
            id: '2',
            name: 'Work',
            address: 'Mekelle University',
            coordinates: const LatLng(13.488, 39.482),
            icon: 'work',
          ),
        ];
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
                setState(() {
                  _savedPlaces.add(SavedPlace(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _newPlaceName,
                    address: _newPlaceAddress,
                    coordinates: const LatLng(13.4967, 39.4753), // Default coordinates
                    icon: 'location_on',
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
    final nameController = TextEditingController(text: place.name);
    final addressController = TextEditingController(text: place.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${place.name}'),
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
                        const SnackBar(content: Text('Map selection coming soon')),
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
                  final index = _savedPlaces.indexWhere((p) => p.id == place.id);
                  if (index != -1) {
                    _savedPlaces[index] = SavedPlace(
                      id: place.id,
                      name: newName,
                      address: newAddress,
                      coordinates: place.coordinates,
                      icon: place.icon,
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
                  content: Text('Verification email sent! Please check your inbox.'),
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
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // User Info Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Profile Photo
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _changeProfilePicture(),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.lightBlue,
                        backgroundImage: _profilePicture != 'assets/images/default_avatar.png' 
                            ? NetworkImage(_profilePicture) 
                            : null,
                        child: _profilePicture == 'assets/images/default_avatar.png'
                            ? Text(
                                _userName.isNotEmpty ? _userName[0] : 'U',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _changeProfilePicture(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      _userPhone,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      _userEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      _userEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
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
                ..._savedPlaces.map((place) => _buildSavedPlaceItem(place)),
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

          // Settings Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Settings',
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
                _buildSettingItem(
                  Icons.notifications_outlined,
                  'Notifications',
                  'Manage notification preferences',
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.lock_outline,
                  'Privacy & Security',
                  'Control your privacy and security settings',
                  onTap: () => _showPrivacySettings(),
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.language,
                  'Language',
                  'English',
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.dark_mode,
                  'Dark Mode',
                  'Switch between light and dark theme',
                  onTap: () => _toggleDarkMode(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Support Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Support',
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
                _buildSettingItem(
                  Icons.help_outline,
                  'FAQ',
                  'Frequently asked questions',
                  onTap: () => _showFAQ(),
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.support_agent,
                  'Contact Support',
                  'Chat with our support team',
                  onTap: () => _showContactSupport(),
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.report_problem,
                  'Report Issue',
                  'Report a problem with your ride',
                  onTap: () => _showReportIssue(),
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.search_off,
                  'Lost Item',
                  'Report a lost item',
                  onTap: () => _showLostItemReport(),
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.emergency,
                  'Emergency SOS',
                  'Setup emergency contacts',
                  iconColor: AppColors.error,
                ),
              ],
            ),
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
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSavedPlaceItem(SavedPlace place) {
    IconData icon;
    Color iconColor;

    if (place.icon == 'home') {
      icon = Icons.home;
      iconColor = AppColors.success;
    } else if (place.icon == 'work') {
      icon = Icons.work;
      iconColor = AppColors.primaryBlue;
    } else {
      icon = Icons.place;
      iconColor = AppColors.warning;
    }

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
                    place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.gray400),
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
              child: Icon(
                icon, 
                color: isComingSoon ? AppColors.gray400 : AppColors.primaryBlue, 
                size: 20
              ),
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
                          color: isComingSoon ? AppColors.gray400 : AppColors.textPrimary,
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
                      color: isComingSoon ? AppColors.gray400 : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right, 
              color: isComingSoon ? AppColors.gray300 : AppColors.gray400
            ),
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
      onTap: onTap ?? () {
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
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.gray400),
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
              leading: const Icon(Icons.dark_mode, color: AppColors.primaryBlue),
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
              leading: const Icon(Icons.brightness_auto, color: AppColors.success),
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
              ListTile(
                leading: const Icon(Icons.email, color: AppColors.primaryBlue),
                title: const Text('Email Verification'),
                subtitle: const Text('Required for sensitive changes'),
                trailing: Switch(
                  value: true, // Always enabled for security
                  onChanged: null, // Cannot be disabled
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: AppColors.primaryBlue),
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
                leading: const Icon(Icons.visibility, color: AppColors.primaryBlue),
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
                leading: const Icon(Icons.security, color: AppColors.primaryBlue),
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
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'General', child: Text('General')),
                  DropdownMenuItem(value: 'Driver', child: Text('Driver Issue')),
                  DropdownMenuItem(value: 'Payment', child: Text('Payment Issue')),
                  DropdownMenuItem(value: 'App', child: Text('App Problem')),
                  DropdownMenuItem(value: 'Safety', child: Text('Safety Concern')),
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
                    content: Text('Issue reported successfully. We will investigate.'),
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
                value: selectedRide,
                decoration: const InputDecoration(
                  labelText: 'Which ride?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Recent Ride', child: Text('Recent Ride')),
                  DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
                  DropdownMenuItem(value: 'This Week', child: Text('This Week')),
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
                    content: Text('Lost item reported. We will contact the driver.'),
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
              trailing: const Icon(Icons.check_circle, color: AppColors.success),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android, color: AppColors.gray400),
              title: const Text('Telebirr'),
              subtitle: const Text('Coming soon'),
              enabled: false,
              onTap: null,
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: AppColors.gray400),
              title: const Text('Bank Card'),
              subtitle: const Text('Coming soon'),
              enabled: false,
              onTap: null,
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: AppColors.gray400),
              title: const Text('Mobile Wallet'),
              subtitle: const Text('Coming soon'),
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
