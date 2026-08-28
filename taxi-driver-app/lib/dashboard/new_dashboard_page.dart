
import 'package:flutter/material.dart';
import 'package:taxiapp/dashboard/widgets/current_ride.dart';
import 'package:taxiapp/dashboard/widgets/earnings_summary.dart';
import 'package:taxiapp/dashboard/widgets/online_status_switch.dart';
import 'package:taxiapp/dashboard/widgets/quick_actions.dart';

class NewDashboardPage extends StatelessWidget {
  const NewDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OnlineStatusSwitch(),
            const SizedBox(height: 16),
            const EarningsSummary(),
            const SizedBox(height: 16),
            const QuickActions(),
            const SizedBox(height: 16),
            const CurrentRide(),
          ],
        ),
      ),
    );
  }
}
