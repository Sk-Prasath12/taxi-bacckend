import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _rideRequests = true;
  bool _earningsUpdates = true;
  bool _promotionalOffers = false;
  bool _driverTips = true;
  String _notificationSound = 'Default';
  bool _vibrateOnNotification = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Push Notifications
            _buildSectionTitle('Push Notifications'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'All Notifications',
                subtitle: 'Enable or disable all notifications',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() {
                    _pushNotifications = value;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.car_rental,
                title: 'Ride Requests',
                subtitle: 'Get notified when new ride requests are available',
                value: _rideRequests,
                onChanged: (value) {
                  setState(() {
                    _rideRequests = value;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.attach_money,
                title: 'Earnings Updates',
                subtitle: 'Receive daily and weekly earnings summaries',
                value: _earningsUpdates,
                onChanged: (value) {
                  setState(() {
                    _earningsUpdates = value;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.card_giftcard,
                title: 'Promotional Offers',
                subtitle: 'Get notified about bonuses and special offers',
                value: _promotionalOffers,
                onChanged: (value) {
                  setState(() {
                    _promotionalOffers = value;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.thumb_up_outlined,
                title: 'Driver Tips & Updates',
                subtitle: 'Tips to improve your driving experience',
                value: _driverTips,
                onChanged: (value) {
                  setState(() {
                    _driverTips = value;
                  });
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Email Notifications
            _buildSectionTitle('Email Notifications'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.email_outlined,
                title: 'Email Notifications',
                subtitle: 'Receive earnings reports and updates via email',
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() {
                    _emailNotifications = value;
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
                  child: const Icon(Icons.edit_outlined, color: AppColors.green),
                ),
                title: const Text('Email Frequency'),
                subtitle: const Text('Daily summary'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showEmailFrequencyDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // SMS Notifications
            _buildSectionTitle('SMS Notifications'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.sms_outlined,
                title: 'SMS Notifications',
                subtitle: 'Receive important updates via text message',
                value: _smsNotifications,
                onChanged: (value) {
                  setState(() {
                    _smsNotifications = value;
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
                  child: const Icon(Icons.phone_outlined, color: Colors.green),
                ),
                title: const Text('SMS Number'),
                subtitle: const Text('+1 ***-***-1234'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showChangePhoneDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Notification Preferences
            _buildSectionTitle('Notification Preferences'),
            _buildSettingsCard([
              _buildDropdownTile(
                icon: Icons.music_note_outlined,
                title: 'Notification Sound',
                value: _notificationSound,
                items: ['Default', 'Chime', 'Bell', 'Gentle', 'Silent'],
                onChanged: (value) {
                  setState(() {
                    _notificationSound = value!;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.vibration,
                title: 'Vibrate on Notification',
                subtitle: 'Vibrate phone when receiving notifications',
                value: _vibrateOnNotification,
                onChanged: (value) {
                  setState(() {
                    _vibrateOnNotification = value;
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
                  child: const Icon(Icons.schedule, color: AppColors.warning),
                ),
                title: const Text('Do Not Disturb'),
                subtitle: const Text('Set quiet hours'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showDoNotDisturbDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Reset Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showResetDialog();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Notification Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
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

  void _showEmailFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Frequency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Daily'),
              leading: Radio<String>(
                value: 'Daily',
                groupValue: 'Daily',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Weekly'),
              leading: Radio<String>(
                value: 'Weekly',
                groupValue: 'Daily',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Monthly'),
              leading: Radio<String>(
                value: 'Monthly',
                groupValue: 'Daily',
                onChanged: (value) {},
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
                const SnackBar(content: Text('Email frequency updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePhoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Phone Number'),
        content: TextField(
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '+1 (555) 123-4567',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.phone),
          ),
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
                  content: Text('Phone number updated'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDoNotDisturbDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Do Not Disturb Hours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set your quiet hours when you don\'t want to be disturbed'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('From'),
                      DropdownButtonFormField<String>(
                        initialValue: '22:00',
                        items: ['20:00', '21:00', '22:00', '23:00'].map((time) {
                          return DropdownMenuItem(value: time, child: Text(time));
                        }).toList(),
                        onChanged: (value) {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('To'),
                      DropdownButtonFormField<String>(
                        initialValue: '07:00',
                        items: ['06:00', '07:00', '08:00', '09:00'].map((time) {
                          return DropdownMenuItem(value: time, child: Text(time));
                        }).toList(),
                        onChanged: (value) {},
                      ),
                    ],
                  ),
                ),
              ],
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
                const SnackBar(content: Text('Quiet hours set')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Notification Settings'),
        content: const Text('This will reset all notification settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pushNotifications = true;
                _emailNotifications = true;
                _smsNotifications = false;
                _rideRequests = true;
                _earningsUpdates = true;
                _promotionalOffers = false;
                _driverTips = true;
                _notificationSound = 'Default';
                _vibrateOnNotification = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings reset'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
