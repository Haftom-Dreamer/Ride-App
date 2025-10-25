import 'package:flutter/material.dart';

class LocationSearchWidget extends StatelessWidget {
  final String pickupAddress;
  final String destinationAddress;
  final Function(String) onPickupChanged;
  final Function(String) onDestinationChanged;

  const LocationSearchWidget({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.onPickupChanged,
    required this.onDestinationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pickup location
          _buildLocationField(
            icon: Icons.my_location,
            label: 'Pickup',
            address: pickupAddress,
            onTap: () => _showLocationSearch(context, 'pickup'),
          ),

          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Destination location
          _buildLocationField(
            icon: Icons.place,
            label: 'Destination',
            address: destinationAddress,
            onTap: () => _showLocationSearch(context, 'destination'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required IconData icon,
    required String label,
    required String address,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: icon == Icons.my_location ? Colors.blue : Colors.red,
                shape: BoxShape.circle,
              ),
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
                  const SizedBox(height: 2),
                  Text(
                    address.isEmpty ? 'Select $label' : address,
                    style: TextStyle(
                      color:
                          address.isEmpty ? Colors.grey.shade500 : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationSearch(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                children: [
                  Text(
                    'Search ${type == 'pickup' ? 'Pickup' : 'Destination'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Enter address or place name',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (value) {
                  // TODO: Implement search functionality
                },
              ),
            ),

            // Search results
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Recent locations
                  _buildSectionHeader('Recent Locations'),
                  _buildLocationItem(
                    icon: Icons.history,
                    title: 'Home',
                    subtitle: '123 Main Street, Addis Ababa',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (type == 'pickup') {
                        onPickupChanged('Home - 123 Main Street, Addis Ababa');
                      } else {
                        onDestinationChanged(
                            'Home - 123 Main Street, Addis Ababa');
                      }
                    },
                  ),
                  _buildLocationItem(
                    icon: Icons.work,
                    title: 'Office',
                    subtitle: '456 Business District, Addis Ababa',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (type == 'pickup') {
                        onPickupChanged(
                            'Office - 456 Business District, Addis Ababa');
                      } else {
                        onDestinationChanged(
                            'Office - 456 Business District, Addis Ababa');
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // Popular places
                  _buildSectionHeader('Popular Places'),
                  _buildLocationItem(
                    icon: Icons.shopping_cart,
                    title: 'Bole Mall',
                    subtitle: 'Bole, Addis Ababa',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (type == 'pickup') {
                        onPickupChanged('Bole Mall, Bole, Addis Ababa');
                      } else {
                        onDestinationChanged('Bole Mall, Bole, Addis Ababa');
                      }
                    },
                  ),
                  _buildLocationItem(
                    icon: Icons.local_airport,
                    title: 'Bole International Airport',
                    subtitle: 'Bole, Addis Ababa',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (type == 'pickup') {
                        onPickupChanged(
                            'Bole International Airport, Bole, Addis Ababa');
                      } else {
                        onDestinationChanged(
                            'Bole International Airport, Bole, Addis Ababa');
                      }
                    },
                  ),
                  _buildLocationItem(
                    icon: Icons.train,
                    title: 'Addis Ababa Railway Station',
                    subtitle: 'Mercato, Addis Ababa',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (type == 'pickup') {
                        onPickupChanged(
                            'Addis Ababa Railway Station, Mercato, Addis Ababa');
                      } else {
                        onDestinationChanged(
                            'Addis Ababa Railway Station, Mercato, Addis Ababa');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}


