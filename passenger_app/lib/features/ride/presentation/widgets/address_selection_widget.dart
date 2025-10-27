import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'address_autocomplete_widget.dart';

class AddressSelectionWidget extends ConsumerStatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final Function(String) onPickupChanged;
  final Function(String) onDestinationChanged;
  final VoidCallback onCurrentLocationTap;

  const AddressSelectionWidget({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.onPickupChanged,
    required this.onDestinationChanged,
    required this.onCurrentLocationTap,
  });

  @override
  ConsumerState<AddressSelectionWidget> createState() =>
      _AddressSelectionWidgetState();
}

class _AddressSelectionWidgetState
    extends ConsumerState<AddressSelectionWidget> {
  @override
  Widget build(BuildContext context) {
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
}
