import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class DataStorageSettingsPage extends StatefulWidget {
  const DataStorageSettingsPage({super.key});

  @override
  State<DataStorageSettingsPage> createState() => _DataStorageSettingsPageState();
}

class _DataStorageSettingsPageState extends State<DataStorageSettingsPage> {
  String _cacheSize = '245 MB';
  final String _offlineMapsSize = '128 MB';
  final String _rideHistorySize = '56 MB';
  bool _autoClearCache = false;
  String _clearCacheFrequency = 'Weekly';
  bool _downloadOnWifi = true;
  String _storageLocation = 'Internal Storage';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Storage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Storage Overview
            _buildSectionTitle('Storage Overview'),
            _buildStorageCard(),
            
            const SizedBox(height: 24),
            
            // Cache Management
            _buildSectionTitle('Cache Management'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud_download_outlined, color: AppColors.green),
                ),
                title: const Text('Clear Cache'),
                subtitle: Text(_cacheSize),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showClearCacheDialog();
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.autorenew,
                title: 'Auto Clear Cache',
                subtitle: 'Automatically clear cache to free up space',
                value: _autoClearCache,
                onChanged: (value) {
                  setState(() {
                    _autoClearCache = value;
                  });
                },
              ),
              if (_autoClearCache) ...[
                const Divider(height: 1, indent: 72),
                _buildDropdownTile(
                  icon: Icons.schedule,
                  title: 'Clear Frequency',
                  value: _clearCacheFrequency,
                  items: ['Daily', 'Weekly', 'Monthly'],
                  onChanged: (value) {
                    setState(() {
                      _clearCacheFrequency = value!;
                    });
                  },
                ),
              ],
            ]),
            
            const SizedBox(height: 24),
            
            // Offline Content
            _buildSectionTitle('Offline Content'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map, color: Colors.green),
                ),
                title: const Text('Offline Maps'),
                subtitle: Text(_offlineMapsSize),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showOfflineMapsDialog();
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.wifi,
                title: 'Download on Wi-Fi Only',
                subtitle: 'Save mobile data by downloading only on Wi-Fi',
                value: _downloadOnWifi,
                onChanged: (value) {
                  setState(() {
                    _downloadOnWifi = value;
                  });
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Data Export
            _buildSectionTitle('Data Export'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.download_outlined, color: AppColors.warning),
                ),
                title: const Text('Export Ride History'),
                subtitle: Text('Download your complete ride history ($_rideHistorySize)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showExportDialog('Ride History');
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
                  child: const Icon(Icons.attach_money, color: Colors.green),
                ),
                title: const Text('Export Earnings Reports'),
                subtitle: const Text('Download earnings summaries'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showExportDialog('Earnings Reports');
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
                  child: const Icon(Icons.file_present_outlined, color: AppColors.blackLight),
                ),
                title: const Text('Export All Data'),
                subtitle: const Text('Complete data backup in JSON format'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showExportDialog('All Data');
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Storage Settings
            _buildSectionTitle('Storage Settings'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder, color: AppColors.green),
                ),
                title: const Text('Storage Location'),
                subtitle: Text(_storageLocation),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showStorageLocationDialog();
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
                  child: const Icon(Icons.analytics, color: AppColors.green),
                ),
                title: const Text('View Storage Details'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showStorageDetailsDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 32),
            
            // Reset Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showResetDialog();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Storage Settings'),
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

  Widget _buildStorageCard() {
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
      child: Column(
        children: [
          _buildStorageItem('Cache', _cacheSize, AppColors.green),
          const SizedBox(height: 16),
          _buildStorageItem('Offline Maps', _offlineMapsSize, Colors.green),
          const SizedBox(height: 16),
          _buildStorageItem('Ride History', _rideHistorySize, AppColors.warning),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Used',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _calculateTotal(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(String label, String size, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
        Text(
          size,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _calculateTotal() {
    // Simple calculation for demo purposes
    return '429 MB';
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

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear app cache? This will free up storage space but may slow down the app temporarily.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cacheSize = '0 MB';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showOfflineMapsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Maps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Downloaded maps:'),
            const SizedBox(height: 12),
            _buildMapItem('New York City', '45 MB'),
            _buildMapItem('Los Angeles', '38 MB'),
            _buildMapItem('Chicago', '25 MB'),
            _buildMapItem('San Francisco', '20 MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening map manager...')),
              );
            },
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapItem(String location, String size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.map, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(location),
            ],
          ),
          Text(size, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showExportDialog(String dataType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export $dataType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select export format:'),
            const SizedBox(height: 12),
            RadioListTile<String>(
              title: const Text('PDF'),
              value: 'PDF',
              groupValue: 'PDF',
              onChanged: (value) {},
            ),
            RadioListTile<String>(
              title: const Text('CSV'),
              value: 'CSV',
              groupValue: 'PDF',
              onChanged: (value) {},
            ),
            RadioListTile<String>(
              title: const Text('JSON'),
              value: 'JSON',
              groupValue: 'PDF',
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
                const SnackBar(
                  content: Text('Exporting data...'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showStorageLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Internal Storage'),
              subtitle: const Text('Default storage location'),
              value: 'Internal Storage',
              groupValue: _storageLocation,
              onChanged: (value) {},
            ),
            RadioListTile<String>(
              title: const Text('SD Card'),
              subtitle: const Text('Move app data to SD card'),
              value: 'SD Card',
              groupValue: _storageLocation,
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
                const SnackBar(content: Text('Storage location updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showStorageDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('App Size', '156 MB'),
              _buildDetailRow('Cache', _cacheSize),
              _buildDetailRow('Offline Maps', _offlineMapsSize),
              _buildDetailRow('Ride History', _rideHistorySize),
              _buildDetailRow('User Data', '24 MB'),
              const Divider(),
              _buildDetailRow('Total', _calculateTotal(), isBold: true),
            ],
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Storage Settings'),
        content: const Text('This will reset all storage settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _autoClearCache = false;
                _clearCacheFrequency = 'Weekly';
                _downloadOnWifi = true;
                _storageLocation = 'Internal Storage';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Storage settings reset'),
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
