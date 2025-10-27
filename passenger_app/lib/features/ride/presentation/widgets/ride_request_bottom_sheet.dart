import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/domain/models/ride.dart';
import 'address_autocomplete_widget.dart';

class RideRequestBottomSheet extends StatefulWidget {
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final String pickupAddress;
  final String destinationAddress;
  final RideType selectedRideType;
  final double? estimatedFare;
  final bool isRequestingRide;
  final Function(RideType) onRideTypeChanged;
  final VoidCallback onRequestRide;
  final Function(String) onPickupChanged;
  final Function(String) onDestinationChanged;
  final VoidCallback onCurrentLocationTap;

  const RideRequestBottomSheet({
    super.key,
    this.pickupLocation,
    this.destinationLocation,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.selectedRideType,
    this.estimatedFare,
    this.isRequestingRide = false,
    required this.onRideTypeChanged,
    required this.onRequestRide,
    required this.onPickupChanged,
    required this.onDestinationChanged,
    required this.onCurrentLocationTap,
  });

  @override
  State<RideRequestBottomSheet> createState() => _RideRequestBottomSheetState();
}

class _RideRequestBottomSheetState extends State<RideRequestBottomSheet> {
  double _sheetHeight = 0.4; // Start at 40% of screen height
  final double _minHeight = 0.2; // Minimum 20% of screen height
  final double _maxHeight = 0.8; // Maximum 80% of screen height

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final currentHeight = screenHeight * _sheetHeight;
    return GestureDetector(
      onPanUpdate: (details) {
        final delta = details.delta.dy;
        final newHeight = _sheetHeight - (delta / screenHeight);

        setState(() {
          _sheetHeight = newHeight.clamp(_minHeight, _maxHeight);
        });
      },
      onPanEnd: (details) {
        // Snap to nearest position
        if (_sheetHeight < 0.3) {
          setState(() => _sheetHeight = _minHeight);
        } else if (_sheetHeight < 0.6) {
          setState(() => _sheetHeight = 0.4);
        } else {
          setState(() => _sheetHeight = _maxHeight);
        }
      },
      child: Container(
        height: currentHeight,
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
          children: [
            // Draggable handle bar
            GestureDetector(
              onTap: () {
                setState(() {
                  _sheetHeight = _sheetHeight == _minHeight ? 0.4 : _minHeight;
                });
              },
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Content - Matching the image design
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Address selection section (matching image)
                    _buildAddressSelectionSection(),

                    const SizedBox(height: 20),

                    // Ride type selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildRideTypeSelection(),
                    ),

                    const SizedBox(height: 16),

                    // Fare estimation
                    if (widget.estimatedFare != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildFareEstimation(),
                      ),

                    const SizedBox(height: 24),

                    // Request ride button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (widget.pickupLocation != null &&
                                  widget.destinationLocation != null &&
                                  !widget.isRequestingRide)
                              ? widget.onRequestRide
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: widget.isRequestingRide
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                    ),

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

  Widget _buildAddressSelectionSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pickup point section
          _buildPickupSection(),

          // Connection line
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 2,
                  height: 20,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
          ),

          // Destination section
          _buildDestinationSection(),

          const SizedBox(height: 20),

          // Saved Places section
          _buildSavedPlacesSection(),

          const SizedBox(height: 20),

          // Recent section
          _buildRecentSection(),
        ],
      ),
    );
  }

  Widget _buildPickupSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pickup point label
          Text(
            'Pickup point',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Pickup input field
          Row(
            children: [
              // Green circle indicator
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Text input field with autocomplete
              Expanded(
                child: AddressAutocompleteWidget(
                  hintText: 'Enter pickup location',
                  initialValue: widget.pickupAddress,
                  onAddressSelected: widget.onPickupChanged,
                ),
              ),

              // Current location button
              GestureDetector(
                onTap: widget.onCurrentLocationTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destination label
          Text(
            'Pick Off',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Destination input field
          Row(
            children: [
              // Gray location pin
              Icon(
                Icons.location_on,
                color: Colors.grey.shade400,
                size: 16,
              ),
              const SizedBox(width: 12),

              // Text input field with autocomplete
              Expanded(
                child: AddressAutocompleteWidget(
                  hintText: 'Where you want to go?',
                  initialValue: widget.destinationAddress,
                  onAddressSelected: widget.onDestinationChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlacesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saved Places header
          Row(
            children: [
              const Icon(
                Icons.flag,
                color: Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Saved Places',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 14,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Work place
          _buildSavedPlaceItem(
            icon: Icons.work,
            title: 'Work',
            subtitle: 'Studio 08 Jake Stream',
            timeDistance: '(10 min, 2.9 km)',
            onTap: () {
              widget.onDestinationChanged('Studio 08 Jake Stream');
            },
          ),

          const SizedBox(height: 12),

          // Home place
          _buildSavedPlaceItem(
            icon: Icons.home,
            title: 'Home',
            subtitle: '705 Green Summit',
            timeDistance: '(43 min, 25 km)',
            onTap: () {
              widget.onDestinationChanged('705 Green Summit');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlaceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String timeDistance,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.grey.shade600,
              size: 20,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeDistance,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Recent pill button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Recent',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Recent locations
          _buildRecentLocationItem(
            title: 'Studio 65Murphy Islands',
            onTap: () {
              widget.onDestinationChanged('Studio 65Murphy Islands');
            },
          ),

          const SizedBox(height: 8),

          _buildRecentLocationItem(
            title: 'Mexicali Ct 13a',
            onTap: () {
              widget.onDestinationChanged('Mexicali Ct 13a');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLocationItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: Colors.grey.shade400,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
                isSelected: widget.selectedRideType == RideType.economy,
                onTap: () => widget.onRideTypeChanged(RideType.economy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRideTypeOption(
                rideType: RideType.standard,
                icon: Icons.directions_car,
                label: 'Standard',
                description: 'Comfortable',
                isSelected: widget.selectedRideType == RideType.standard,
                onTap: () => widget.onRideTypeChanged(RideType.standard),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRideTypeOption(
                rideType: RideType.premium,
                icon: Icons.directions_car_filled,
                label: 'Premium',
                description: 'Luxury',
                isSelected: widget.selectedRideType == RideType.premium,
                onTap: () => widget.onRideTypeChanged(RideType.premium),
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
            'ETB ${widget.estimatedFare!.toStringAsFixed(0)}',
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
}
