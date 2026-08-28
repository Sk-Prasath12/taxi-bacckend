import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class ServiceManagerPage extends StatelessWidget {
  const ServiceManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Manager'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVehicleOverview(context),
            const SizedBox(height: 24),
            const Text(
              'Maintenance Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildServiceItem(
              context,
              title: 'Oil Change',
              dueDate: 'In 500 km',
              progress: 0.8,
              icon: Icons.oil_barrel,
              color: Colors.brown,
            ),
            const SizedBox(height: 12),
            _buildServiceItem(
              context,
              title: 'Tire Rotation',
              dueDate: 'In 2,000 km',
              progress: 0.4,
              icon: Icons.settings_input_component,
              color: AppColors.green,
            ),
            const SizedBox(height: 12),
            _buildServiceItem(
              context,
              title: 'Brake Inspection',
              dueDate: 'Due in 15 days',
              progress: 0.9,
              icon: Icons.report_problem,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Document Renewal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDocumentItem(
              context,
              title: 'Vehicle Insurance',
              expiryDate: 'Exp: Oct 24, 2024',
              status: 'Active',
              statusColor: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildDocumentItem(
              context,
              title: 'Pollution Certificate',
              expiryDate: 'Exp: Mar 15, 2024',
              status: 'Expiring Soon',
              statusColor: AppColors.warning,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Add Service Record'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildVehicleOverview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car, color: AppColors.green, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toyota Prius (2022)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Reg No: ABC-1234',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.speed, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('45,200 km', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(
    BuildContext context, {
    required String title,
    required String dueDate,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(dueDate, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    BuildContext context, {
    required String title,
    required String expiryDate,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(expiryDate, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
