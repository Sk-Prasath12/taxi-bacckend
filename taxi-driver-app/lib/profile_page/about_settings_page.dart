import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Info
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      size: 80,
                      color: AppColors.cardDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Taxi Driver App',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // App Description
            _buildSectionTitle('About the App'),
            _buildInfoCard([
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'The best taxi driver app to manage your rides and earnings efficiently. Track your trips, monitor your income, and provide excellent service to your passengers.',
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Features
            _buildSectionTitle('Key Features'),
            _buildInfoCard([
              _buildFeatureTile(context, Icons.car_rental, 'Ride Management', 'Track and manage all your rides'),
              const Divider(height: 1, indent: 56),
              _buildFeatureTile(context, Icons.attach_money, 'Earnings Tracking', 'Monitor your daily and weekly income'),
              const Divider(height: 1, indent: 56),
              _buildFeatureTile(context, Icons.map, 'Navigation', 'GPS-powered route optimization'),
              const Divider(height: 1, indent: 56),
              _buildFeatureTile(context, Icons.star, 'Ratings & Reviews', 'Build your reputation'),
              const Divider(height: 1, indent: 56),
              _buildFeatureTile(context, Icons.account_balance_wallet, 'Wallet', 'Easy withdrawals and payments'),
            ]),
            
            const SizedBox(height: 24),
            
            // Legal
            _buildSectionTitle('Legal'),
            _buildInfoCard([
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AppColors.green),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showLegalDialog(context, 'Terms of Service');
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: Colors.green),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showLegalDialog(context, 'Privacy Policy');
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.gavel, color: AppColors.warning),
                title: const Text('License Agreement'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showLegalDialog(context, 'License Agreement');
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Contact & Support
            _buildSectionTitle('Contact & Support'),
            _buildInfoCard([
              ListTile(
                leading: const Icon(Icons.email_outlined, color: AppColors.blackLight),
                title: const Text('Contact Support'),
                subtitle: const Text('support@taxiapp.com'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening email client...')),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: Colors.green),
                title: const Text('Call Support'),
                subtitle: const Text('+1 (800) 123-4567'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dialing support number...')),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.help_outline, color: AppColors.green),
                title: const Text('Help Center'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Help Center...')),
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Social Media
            _buildSectionTitle('Connect With Us'),
            _buildInfoCard([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSocialIcon(Icons.facebook, AppColors.green),
                    _buildSocialIcon(Icons.chat, Colors.lightBlue),
                    _buildSocialIcon(Icons.camera_alt, AppColors.blackLight),
                    _buildSocialIcon(Icons.play_arrow, Colors.red),
                  ],
                ),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // More Info
            _buildSectionTitle('More Information'),
            _buildInfoCard([
              ListTile(
                leading: const Icon(Icons.code, color: AppColors.green),
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Taxi Driver App',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2024 Taxi App Inc.',
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.update, color: AppColors.warning),
                title: const Text('Check for Updates'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _checkForUpdates(context);
                },
              ),
            ]),
            
            const SizedBox(height: 32),
            
            // Copyright
            Center(
              child: Text(
                '© ${DateTime.now().year} Taxi App Inc.\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
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
        children: children,
      ),
    );
  }

  Widget _buildFeatureTile(BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  void _showLegalDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This is a placeholder for the $title document. In a real application, this would contain the full legal text.',
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Last updated: January 2024',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
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

  void _checkForUpdates(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checking for Updates'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Available'),
            content: const Text('Version 1.1.0 is available with new features and improvements.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Downloading update...'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      }
    });
  }
}
