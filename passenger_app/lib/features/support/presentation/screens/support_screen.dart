import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../ride/data/ride_repository.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final RideRepository _rideRepository = RideRepository();

  List<Map<String, dynamic>> _recentRides = [];
  int? _selectedRideId;
  bool _loadingRides = true;
  bool _submitting = false;
  final TextEditingController _lostItemController = TextEditingController();
  // General issue
  final TextEditingController _issueDescriptionController = TextEditingController();
  final List<String> _issueCategories = const [
    'Payment',
    'Driver',
    'App/Technical',
    'Safety',
    'Other',
  ];
  String _selectedIssueCategory = 'Other';
  int? _issueRideId; // optional attached trip
  bool _submittingIssue = false;

  @override
  void initState() {
    super.initState();
    _loadRecentRides();
  }

  Future<void> _loadRecentRides() async {
    try {
      final history = await _rideRepository.getRideHistory(page: 1, perPage: 20);
      final rides = (history['rides'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _recentRides = rides;
        _loadingRides = false;
      });
    } catch (e) {
      setState(() {
        _recentRides = [];
        _loadingRides = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trips: $e')),
        );
      }
    }
  }

  Future<void> _submitLostItem() async {
    if (_selectedRideId == null || _lostItemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trip and describe the item')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _rideRepository.sendSOS(
        rideId: _selectedRideId!,
        location: const LatLng(0, 0),
        message: 'Lost item report: ${_lostItemController.text.trim()}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lost item reported. We will contact you.')),
        );
        _lostItemController.clear();
        setState(() => _selectedRideId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitIssue() async {
    if (_issueDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue')),
      );
      return;
    }
    setState(() => _submittingIssue = true);
    try {
      await _rideRepository.sendSOS(
        rideId: _issueRideId ?? 0,
        location: const LatLng(0, 0),
        message:
            'General Issue [$_selectedIssueCategory]: ${_issueDescriptionController.text.trim()}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported. We will contact you.')),
        );
        _issueDescriptionController.clear();
        setState(() => _issueRideId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingIssue = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Report Lost Item
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report a Lost Item',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _loadingRides
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ))
                      : DropdownButtonFormField<int>(
                          value: _selectedRideId,
                          decoration: const InputDecoration(
                            labelText: 'Select Trip',
                            border: OutlineInputBorder(),
                          ),
                          items: _recentRides
                              .map((r) => DropdownMenuItem<int>(
                                    value: r['id'] as int,
                                    child: Text(
                                      _formatRideTitle(r),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRideId = v),
                        ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lostItemController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Describe the lost item',
                      hintText: 'e.g., Black wallet with ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitLostItem,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Report a General Issue
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report an Issue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedIssueCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _issueCategories
                        .map((c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedIssueCategory = v ?? 'Other'),
                  ),
                  const SizedBox(height: 12),
                  if (!_loadingRides)
                    DropdownButtonFormField<int>(
                      value: _issueRideId,
                      decoration: const InputDecoration(
                        labelText: 'Attach Trip (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._recentRides.map((r) => DropdownMenuItem<int>(
                              value: r['id'] as int,
                              child: Text(_formatRideTitle(r), overflow: TextOverflow.ellipsis),
                            )),
                      ].whereType<DropdownMenuItem<int>>().toList(),
                      onChanged: (v) => setState(() => _issueRideId = v),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _issueDescriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Describe the issue',
                      hintText: 'Tell us what happened',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submittingIssue ? null : _submitIssue,
                      child: _submittingIssue
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // FAQs
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAQs',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildFAQ('How do I change my destination?',
                      'Tap Change on the trip summary before requesting.'),
                  _buildFAQ('How do I switch theme?',
                      'Go to Settings → App Preferences → Dark Mode.'),
                  _buildFAQ('My payment failed, what should I do?',
                      'Report an issue under Payment category and we will assist.'),
                  _buildFAQ('I lost an item in a ride. How to report?',
                      'Use the Report a Lost Item card above and select the trip.'),
                  _buildFAQ('How to contact support?',
                      'Use the contact buttons below or the Support option in Settings.'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Contact
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Us',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Call: +251 911 234 567')),
                            );
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email: selamawiride@gmail.com')),
                            );
                          },
                          icon: const Icon(Icons.email),
                          label: const Text('Email'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ(String q, String a) {
    return ExpansionTile(
      title: Text(q, style: Theme.of(context).textTheme.bodyLarge),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              a,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRideTitle(Map<String, dynamic> r) {
    final pickup = (r['pickup_address'] ?? '-') as String;
    final dest = (r['dest_address'] ?? '-') as String;
    final ts = (r['request_time'] ?? '') as String;
    return '$pickup → $dest  •  $ts';
  }
}


