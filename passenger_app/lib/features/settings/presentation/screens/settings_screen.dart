import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../support/presentation/screens/support_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  void _showSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SupportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeProviderNotifier);
    final bool _darkModeEnabled = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notifications Section
          _buildSectionCard(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              _buildSwitchItem(
                title: 'Push Notifications',
                subtitle: 'Receive notifications about your rides',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.notification_important,
                title: 'Ride Updates',
                subtitle: 'Driver arrival, trip status',
                onTap: () => _showNotificationSettings(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.local_offer,
                title: 'Promotions',
                subtitle: 'Special offers and discounts',
                onTap: () => _showPromotionSettings(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Privacy & Security Section
          _buildSectionCard(
            title: 'Privacy & Security',
            icon: Icons.lock_outline,
            children: [
              _buildSettingItem(
                icon: Icons.visibility,
                title: 'Profile Visibility',
                subtitle: 'Control who can see your profile',
                onTap: () => _showPrivacySettings(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.location_off,
                title: 'Location Services',
                subtitle: 'Manage location permissions',
                onTap: () => _showLocationSettings(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.security,
                title: 'Two-Factor Authentication',
                subtitle: 'Add extra security to your account',
                onTap: () => _show2FASettings(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                onTap: () => _showDeleteAccountDialog(),
                iconColor: AppColors.error,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // App Preferences Section
          _buildSectionCard(
            title: 'App Preferences',
            icon: Icons.tune,
            children: [
              _buildSettingItem(
                icon: Icons.language,
                title: 'Language',
                subtitle: _selectedLanguage,
                onTap: () => _showLanguageSelector(),
              ),
              _buildDivider(),
              _buildSwitchItem(
                title: 'Dark Mode',
                subtitle: 'Switch between light and dark theme',
                value: _darkModeEnabled,
                onChanged: (value) {
                  themeProvider.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.text_fields,
                title: 'Font Size',
                subtitle: 'Adjust text size for better readability',
                onTap: () => _showFontSizeSettings(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.accessibility,
                title: 'Accessibility',
                subtitle: 'Screen reader and accessibility options',
                onTap: () => _showAccessibilitySettings(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment & Billing Section
          _buildSectionCard(
            title: 'Payment & Billing',
            icon: Icons.payment,
            children: [
              _buildSettingItem(
                icon: Icons.credit_card,
                title: 'Payment Methods',
                subtitle: 'Manage your payment options',
                onTap: () => _showPaymentMethods(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.receipt,
                title: 'Billing History',
                subtitle: 'View your ride receipts',
                onTap: () => _showBillingHistory(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.local_offer,
                title: 'Promo Codes',
                subtitle: 'Enter and manage promo codes',
                onTap: () => _showPromoCodes(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // About Section
          _buildSectionCard(
            title: 'About',
            icon: Icons.info_outline,
            children: [
              _buildSettingItem(
                icon: Icons.support_agent,
                title: 'Customer Support',
                subtitle: 'Call, email, or chat with us',
                onTap: () => _showSupport(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.description,
                title: 'Terms & Conditions',
                subtitle: 'Read our service terms',
                onTap: () => _showTermsAndConditions(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'How we use your data',
                onTap: () => _showPrivacyPolicy(),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.info,
                title: 'App Version',
                subtitle: 'Version 1.0.0',
                onTap: () => _showAppInfo(),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon,
                    color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
          // Section Items
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.toggle_on,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      indent: 52,
      height: 1,
      color: Theme.of(context).dividerColor,
    );
  }

  // Action Methods
  void _showNotificationSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification settings coming soon!')),
    );
  }

  void _showPromotionSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promotion settings coming soon!')),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Settings'),
        content: const Text('Privacy settings will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location settings coming soon!')),
    );
  }

  void _show2FASettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('2FA settings coming soon!')),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion coming soon!')),
              );
            },
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              trailing: _selectedLanguage == 'English'
                  ? const Icon(Icons.check, color: AppColors.primaryBlue)
                  : null,
              onTap: () {
                setState(() {
                  _selectedLanguage = 'English';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('አማርኛ'),
              trailing: _selectedLanguage == 'አማርኛ'
                  ? const Icon(Icons.check, color: AppColors.primaryBlue)
                  : null,
              onTap: () {
                setState(() {
                  _selectedLanguage = 'አማርኛ';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('ትግርኛ'),
              trailing: _selectedLanguage == 'ትግርኛ'
                  ? const Icon(Icons.check, color: AppColors.primaryBlue)
                  : null,
              onTap: () {
                setState(() {
                  _selectedLanguage = 'ትግርኛ';
                });
                Navigator.pop(context);
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

  // Removed legacy _toggleDarkMode; theme switches via ThemeProvider

  void _showFontSizeSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Font size settings coming soon!')),
    );
  }

  void _showAccessibilitySettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accessibility settings coming soon!')),
    );
  }

  void _showPaymentMethods() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment methods coming soon!')),
    );
  }

  void _showBillingHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Billing history coming soon!')),
    );
  }

  void _showPromoCodes() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promo codes coming soon!')),
    );
  }

  void _showTermsAndConditions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms & Conditions coming soon!')),
    );
  }

  void _showPrivacyPolicy() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy Policy coming soon!')),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selamawi Ride'),
            Text('Version: 1.0.0'),
            Text('Build: 2024.01.01'),
            SizedBox(height: 8),
            Text('© 2024 Selamawi Ride. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
