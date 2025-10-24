import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ride_history_provider.dart';

class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Completed',
    'Cancelled',
    'In Progress'
  ];

  @override
  void initState() {
    super.initState();
    // Load ride history when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideHistoryProvider.notifier).loadRideHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideHistoryState = ref.watch(rideHistoryProvider);
    final rideHistoryNotifier = ref.read(rideHistoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Filter dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String value) {
              setState(() {
                _selectedFilter = value;
              });
              rideHistoryNotifier.filterRides(value);
            },
            itemBuilder: (BuildContext context) {
              return _filterOptions.map((String option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        _getFilterIcon(option),
                        color: _selectedFilter == option
                            ? Colors.blue.shade700
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(option),
                      if (_selectedFilter == option)
                        const Icon(Icons.check, color: Colors.blue),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = option;
                      });
                      rideHistoryNotifier.filterRides(option);
                    },
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade700,
                  ),
                );
              },
            ),
          ),

          // Ride history list
          Expanded(
            child: rideHistoryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : rideHistoryState.rides.isEmpty
                    ? _buildEmptyState()
                    : _buildRideHistoryList(rideHistoryState.rides),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Ride History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed rides will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRideHistoryList(List<RideHistory> rides) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(rideHistoryProvider.notifier).loadRideHistory();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index];
          return _buildRideCard(ride);
        },
      ),
    );
  }

  Widget _buildRideCard(RideHistory ride) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showRideDetails(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ride.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ride.status,
                      style: TextStyle(
                        color: _getStatusColor(ride.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(ride.requestTime),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Route information
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 20,
                        color: Colors.grey.shade300,
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickupAddress,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ride.destAddress,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Fare and vehicle type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.attach_money,
                        size: 16,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${ride.fare.toStringAsFixed(2)} ETB',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ride.vehicleType,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRideDetails(RideHistory ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ride Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ride.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ride.status,
                      style: TextStyle(
                        color: _getStatusColor(ride.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route
                    _buildDetailSection(
                      'Route',
                      [
                        _buildLocationRow('From', ride.pickupAddress,
                            Icons.radio_button_checked, Colors.green),
                        _buildLocationRow('To', ride.destAddress,
                            Icons.radio_button_checked, Colors.red),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Trip Details
                    _buildDetailSection(
                      'Trip Details',
                      [
                        _buildDetailRow(
                            'Distance',
                            '${ride.distanceKm.toStringAsFixed(1)} km',
                            Icons.straighten),
                        _buildDetailRow('Vehicle Type', ride.vehicleType,
                            Icons.directions_car),
                        _buildDetailRow('Payment Method', ride.paymentMethod,
                            Icons.payment),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Fare
                    _buildDetailSection(
                      'Fare',
                      [
                        _buildDetailRow(
                            'Total Fare',
                            '${ride.fare.toStringAsFixed(2)} ETB',
                            Icons.attach_money,
                            isHighlighted: true),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Timing
                    _buildDetailSection(
                      'Timing',
                      [
                        _buildDetailRow(
                            'Request Time',
                            _formatDateTime(ride.requestTime),
                            Icons.access_time),
                        if (ride.assignedTime != null)
                          _buildDetailRow(
                              'Assigned Time',
                              _formatDateTime(ride.assignedTime!),
                              Icons.check_circle),
                      ],
                    ),

                    if (ride.note != null && ride.note!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        'Note',
                        [
                          _buildDetailRow(
                              'Special Instructions', ride.note!, Icons.note),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? Colors.green.shade600 : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
      String label, String address, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              address,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in progress':
      case 'assigned':
        return Colors.orange;
      case 'requested':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.list;
      case 'Completed':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      case 'In Progress':
        return Icons.hourglass_empty;
      default:
        return Icons.list;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Ride History model
class RideHistory {
  final int id;
  final String pickupAddress;
  final String destAddress;
  final double distanceKm;
  final double fare;
  final String vehicleType;
  final String status;
  final DateTime requestTime;
  final DateTime? assignedTime;
  final String? note;
  final String paymentMethod;

  const RideHistory({
    required this.id,
    required this.pickupAddress,
    required this.destAddress,
    required this.distanceKm,
    required this.fare,
    required this.vehicleType,
    required this.status,
    required this.requestTime,
    this.assignedTime,
    this.note,
    required this.paymentMethod,
  });

  factory RideHistory.fromJson(Map<String, dynamic> json) {
    return RideHistory(
      id: json['id'] as int,
      pickupAddress: json['pickup_address'] as String,
      destAddress: json['dest_address'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      fare: (json['fare'] as num).toDouble(),
      vehicleType: json['vehicle_type'] as String,
      status: json['status'] as String,
      requestTime: DateTime.parse(json['request_time'] as String),
      assignedTime: json['assigned_time'] != null
          ? DateTime.parse(json['assigned_time'] as String)
          : null,
      note: json['note'] as String?,
      paymentMethod: json['payment_method'] as String,
    );
  }
}
