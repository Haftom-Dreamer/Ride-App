import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/domain/models/ride.dart';

class RideRequestBottomSheet extends StatelessWidget {
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final RideType selectedRideType;
  final double? estimatedFare;
  final bool isRequestingRide;
  final Function(RideType) onRideTypeChanged;
  final VoidCallback onRequestRide;

  const RideRequestBottomSheet({
    super.key,
    this.pickupLocation,
    this.destinationLocation,
    required this.selectedRideType,
    this.estimatedFare,
    this.isRequestingRide = false,
    required this.onRideTypeChanged,
    required this.onRequestRide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup location
                _buildLocationField(
                  icon: Icons.my_location,
                  label: 'Pickup',
                  location: pickupLocation,
                  onTap: () {
                    // TODO: Implement location search
                    _showLocationSearch(context, 'pickup');
                  },
                ),

                const SizedBox(height: 16),

                // Destination location
                _buildLocationField(
                  icon: Icons.place,
                  label: 'Destination',
                  location: destinationLocation,
                  onTap: () {
                    // TODO: Implement location search
                    _showLocationSearch(context, 'destination');
                  },
                ),

                const SizedBox(height: 24),

                // Ride type selection
                _buildRideTypeSelection(),

                const SizedBox(height: 16),

                // Fare estimation
                if (estimatedFare != null) _buildFareEstimation(),

                const SizedBox(height: 24),

                // Request ride button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (pickupLocation != null &&
                            destinationLocation != null &&
                            !isRequestingRide)
                        ? onRequestRide
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isRequestingRide
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Requesting...'),
                            ],
                          )
                        : const Text(
                            'Request Ride',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required IconData icon,
    required String label,
    LatLng? location,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: location != null ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location != null
                        ? '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}'
                        : 'Select $label',
                    style: TextStyle(
                      color: location != null
                          ? Colors.black
                          : Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (location != null)
              IconButton(
                onPressed: () {
                  // TODO: Clear location
                },
                icon: const Icon(Icons.close, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride Type',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRideTypeOption(
                rideType: RideType.economy,
                icon: Icons.motorcycle,
                label: 'Economy',
                description: 'Budget-friendly',
                isSelected: selectedRideType == RideType.economy,
                onTap: () => onRideTypeChanged(RideType.economy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRideTypeOption(
                rideType: RideType.standard,
                icon: Icons.directions_car,
                label: 'Standard',
                description: 'Comfortable',
                isSelected: selectedRideType == RideType.standard,
                onTap: () => onRideTypeChanged(RideType.standard),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRideTypeOption(
                rideType: RideType.premium,
                icon: Icons.directions_car_filled,
                label: 'Premium',
                description: 'Luxury',
                isSelected: selectedRideType == RideType.premium,
                onTap: () => onRideTypeChanged(RideType.premium),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRideTypeOption({
    required RideType rideType,
    required IconData icon,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade500,
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareEstimation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_money,
            color: Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Estimated Fare: ',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'ETB ${estimatedFare!.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationSearch(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search ${type == 'pickup' ? 'Pickup' : 'Destination'} Location',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter address or place name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(
              child: Center(
                child: Text(
                  'Location search functionality\nwill be implemented here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
