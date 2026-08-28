import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  bool _isDarkMode = false;
  String _appTheme = 'Light';
  double _textSize = 16.0;
  String _appIcon = 'Default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Section
            _buildSectionTitle('Theme'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Use dark theme throughout the app',
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildDropdownTile(
                icon: Icons.palette_outlined,
                title: 'App Theme',
                value: _appTheme,
                items: ['Light', 'Dark', 'System Default', 'Blue', 'Green'],
                onChanged: (value) {
                  setState(() {
                    _appTheme = value!;
                  });
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Display Section
            _buildSectionTitle('Display'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.text_fields, color: AppColors.green),
                ),
                title: const Text('Text Size'),
                subtitle: Text('${_textSize.toInt()}px'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showTextSizeSlider();
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildDropdownTile(
                icon: Icons.apps_outlined,
                title: 'App Icon',
                value: _appIcon,
                items: ['Default', 'Classic', 'Modern', 'Minimal'],
                onChanged: (value) {
                  setState(() {
                    _appIcon = value!;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App icon changed')),
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Map Display
            _buildSectionTitle('Map Display'),
            _buildSettingsCard([
              _buildDropdownTile(
                icon: Icons.map,
                title: 'Map Type',
                value: 'Standard',
                items: ['Standard', 'Satellite', 'Terrain', 'Hybrid'],
                onChanged: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Map type updated')),
                  );
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSwitchTile(
                icon: Icons.location_searching,
                title: 'Show Traffic',
                subtitle: 'Display traffic conditions on map',
                value: true,
                onChanged: (value) {},
              ),
            ]),
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

  void _showTextSizeSlider() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Text Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: _textSize,
              min: 12.0,
              max: 24.0,
              divisions: 12,
              label: '${_textSize.toInt()}px',
              onChanged: (value) {
                setState(() {
                  _textSize = value;
                });
              },
            ),
            Text('Preview: ${_textSize.toInt()}px',
                style: TextStyle(fontSize: _textSize)),
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
                  content: Text('Text size updated'),
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
}
