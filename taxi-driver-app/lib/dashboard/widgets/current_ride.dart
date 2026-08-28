import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class CurrentRide extends StatelessWidget {
  const CurrentRide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Ride',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '123 Main St, Anytown, USA',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.red),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '456 Oak Ave, Anytown, USA',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: const Text('View Ride Details'),
          ),
        ],
      ),
    );
  }
}
