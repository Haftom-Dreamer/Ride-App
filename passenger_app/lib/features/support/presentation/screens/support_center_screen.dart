import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isEmergency = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        title: const Text('Support Center'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.error, Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Emergency SOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Press and hold for 3 seconds to contact emergency services',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showEmergencyDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Emergency SOS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Help Section
            Text(
              'Quick Help',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildQuickHelpCard(
                    icon: Icons.phone,
                    title: 'Call Support',
                    subtitle: '+251 911 234 567',
                    color: AppColors.primaryBlue,
                    onTap: () => _callSupport(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickHelpCard(
                    icon: Icons.chat,
                    title: 'Live Chat',
                    subtitle: 'Available 24/7',
                    color: AppColors.secondaryGreen,
                    onTap: () => _startLiveChat(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickHelpCard(
                    icon: Icons.email,
                    title: 'Email Support',
                    subtitle: 'selamawiride@gmail.com',
                    color: AppColors.warning,
                    onTap: () => _sendEmail(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickHelpCard(
                    icon: Icons.report_problem,
                    title: 'Report Issue',
                    subtitle: 'Report a problem',
                    color: AppColors.error,
                    onTap: () => _reportIssue(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // FAQ Section
            Text(
              'Frequently Asked Questions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            ..._buildFAQItems(),

            const SizedBox(height: 24),

            // Safety Features
            Text(
              'Safety Features',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _buildSafetyFeatureCard(
              icon: Icons.share_location,
              title: 'Share Live Location',
              subtitle: 'Share your real-time location with trusted contacts',
              onTap: () => _shareLiveLocation(),
            ),

            const SizedBox(height: 12),

            _buildSafetyFeatureCard(
              icon: Icons.security,
              title: 'Safety Check',
              subtitle: 'Verify your driver and vehicle details',
              onTap: () => _safetyCheck(),
            ),

            const SizedBox(height: 12),

            _buildSafetyFeatureCard(
              icon: Icons.record_voice_over,
              title: 'Voice Recording',
              subtitle: 'Record audio during your ride for safety',
              onTap: () => _voiceRecording(),
            ),

            const SizedBox(height: 24),

            // Contact Form
            Text(
              'Send us a Message',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

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
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'General', child: Text('General')),
                      DropdownMenuItem(
                          value: 'Technical', child: Text('Technical Issue')),
                      DropdownMenuItem(
                          value: 'Payment', child: Text('Payment Issue')),
                      DropdownMenuItem(
                          value: 'Safety', child: Text('Safety Concern')),
                      DropdownMenuItem(
                          value: 'Feedback', child: Text('Feedback')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Describe your issue or question...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _isEmergency,
                        onChanged: (value) {
                          setState(() {
                            _isEmergency = value!;
                          });
                        },
                      ),
                      const Text('This is an emergency'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Send Message'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickHelpCard({
    required IconData icon,
    required String title,
    required String subtitle,
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
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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

  List<Widget> _buildFAQItems() {
    final faqs = [
      {
        'question': 'How do I request a ride?',
        'answer':
            'Tap "Where to?" on the home screen, select your destination, choose a vehicle type, and tap "Request Ride".'
      },
      {
        'question': 'How much does a ride cost?',
        'answer':
            'Prices vary by vehicle type: Bajaj (ETB 30-50), Car (ETB 50-80), SUV (ETB 80-120). Exact fare is calculated based on distance.'
      },
      {
        'question': 'What if I need to cancel my ride?',
        'answer':
            'You can cancel your ride before the driver arrives. Tap "Cancel Request" in the app.'
      },
      {
        'question': 'How do I contact my driver?',
        'answer':
            'Once your driver is assigned, you can call them directly using the "Call Driver" button.'
      },
      {
        'question': 'Is the service available 24/7?',
        'answer':
            'Yes, our ride service is available 24 hours a day, 7 days a week in Mekelle and Adigrat.'
      },
    ];

    return faqs
        .map((faq) => _buildFAQItem(faq['question']!, faq['answer']!))
        .toList();
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: AppColors.error),
            SizedBox(width: 8),
            Text('Emergency SOS'),
          ],
        ),
        content: const Text(
          'Are you sure you want to activate Emergency SOS? This will immediately contact emergency services and share your location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _activateEmergencySOS();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Activate SOS'),
          ),
        ],
      ),
    );
  }

  void _activateEmergencySOS() {
    // TODO: Implement emergency SOS functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Emergency SOS activated! Emergency services have been contacted.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _callSupport() {
    // TODO: Implement phone call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling support...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _startLiveChat() {
    // TODO: Implement live chat functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting live chat...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _sendEmail() {
    // TODO: Implement email functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening email client...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _reportIssue() {
    // TODO: Navigate to report issue screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening issue report form...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _shareLiveLocation() {
    // TODO: Implement live location sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live location sharing feature coming soon'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _safetyCheck() {
    // TODO: Implement safety check
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safety check feature coming soon'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _voiceRecording() {
    // TODO: Implement voice recording
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice recording feature coming soon'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // TODO: Implement message sending
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Message sent successfully${_isEmergency ? ' (Emergency priority)' : ''}'),
        backgroundColor: AppColors.success,
      ),
    );

    _messageController.clear();
    setState(() {
      _isEmergency = false;
    });
  }
}
