import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class IncentivePage extends StatelessWidget {
  const IncentivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incentives'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodayProgress(context),
            const SizedBox(height: 24),
            const Text(
              'Available Incentives',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildIncentiveCard(
              context,
              title: 'Weekly Goal',
              description: 'Complete 50 rides to earn ₹50 bonus',
              progress: 0.6,
              current: '30',
              total: '50',
              color: AppColors.green,
            ),
            const SizedBox(height: 16),
            _buildIncentiveCard(
              context,
              title: 'Peak Hour Bonus',
              description: 'Complete 10 rides between 5PM - 8PM',
              progress: 0.2,
              current: '2',
              total: '10',
              color: AppColors.warning,
            ),
            const SizedBox(height: 24),
            const Text(
              'Completed Incentives',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCompletedCard(
              context,
              title: 'First Ride of Day',
              bonus: '₹2.00',
              date: 'Today, 8:45 AM',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayProgress(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Earnings Bonus',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Text(
                '₹15.00',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: 0.75,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('15 / 20 Rides', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
              Text('75%', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncentiveCard(
    BuildContext context, {
    required String title,
    required String description,
    required double progress,
    required String current,
    required String total,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.star, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(description, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$current / $total completed', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('${(progress * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(
    BuildContext context, {
    required String title,
    required String bonus,
    required String date,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(date, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            bonus,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
