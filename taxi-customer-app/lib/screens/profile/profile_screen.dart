import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/app_user.dart';
import '../../domain/services/auth_storage.dart';
import '../../presentation/components/app_loading.dart';
import '../../services/customer_auth_manager.dart';
import '../../services/customer_session_store.dart';
import '../../services/profile_service.dart';
import '../../services/ride_session_cleanup.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  /// When true, only the scrollable body is built (no [Scaffold]/[AppBar]) for use inside [HomeScreen].
  final bool embedInShell;

  const ProfileScreen({super.key, this.embedInShell = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailDisplayController = TextEditingController();

  final _pwdEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _loadingProfile = true;
  bool _updatingProfile = false;
  bool _changingPassword = false;

  String _displayName = '';
  String _displayEmail = '';
  String _customerId = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailDisplayController.dispose();
    _pwdEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _applyToForm({
    required String name,
    required String email,
    String? phone,
    String? customerId,
  }) {
    _nameController.text = name;
    _phoneController.text = phone ?? '';
    _emailDisplayController.text = email;
    _pwdEmailController.text = email;
    _displayName = name;
    _displayEmail = email;
    _customerId = customerId ?? '';
    AppUser.displayName = name;
    AppUser.email = email;
    AppUser.phoneNumber = phone ?? '';
    if (customerId != null) AppUser.customerId = customerId;
  }

  Future<void> _loadCachedProfile() async {
    final session = await CustomerSessionStore.loadSession();
    if (session != null) {
      _applyToForm(
        name: session['name']?.toString() ?? AppUser.displayName,
        email: session['email']?.toString() ?? AppUser.email,
        phone: session['phone']?.toString(),
        customerId: session['customerId']?.toString(),
      );
      return;
    }
    final cached = await AuthStorage.getProfileJson();
    if (cached != null) {
      _applyToForm(
        name: cached['name']?.toString() ?? AppUser.displayName,
        email: cached['email']?.toString() ?? AppUser.email,
        phone: cached['phone']?.toString(),
        customerId: cached['id']?.toString(),
      );
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    await _loadCachedProfile();
    if (mounted) setState(() {});

    try {
      final profile = await ProfileService.getProfile();
      if (!mounted) return;
      _applyToForm(
        name: profile.name,
        email: profile.email,
        phone: profile.phone,
        customerId: profile.id,
      );
      await CustomerAuthManager.syncProfileMap({
        'id': profile.id,
        'name': profile.name,
        'email': profile.email,
        'phone': profile.phone ?? '',
        'role': 'customer',
      });
    } catch (e) {
      if (!mounted) return;
      if (_displayName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _avatarLetter(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  Future<void> _submitProfile() async {
    final form = _profileFormKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _updatingProfile = true);
    try {
      final updated = await ProfileService.updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      _applyToForm(
        name: updated.name,
        email: updated.email,
        phone: updated.phone,
        customerId: updated.id,
      );
      await CustomerAuthManager.syncProfileMap({
        'id': updated.id,
        'name': updated.name,
        'email': updated.email,
        'phone': updated.phone ?? '',
        'role': 'customer',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _updatingProfile = false);
    }
  }

  Future<void> _submitPassword() async {
    final form = _passwordFormKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _changingPassword = true);
    try {
      await ProfileService.changePassword(
        email: _pwdEmailController.text,
        oldPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: child,
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingProfile) {
      return const Center(child: AppLoading(message: 'Loading profile…', size: 44));
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedInShell)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Text(
                  'Profile',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primary,
                child: Text(
                  _avatarLetter(_displayName.isNotEmpty ? _displayName : _nameController.text),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _displayName.isNotEmpty ? _displayName : _nameController.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _displayEmail.isNotEmpty ? _displayEmail : _emailDisplayController.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            if (_customerId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'ID: $_customerId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 24),
            Form(
              key: _profileFormKey,
              child: _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Profile settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration('Name'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name is required';
                        if (v.trim().length < 2) return 'Name must be at least 2 characters';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _fieldDecoration('Phone'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone is required';
                        if (v.trim().length != 10) return 'Phone must be 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailDisplayController,
                      style: const TextStyle(color: AppTheme.textSecondary),
                      readOnly: true,
                      decoration: _fieldDecoration('Email'),
                    ),
                    const SizedBox(height: 20),
                    _primaryButton(
                      label: 'Save Profile',
                      loading: _updatingProfile,
                      onPressed: _submitProfile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _passwordFormKey,
              child: _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pwdEmailController,
                      style: const TextStyle(color: AppTheme.textSecondary),
                      readOnly: true,
                      decoration: _fieldDecoration('Email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _currentPasswordController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      obscureText: true,
                      decoration: _fieldDecoration('Current Password'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Current password is required';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      obscureText: true,
                      decoration: _fieldDecoration('New Password'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'New password is required';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _primaryButton(
                      label: 'Update Password',
                      loading: _changingPassword,
                      onPressed: _submitPassword,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: AppTheme.danger),
                foregroundColor: AppTheme.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Log out?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'You will need to sign in again to use the app.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await CustomerAuthManager.logout();
    await RideSessionCleanup.resetForNewSession();
    SocketService.instance.disconnect();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedInShell) {
      return ColoredBox(
        color: AppTheme.background,
        child: _buildBody(),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(),
    );
  }
}
