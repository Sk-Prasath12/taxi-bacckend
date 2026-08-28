import 'package:flutter/material.dart';
import 'package:taxi_user/authentication/login/login_screen.dart';
import 'package:taxi_user/presentation/components/taxi_text_field.dart';
import 'package:taxi_user/services/auth_service.dart';

class ForgotPasswordSetPasswordScreen extends StatefulWidget {
  const ForgotPasswordSetPasswordScreen({super.key});

  @override
  State<ForgotPasswordSetPasswordScreen> createState() => _ForgotPasswordSetPasswordScreenState();
}

class _ForgotPasswordSetPasswordScreenState extends State<ForgotPasswordSetPasswordScreen> {
  final _passwordController = TextEditingController();
  String _email = '';
  String? _error;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _email = args?['email']?.toString() ?? '';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onResetPassword() async {
    if (_loading) return;
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Please enter a password');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_email.isEmpty) {
      setState(() => _error = 'Session expired. Please start again.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final result = await AuthService.setNewPassword(email: _email, password: password);
    if (!mounted) return;

    if (result['success'] == true) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Password reset successfully'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      final message = (result['message'] ?? 'Failed to reset password').toString();
      setState(() => _error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }

    if (mounted) setState(() => _loading = false);
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
              'Set New Password',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create a new password for your account',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 50),
            TaxiTextField(
              label: 'New Password',
              prefixIcon: Icons.lock,
              obscureText: true,
              suffixIcon: Icons.visibility_off,
              controller: _passwordController,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _loading ? null : _onResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDB813),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'RESET PASSWORD',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
