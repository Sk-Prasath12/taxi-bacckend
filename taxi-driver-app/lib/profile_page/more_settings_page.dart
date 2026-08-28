import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/earnings/earnings_page.dart';
import 'package:taxiapp/support/support_page.dart';
import 'language_region_settings_page.dart';
import 'incentive_page.dart';
import 'service_manager_page.dart';

class MoreSettingsPage extends StatelessWidget {
  const MoreSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMoreHeader(context),
            const SizedBox(height: 16),
            _buildSection(context, 'Earnings & Incentives', [
              _buildMoreItem(
                context,
                icon: Icons.monetization_on_outlined,
                title: 'Earning Details',
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsPage())),
              ),
              _buildMoreItem(
                context,
                icon: Icons.star_outline,
                title: 'Incentives',
                color: AppColors.warning,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncentivePage())),
              ),
            ]),
            _buildSection(context, 'Management', [
              _buildMoreItem(
                context,
                icon: Icons.manage_accounts_outlined,
                title: 'Service Manager',
                color: AppColors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceManagerPage())),
              ),
            ]),
            _buildSection(context, 'Support & Settings', [
              _buildMoreItem(
                context,
                icon: Icons.help_outline,
                title: 'Help & Support',
                color: Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())),
              ),
              _buildMoreItem(
                context,
                icon: Icons.language,
                title: 'Language Settings',
                color: AppColors.blackLight,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageRegionSettingsPage())),
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.cardDark,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Taxi Driver',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Premium Member',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}
