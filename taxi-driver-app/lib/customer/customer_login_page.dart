import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/customer/customer_auth_service.dart';
import 'package:taxiapp/core/app_input_style.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _email = TextEditingController(text: 'sk2011@yopmail.com');
  final _password = TextEditingController(text: 'Sk@123456');
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final ok = await CustomerAuthService().login(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CustomerAuthService().lastError ?? 'Login failed'), backgroundColor: AppColors.green),
      );
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer App')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Book a ride', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Login to request and confirm rides. Driver app will receive live requests.'),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              style: AppInputStyle.field,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              style: AppInputStyle.field,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
