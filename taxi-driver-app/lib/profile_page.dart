import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/profile_page/settings_page.dart';
import 'package:taxiapp/notifications_page.dart';
import 'package:taxiapp/history_page.dart';
import 'package:taxiapp/authentication_page/home_page/home_page.dart';
import 'package:taxiapp/profile_page/more_settings_page.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

class NewProfilePage extends StatelessWidget {
  final AuthService authService;

  const NewProfilePage({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final userName = authService.currentUserName ?? 'Driver';
    final userEmail = authService.currentUser ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Notifications icon
          IconButton(
            icon: const Icon(TaxiIcons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Header Card
            _buildProfileHeader(context, userName, userEmail),

            const SizedBox(height: 24),

            // Stats Section
            _buildStatsSection(context),

            const SizedBox(height: 24),

            // Menu Items
            _buildMenuSection(context),

            const SizedBox(height: 32),

            // Logout Button
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    String userName,
    String userEmail,
  ) {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, _) {
        final profilePath = authService.profileImagePath;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              // Profile Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: profilePath == null
                      ? const Icon(TaxiIcons.profile, size: 60, color: AppColors.green)
                      : (kIsWeb
                          ? Image.network(
                              profilePath,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            )
                          : Image.file(
                              File(profilePath),
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            )),
                ),
              ),
          const SizedBox(height: 16),
          // Name
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Email
          Text(
            userEmail,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          // Edit Profile Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'Edit Profile',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          // Driver Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Active Driver',
                  style: TextStyle(
                    color: AppColors.cardDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildStatsSection(BuildContext context) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: TaxiIcons.taxi,
            value: '1,234',
            label: 'Total Rides',
            color: AppColors.green,
          ),
          _buildDivider(),
          _buildStatItem(
            context,
            icon: TaxiIcons.star,
            value: '4.9',
            label: 'Rating',
            color: AppColors.black,
          ),
          _buildDivider(),
          _buildStatItem(
            context,
            icon: TaxiIcons.earnings,
            value: '₹5.2k',
            label: 'Earnings',
            color: AppColors.greenDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.grey[200]);
  }

  Widget _buildMenuSection(BuildContext context) {
    return Material(
      color: AppColors.cardDark,
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Update your information',
            onTap: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Manage your preferences',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(authService: authService),
                ),
              );
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.history,
            title: 'Ride History',
            subtitle: 'View your past rides',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.payment,
            title: 'Payments',
            subtitle: 'Manage your earnings',
            onTap: () {
              Navigator.pushNamed(context, '/earnings');
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.wallet,
            title: 'Wallet',
            subtitle: 'View balance & withdraw',
            onTap: () {
              Navigator.pushNamed(context, '/wallet');
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.directions_car,
            title: 'Vehicle Details',
            subtitle: 'Manage your vehicle info',
            onTap: () {
              Navigator.pushNamed(context, '/vehicle-details');
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.folder_shared,
            title: 'Documents',
            subtitle: 'Upload and manage documents',
            onTap: () {
              Navigator.pushNamed(context, '/documents');
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.star_border,
            title: 'Ratings & Reviews',
            subtitle: 'View your ratings',
            onTap: () {
              Navigator.pushNamed(context, '/ratings');
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.help_center_outlined,
            title: 'Help & Support',
            subtitle: 'Get help and support',
            onTap: () {
              Navigator.pushNamed(context, '/support');
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.more_horiz,
            title: 'More Settings',
            subtitle: 'Earnings, Incentives, Service & more',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MoreSettingsPage()),
              );
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version 1.0.0',
            onTap: () {
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.green, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _buildMenuDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      color: Colors.grey[200],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showLogoutDialog(context),
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$feature feature will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Taxi App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version 1.0.0'),
            const SizedBox(height: 16),
            Text(
              'The best taxi driver app to manage your rides and earnings.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await authService.logout();
      if (!context.mounted) return;

      // Navigate to home page and clear all routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => HomePage(authService: authService),
        ),
        (route) => false,
      );
    }
  }
}
