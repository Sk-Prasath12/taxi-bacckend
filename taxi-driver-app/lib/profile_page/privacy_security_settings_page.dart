import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class PrivacySecuritySettingsPage extends StatefulWidget {
  const PrivacySecuritySettingsPage({super.key});

  @override
  State<PrivacySecuritySettingsPage> createState() => _PrivacySecuritySettingsPageState();
}

class _PrivacySecuritySettingsPageState extends State<PrivacySecuritySettingsPage> {
  bool _locationEnabled = true;
  bool _biometricLogin = false;
  bool _twoFactorAuth = false;
  bool _showRideHistory = true;
  String _privacyMode = 'Standard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Services
            _buildSectionTitle('Location Services'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.location_on_outlined,
                title: 'Location Access',
                subtitle: 'Allow app to access your location for ride tracking',
                value: _locationEnabled,
                onChanged: (value) {
                  setState(() {
                    _locationEnabled = value;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history, color: AppColors.green),
                ),
                title: const Text('Location History'),
                subtitle: const Text('Manage your location history'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening location history...')),
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Authentication & Security
            _buildSectionTitle('Authentication & Security'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_outline, color: AppColors.warning),
                ),
                title: const Text('Change Password'),
                subtitle: const Text('Update your password regularly for security'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showChangePasswordDialog();
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.fingerprint,
                title: 'Biometric Login',
                subtitle: 'Use fingerprint or face recognition to login',
                value: _biometricLogin,
                onChanged: (value) {
                  setState(() {
                    _biometricLogin = value;
                  });
                  if (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Biometric login enabled'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.security,
                title: 'Two-Factor Authentication',
                subtitle: 'Add an extra layer of security to your account',
                value: _twoFactorAuth,
                onChanged: (value) {
                  setState(() {
                    _twoFactorAuth = value;
                  });
                  if (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('2FA setup instructions sent to your email'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Privacy Settings
            _buildSectionTitle('Privacy Settings'),
            _buildSettingsCard([
              _buildDropdownTile(
                icon: Icons.visibility_outlined,
                title: 'Privacy Mode',
                value: _privacyMode,
                items: ['Standard', 'Enhanced', 'Maximum'],
                onChanged: (value) {
                  setState(() {
                    _privacyMode = value!;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.history_toggle_off,
                title: 'Show Ride History',
                subtitle: 'Display your ride history in the app',
                value: _showRideHistory,
                onChanged: (value) {
                  setState(() {
                    _showRideHistory = value;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_remove_outlined, color: Colors.red),
                ),
                title: const Text('Data Sharing Preferences'),
                subtitle: const Text('Control how your data is shared'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showDataSharingDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Active Sessions
            _buildSectionTitle('Active Sessions'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.devices, color: AppColors.blackLight),
                ),
                title: const Text('Manage Devices'),
                subtitle: const Text('See where you\'re logged in'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showActiveSessionsDialog();
                },
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red),
                ),
                title: const Text('Logout from All Devices'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showLogoutAllDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Delete Account
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showDeleteAccountDialog();
                },
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Delete Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildSettingsCard(List<Widget> children) {
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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password changed successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showDataSharingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Sharing Preferences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose what data you want to share:'),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Ride analytics'),
              subtitle: const Text('Help improve our service'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Location data'),
              subtitle: const Text('For better route suggestions'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Marketing insights'),
              subtitle: const Text('Receive personalized offers'),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preferences saved')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showActiveSessionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Sessions'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSessionTile(
                device: 'iPhone 14 Pro',
                location: 'New York, USA',
                time: 'Active now',
                isCurrent: true,
              ),
              const Divider(),
              _buildSessionTile(
                device: 'Chrome on Windows',
                location: 'Boston, USA',
                time: 'Last active 2 hours ago',
                isCurrent: false,
              ),
              const Divider(),
              _buildSessionTile(
                device: 'Samsung Galaxy S23',
                location: 'Chicago, USA',
                time: 'Last active 1 day ago',
                isCurrent: false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile({
    required String device,
    required String location,
    required String time,
    required bool isCurrent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.phone_iphone : Icons.computer,
            color: isCurrent ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '?location • $time',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () {},
            ),
        ],
      ),
    );
  }

  void _showLogoutAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout from All Devices'),
        content: const Text('Are you sure you want to logout from all devices? You will need to login again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out from all devices'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout All'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion request submitted'),
                  backgroundColor: AppColors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
