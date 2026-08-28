import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class LanguageRegionSettingsPage extends StatefulWidget {
  const LanguageRegionSettingsPage({super.key});

  @override
  State<LanguageRegionSettingsPage> createState() => _LanguageRegionSettingsPageState();
}

class _LanguageRegionSettingsPageState extends State<LanguageRegionSettingsPage> {
  String _language = 'English';
  String _currency = 'USD';
  String _region = 'United States';
  String _dateFormat = 'MM/DD/YYYY';
  String _timeFormat = '12-hour';
  String _distanceUnit = 'Miles';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language & Region'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Settings
            _buildSectionTitle('Language'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.translate, color: AppColors.green),
                ),
                title: const Text('App Language'),
                subtitle: Text(_language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showLanguageDialog();
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
                  child: const Icon(Icons.voice_over_off, color: Colors.green),
                ),
                title: const Text('Voice Language'),
                subtitle: const Text('Navigation voice prompts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening voice language settings...')),
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Region & Currency
            _buildSectionTitle('Region & Currency'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.public, color: AppColors.warning),
                ),
                title: const Text('Region'),
                subtitle: Text(_region),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showRegionDialog();
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
                title: const Text('Currency'),
                subtitle: Text(_currency),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showCurrencyDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Date & Time Format
            _buildSectionTitle('Date & Time'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppColors.blackLight),
                ),
                title: const Text('Date Format'),
                subtitle: Text(_dateFormat),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showDateFormatDialog();
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
                  child: const Icon(Icons.access_time, color: AppColors.green),
                ),
                title: const Text('Time Format'),
                subtitle: Text(_timeFormat),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showTimeFormatDialog();
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Units
            _buildSectionTitle('Units'),
            _buildSettingsCard([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.straighten, color: AppColors.green),
                ),
                title: const Text('Distance Unit'),
                subtitle: Text(_distanceUnit),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showDistanceUnitDialog();
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
                label: const Text('Reset to Defaults'),
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

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildLanguageOption('English', '🇺🇸'),
              _buildLanguageOption('Spanish', '🇪🇸'),
              _buildLanguageOption('French', '🇫🇷'),
              _buildLanguageOption('German', '🇩🇪'),
              _buildLanguageOption('Chinese', '🇨🇳'),
              _buildLanguageOption('Japanese', '🇯🇵'),
              _buildLanguageOption('Korean', '🇰🇷'),
              _buildLanguageOption('Portuguese', '🇵🇹'),
              _buildLanguageOption('Arabic', '🇸🇦'),
              _buildLanguageOption('Hindi', '🇮🇳'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String language, String flag) {
    final isSelected = _language == language;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(language),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          _language = language;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language changed to $language')),
        );
      },
    );
  }

  void _showRegionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Region'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildRegionOption('United States'),
              _buildRegionOption('Canada'),
              _buildRegionOption('United Kingdom'),
              _buildRegionOption('Australia'),
              _buildRegionOption('Germany'),
              _buildRegionOption('France'),
              _buildRegionOption('Spain'),
              _buildRegionOption('Mexico'),
              _buildRegionOption('Brazil'),
              _buildRegionOption('India'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionOption(String region) {
    final isSelected = _region == region;
    return ListTile(
      title: Text(region),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          _region = region;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Region changed to $region')),
        );
      },
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildCurrencyOption('USD', '\$'),
              _buildCurrencyOption('EUR', '€'),
              _buildCurrencyOption('GBP', '£'),
              _buildCurrencyOption('CAD', 'C\$'),
              _buildCurrencyOption('AUD', 'A\$'),
              _buildCurrencyOption('JPY', '¥'),
              _buildCurrencyOption('INR', '₹'),
              _buildCurrencyOption('MXN', '\$'),
              _buildCurrencyOption('BRL', 'R\$'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyOption(String currency, String symbol) {
    final isSelected = _currency == currency;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(currency),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          _currency = currency;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Currency changed to $currency')),
        );
      },
    );
  }

  void _showDateFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioOption('MM/DD/YYYY', '12/31/2024'),
            _buildRadioOption('DD/MM/YYYY', '31/12/2024'),
            _buildRadioOption('YYYY-MM-DD', '2024-12-31'),
            _buildRadioOption('DD MMM YYYY', '31 Dec 2024'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String value, String example) {
    final isSelected = _dateFormat == value;
    return RadioListTile<String>(
      title: Text(value),
      subtitle: Text('Example: $example'),
      value: value,
      groupValue: _dateFormat,
      onChanged: (newValue) {
        setState(() {
          _dateFormat = newValue!;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date format updated')),
        );
      },
    );
  }

  void _showTimeFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioOptionTime('12-hour', '2:30 PM'),
            _buildRadioOptionTime('24-hour', '14:30'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOptionTime(String value, String example) {
    final isSelected = _timeFormat == value;
    return RadioListTile<String>(
      title: Text(value),
      subtitle: Text('Example: $example'),
      value: value,
      groupValue: _timeFormat,
      onChanged: (newValue) {
        setState(() {
          _timeFormat = newValue!;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time format updated')),
        );
      },
    );
  }

  void _showDistanceUnitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Distance Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioOptionDistance('Miles', 'mi'),
            _buildRadioOptionDistance('Kilometers', 'km'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOptionDistance(String value, String abbreviation) {
    final isSelected = _distanceUnit == value;
    return RadioListTile<String>(
      title: Text(value),
      subtitle: Text('Abbreviation: $abbreviation'),
      value: value,
      groupValue: _distanceUnit,
      onChanged: (newValue) {
        setState(() {
          _distanceUnit = newValue!;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Distance unit updated')),
        );
      },
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('This will reset all language and region settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _language = 'English';
                _currency = 'USD';
                _region = 'United States';
                _dateFormat = 'MM/DD/YYYY';
                _timeFormat = '12-hour';
                _distanceUnit = 'Miles';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
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
