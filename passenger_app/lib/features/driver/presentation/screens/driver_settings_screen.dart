import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/driver_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import 'driver_profile_screen.dart';
import 'driver_support_screen.dart';
import 'driver_dispatcher_chat_screen.dart';

class DriverSettingsScreen extends ConsumerStatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  ConsumerState<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends ConsumerState<DriverSettingsScreen> {
  final DriverRepository _repo = DriverRepository();
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPicture = false;

  Future<void> _updateProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _uploadingPicture = true);

      await _repo.uploadProfilePicture(image.path);
      
      // Reload profile to update in auth state
      // The profile will be refreshed on next navigation
      // Profile picture URL will update automatically on next profile load

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.watch(themeProviderNotifier);
    final isDark = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile Picture Section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final user = ref.watch(authProvider).user;
                          return CircleAvatar(
                            radius: 50,
                            backgroundImage: user?.profilePicture != null &&
                                    user!.profilePicture!.isNotEmpty
                                ? NetworkImage(
                                    'http://127.0.0.1:5000/${user.profilePicture}')
                                : null,
                            child: user?.profilePicture == null ||
                                    user!.profilePicture!.isEmpty
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          );
                        },
                      ),
                      if (_uploadingPicture)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            onPressed: _uploadingPicture ? null : _updateProfilePicture,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap camera icon to update profile picture',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // Appearance Section
          _buildSectionTitle('Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch between light and dark theme'),
              value: isDark,
              onChanged: (value) {
                themeNotifier.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ),

          // Account Section
          _buildSectionTitle('Account'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'Change app language (Coming soon)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language selection coming soon')),
              );
            },
          ),

          // Communication Section
          _buildSectionTitle('Communication'),
          _buildSettingsTile(
            icon: Icons.message,
            title: 'Chat with Dispatcher',
            subtitle: 'Get help from dispatch team',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DriverDispatcherChatScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.phone,
            title: 'Call Support',
            subtitle: 'Contact support via phone',
            onTap: () async {
              const phoneNumber = '+251912345678'; // Replace with actual support number
              final uri = Uri.parse('tel:$phoneNumber');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not make phone call')),
                  );
                }
              }
            },
          ),

          // Support Section
          _buildSectionTitle('Help & Support'),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Report Issue / Get Support',
            subtitle: 'Submit a support request',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DriverSupportScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.feedback,
            title: 'Send Feedback',
            subtitle: 'Share your thoughts and suggestions',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DriverSupportScreen(
                    initialType: 'feedback',
                  ),
                ),
              );
            },
          ),

          // App Info Section
          _buildSectionTitle('About'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon')),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Read our terms and conditions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of service coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}

