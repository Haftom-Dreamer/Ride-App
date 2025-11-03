import 'package:flutter/material.dart';

class DriverStatsWidget extends StatelessWidget {
  final int todayRides;
  final double todayEarnings;
  final double? rating;

  const DriverStatsWidget({
    super.key,
    required this.todayRides,
    required this.todayEarnings,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              icon: Icons.local_taxi,
              label: 'Today\'s Rides',
              value: todayRides.toString(),
              color: Colors.blue,
            ),
            _buildStatItem(
              context,
              icon: Icons.attach_money,
              label: 'Today\'s Earnings',
              value: 'ETB ${todayEarnings.toStringAsFixed(2)}',
              color: Colors.green,
            ),
            if (rating != null)
              _buildStatItem(
                context,
                icon: Icons.star,
                label: 'Rating',
                value: rating!.toStringAsFixed(1),
                color: Colors.amber,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

