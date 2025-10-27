import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';

enum TripStatus {
  completed,
  cancelled,
  ongoing,
}

class TripRecord {
  final String id;
  final DateTime timestamp;
  final String fromLocation;
  final String toLocation;
  final LatLng fromCoordinates;
  final LatLng toCoordinates;
  final double fare;
  final String vehicleType;
  final String driverName;
  final String? driverPhoto;
  final double distanceKm;
  final String duration;
  final TripStatus status;
  final double? rating;

  const TripRecord({
    required this.id,
    required this.timestamp,
    required this.fromLocation,
    required this.toLocation,
    required this.fromCoordinates,
    required this.toCoordinates,
    required this.fare,
    required this.vehicleType,
    required this.driverName,
    this.driverPhoto,
    required this.distanceKm,
    required this.duration,
    required this.status,
    this.rating,
  });
}

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Sample trip data
  final List<TripRecord> _allTrips = [
    TripRecord(
      id: 'trip_1',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      fromLocation: 'Hawelti, Mekelle',
      toLocation: 'Ayder Hospital',
      fromCoordinates: const LatLng(13.4833, 39.4750),
      toCoordinates: const LatLng(13.4641, 39.4639),
      fare: 45,
      vehicleType: 'Bajaj',
      driverName: 'Tekle Haile',
      distanceKm: 3.2,
      duration: '12 min',
      status: TripStatus.completed,
      rating: 5.0,
    ),
    TripRecord(
      id: 'trip_2',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      fromLocation: 'Kedamay Weyane',
      toLocation: 'Mekelle University',
      fromCoordinates: const LatLng(13.4950, 39.4700),
      toCoordinates: const LatLng(13.4833, 39.4833),
      fare: 38,
      vehicleType: 'Standard Car',
      driverName: 'Gebru Tesfay',
      distanceKm: 2.5,
      duration: '8 min',
      status: TripStatus.completed,
      rating: 4.5,
    ),
    TripRecord(
      id: 'trip_3',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      fromLocation: 'Quiha',
      toLocation: 'Mekelle Airport',
      fromCoordinates: const LatLng(13.5150, 39.4900),
      toCoordinates: const LatLng(13.4674, 39.5336),
      fare: 0,
      vehicleType: 'Bajaj',
      driverName: 'Haftom Gebrekidan',
      distanceKm: 4.8,
      duration: '15 min',
      status: TripStatus.cancelled,
    ),
    TripRecord(
      id: 'trip_4',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      fromLocation: 'Mekelle Central Market',
      toLocation: 'Adi Haki',
      fromCoordinates: const LatLng(13.4920, 39.4730),
      toCoordinates: const LatLng(13.4900, 39.4800),
      fare: 25,
      vehicleType: 'Bajaj',
      driverName: 'Yohannes Negash',
      distanceKm: 1.2,
      duration: '5 min',
      status: TripStatus.completed,
      rating: 4.0,
    ),
    TripRecord(
      id: 'trip_5',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      fromLocation: 'Hawelti',
      toLocation: 'Kedamay Weyane',
      fromCoordinates: const LatLng(13.4833, 39.4750),
      toCoordinates: const LatLng(13.4950, 39.4700),
      fare: 65,
      vehicleType: 'Premium SUV',
      driverName: 'Berhe Kahsay',
      distanceKm: 2.1,
      duration: '7 min',
      status: TripStatus.completed,
      rating: 5.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TripRecord> get _filteredTrips {
    final int currentTab = _tabController.index;
    
    if (currentTab == 0) {
      // All trips
      return _allTrips;
    } else if (currentTab == 1) {
      // Completed trips
      return _allTrips.where((trip) => trip.status == TripStatus.completed).toList();
    } else {
      // Cancelled trips
      return _allTrips.where((trip) => trip.status == TripStatus.cancelled).toList();
    }
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tripDate = DateTime(date.year, date.month, date.day);

    if (tripDate == today) {
      return 'Today';
    } else if (tripDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(tripDate).inDays < 7) {
      return 'This Week';
    } else if (now.difference(tripDate).inDays < 30) {
      return 'This Month';
    } else {
      return 'Earlier';
    }
  }

  Map<String, List<TripRecord>> get _groupedTrips {
    final Map<String, List<TripRecord>> grouped = {};
    
    for (final trip in _filteredTrips) {
      final header = _getDateHeader(trip.timestamp);
      if (!grouped.containsKey(header)) {
        grouped[header] = [];
      }
      grouped[header]!.add(trip);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        title: const Text('My Trips'),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          onTap: (index) {
            setState(() {}); // Refresh the list
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _filteredTrips.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _groupedTrips.length,
              itemBuilder: (context, index) {
                final header = _groupedTrips.keys.elementAt(index);
                final trips = _groupedTrips[header]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        header,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    
                    // Trip cards
                    ...trips.map((trip) => _buildTripCard(trip)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: AppColors.gray300,
            ),
            const SizedBox(height: 16),
            Text(
              _tabController.index == 2 ? 'No Cancelled Trips' : 'No Trips Yet',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tabController.index == 2 
                  ? 'You haven\'t cancelled any rides'
                  : 'Book your first ride to get started',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(TripRecord trip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showTripDetails(trip),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row - time and status
                Row(
                  children: [
                    Text(
                      _formatTime(trip.timestamp),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(trip.status),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Route
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon column
                    Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.pickupGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 20,
                          color: AppColors.gray300,
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.destinationRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Locations
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.fromLocation,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            trip.toLocation,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
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
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Footer - driver, vehicle, fare
                Row(
                  children: [
                    // Driver
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.lightBlue,
                      child: Text(
                        trip.driverName[0],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.driverName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            trip.vehicleType,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Fare
                    if (trip.status == TripStatus.completed)
                      Text(
                        'ETB ${trip.fare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    
                    // Rating
                    if (trip.status == TripStatus.completed && trip.rating != null) ...[
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            trip.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TripStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;
    
    switch (status) {
      case TripStatus.completed:
        backgroundColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        text = 'Completed';
        break;
      case TripStatus.cancelled:
        backgroundColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        text = 'Cancelled';
        break;
      case TripStatus.ongoing:
        backgroundColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        text = 'Ongoing';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showTripDetails(TripRecord trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Row(
                  children: [
                    Text(
                      'Trip Details',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const Spacer(),
                    _buildStatusBadge(trip.status),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Date and time
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDate(trip.timestamp)} at ${_formatTime(trip.timestamp)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Route details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.pickupGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              trip.fromLocation,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.destinationRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              trip.toLocation,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Trip info
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.straighten,
                        'Distance',
                        '${trip.distanceKm.toStringAsFixed(1)} km',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.access_time,
                        'Duration',
                        trip.duration,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Driver info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gray200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.lightBlue,
                        child: Text(
                          trip.driverName[0],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.driverName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              trip.vehicleType,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trip.rating != null)
                        Row(
                          children: [
                            const Icon(Icons.star, size: 20, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(
                              trip.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Fare
                if (trip.status == TripStatus.completed)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Fare',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'ETB ${trip.fare.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Actions
                if (trip.status == TripStatus.completed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Book again with same route
                      },
                      child: const Text('Book Again'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Get help
                      },
                      child: const Text('Get Help'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primaryBlue),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}

