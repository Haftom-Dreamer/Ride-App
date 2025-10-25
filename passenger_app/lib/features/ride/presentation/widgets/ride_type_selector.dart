import 'package:flutter/material.dart';
import '../../../../shared/domain/models/ride.dart';

class RideTypeSelector extends StatelessWidget {
  final RideType selectedRideType;
  final Function(RideType) onRideTypeChanged;

  const RideTypeSelector({
    super.key,
    required this.selectedRideType,
    required this.onRideTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your ride',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 16,
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
                price: 'ETB 15/km',
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
                price: 'ETB 20/km',
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
                price: 'ETB 30/km',
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
    required String price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
