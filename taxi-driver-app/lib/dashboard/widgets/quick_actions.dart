
import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionItem(context, Icons.map, 'View Map'),
            _buildActionItem(context, Icons.history, 'Ride History'),
            _buildActionItem(context, Icons.star, 'Ratings'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Icon(icon, size: 30, color: Theme.of(context).primaryColor),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
