import 'package:flutter/material.dart';
import 'package:taxi_user/presentation/components/app_screen_header.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/presentation/components/taxi_text_field.dart';
import 'package:taxi_user/services/auth_service.dart';
import 'package:taxi_user/services/ride_session_cleanup.dart';
import 'package:taxi_user/services/session_bootstrap.dart';
import 'package:taxi_user/theme/app_theme.dart';

/// Password setup — calls backend setPassword (signup) or resetPassword (forgot).
class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _passwordController = TextEditingController();
  String _flow = 'signup';
  String _email = '';
  String? _error;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final flow = args['flow']?.toString() ?? 'signup';
    final email =
        (args['email']?.toString() ?? args['identity']?.toString() ?? '')
            .trim()
            .toLowerCase();

    if (flow == _flow && email == _email) return;

    setState(() {
      _flow = flow;
      _email = email;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String get _title => _flow == 'signup' ? 'Set password' : 'Reset password';
  String get _buttonText =>
      _flow == 'signup' ? 'CREATE ACCOUNT' : 'UPDATE PASSWORD';

  Future<void> _onSave() async {
    if (_loading) return;
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() => _error = 'Please enter a password');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (_email.isEmpty) {
      setState(() => _error = 'Session expired. Verify OTP and try again.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if (_flow == 'reset') {
        final result =
            await AuthService.setNewPassword(email: _email, password: password);
        if (result['success'] != true) {
          final message =
              (result['message'] ?? 'Failed to reset password').toString();
          if (!mounted) return;
          setState(() => _error = message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
          );
          return;
        }
      } else {
        final result =
            await AuthService.setPassword(email: _email, password: password);
        if (result['success'] != true) {
          final message =
              (result['message'] ?? 'Failed to save password').toString();
          if (!mounted) return;
          setState(() => _error = message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
          );
          return;
        }
        final data = result['data'] as Map<String, dynamic>?;
        final token = data?['token']?.toString();
        if (token != null && token.isNotEmpty) {
          final user = data?['user'];
          final name = user is Map ? user['name']?.toString() : null;
          final refreshToken = data?['refreshToken']?.toString();
          if (!mounted) return;
          await SessionBootstrap.afterLogin(
            token: token,
            email: _email,
            displayName: name,
            refreshToken: refreshToken,
            user: user is Map ? Map<String, dynamic>.from(user) : null,
            context: context,
          );
          if (!mounted) return;
          await RideSessionCleanup.resetForNewSession();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          return;
        }
        setState(() => _error =
            'Account could not be completed. Verify OTP again from sign up.');
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.primary,
              size: 56,
            ),
            title: const Text(
              'Password updated',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: const Text(
              'Your new password is saved. Sign in with your email and password.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Sign in',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
        arguments: {'email': _email},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'Failed to save password'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            title: _flow == 'reset' ? 'New password' : _title,
            subtitle: _email.isEmpty
                ? 'Create a password for your account'
                : _flow == 'reset'
                    ? 'Choose a new password for $_email'
                    : 'Create a password for $_email',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_email.isEmpty) ...[
                    Text(
                      'Email missing. Complete OTP verification first.',
                      style: TextStyle(color: AppTheme.danger, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TaxiButton(
                      text: 'BACK TO SIGN UP',
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                    ),
                  ] else ...[
                    TaxiTextField(
                      label: _flow == 'reset' ? 'New password' : 'Password',
                      hint: 'At least 8 characters',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: true,
                      controller: _passwordController,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: AppTheme.danger, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 32),
                    TaxiButton(
                      text: _loading ? 'Please wait...' : _buttonText,
                      onPressed: _loading ? () {} : _onSave,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
