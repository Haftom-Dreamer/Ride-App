import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/tigray_locations.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Real user data - will be loaded from API
  String _userName = 'Loading...';
  String _userPhone = 'Loading...';
  String _userEmail = 'Loading...';

  List<SavedPlace> _savedPlaces = [];
  String _newPlaceName = '';
  String _newPlaceAddress = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Load user data - for now using sample data
    setState(() {
      _userName = 'Mekdes Tesfay';
      _userPhone = '+251 912 345 678';
      _userEmail = 'mekdes.tesfay@example.com';
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

  void _editProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
              controller: TextEditingController(text: _userName),
              onChanged: (value) => _userName = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Phone'),
              controller: TextEditingController(text: _userPhone),
              onChanged: (value) => _userPhone = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              controller: TextEditingController(text: _userEmail),
              onChanged: (value) => _userEmail = value,
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
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
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
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.lightBlue,
                      child: Text(
                        _userName[0],
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
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
                ),
                _buildDivider(),
                _buildPaymentMethodItem(
                  icon: Icons.phone_android,
                  title: 'Mobile Money',
                  subtitle: 'Not connected',
                  isDefault: false,
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
                  'Privacy',
                  'Control your privacy settings',
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.language,
                  'Language',
                  'English',
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
                  'Help Center',
                  'Get help with your rides',
                ),
                _buildDivider(),
                _buildSettingItem(
                  Icons.support_agent,
                  'Contact Support',
                  'Chat with our support team',
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
      onTap: () {
        // TODO: Edit saved place
      },
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
  }) {
    return InkWell(
      onTap: () {
        // TODO: Manage payment method
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
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
                    ],
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
      {Color? iconColor}) {
    return InkWell(
      onTap: () {
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

      // Clear stored authentication data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_phone');

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
