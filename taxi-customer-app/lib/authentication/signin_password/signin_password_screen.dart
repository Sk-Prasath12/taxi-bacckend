import 'package:flutter/material.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/presentation/components/taxi_text_field.dart';
import 'package:taxi_user/services/auth_service.dart';
import 'package:taxi_user/services/ride_session_cleanup.dart';
import 'package:taxi_user/services/session_bootstrap.dart';

/// Password login — calls backend, saves session for auto-login, then goes to home.
class SigninPasswordScreen extends StatefulWidget {
  const SigninPasswordScreen({super.key});

  @override
  State<SigninPasswordScreen> createState() => _SigninPasswordScreenState();
}

class _SigninPasswordScreenState extends State<SigninPasswordScreen> {
  final _passwordController = TextEditingController();
  final bool _obscure = true;
  String? _error;
  String _identity = '';
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      _identity =
          args['email']?.toString() ?? args['identity']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final result = await AuthService.login(email: _identity, password: password);
      if (result['success'] != true) {
        throw Exception(result['message']?.toString() ?? 'Login failed');
      }

      final data = result['data'] as Map<String, dynamic>?;
      final token = data?['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Login failed: no token from server');
      }

      final user = data?['user'];
      final name = user is Map ? user['name']?.toString() : null;
      final email = user is Map ? user['email']?.toString() : _identity;
      final refreshToken = data?['refreshToken']?.toString();

      await SessionBootstrap.afterLogin(
        token: token,
        email: email ?? _identity,
        displayName: name,
        refreshToken: refreshToken,
        user: user is Map ? Map<String, dynamic>.from(user) : null,
        context: context,
      );

      if (!mounted) return;
      await RideSessionCleanup.resetForNewSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_error ?? 'Login failed'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Enter Password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your password for $_identity',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            TaxiTextField(
              label: 'Password',
              prefixIcon: Icons.lock,
              obscureText: _obscure,
              suffixIcon: _obscure ? Icons.visibility_off : Icons.visibility,
              controller: _passwordController,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/forgot-password',
                  arguments: {'identity': _identity},
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            TaxiButton(
              text: _loading ? 'Signing in...' : 'SIGN IN',
              color: const Color(0xFFFDB813),
              textColor: Colors.black,
              onPressed: _loading ? () {} : () => _onSignIn(),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text(
                  'New here? Create an account',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
