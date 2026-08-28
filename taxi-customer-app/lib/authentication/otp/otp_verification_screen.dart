import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxi_user/config/env_config.dart';
import 'package:taxi_user/presentation/components/app_screen_header.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/services/auth_service.dart';
import 'package:taxi_user/theme/app_theme.dart';

/// OTP verification — customer API (`/api/customers/register/*`).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String _flow = 'signup';
  String _identity = '';
  String _name = '';
  String _phone = '';
  String? _error;
  bool _loading = false;
  bool _focusedOnce = false;
  String? _displayedOtp;
  bool _otpPrefillApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final flow = args['flow']?.toString() ?? 'signup';
    final rawIdentity =
        args['identity']?.toString() ?? args['email']?.toString() ?? '';
    final identity = rawIdentity.trim().toLowerCase();
    final name = args['name']?.toString().trim() ?? '';
    final phone = args['phone']?.toString().trim() ?? '';
    final otpArg = args['otp']?.toString().trim() ?? '';

    if (flow == _flow &&
        identity == _identity &&
        name == _name &&
        phone == _phone &&
        _otpPrefillApplied) {
      return;
    }

    setState(() {
      _flow = flow;
      _identity = identity;
      _name = name;
      _phone = phone;
    });

    if (!_otpPrefillApplied && RegExp(r'^\d{6}$').hasMatch(otpArg)) {
      _otpPrefillApplied = true;
      _displayedOtp = otpArg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fillOtpDigits(otpArg);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusedOnce) return;
      _focusedOnce = true;
      _otpFocusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _subtitle {
    if (_identity.isEmpty) {
      return 'Enter the 6-digit code sent to your email';
    }
    return 'Enter the 6-digit code sent to $_identity';
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  void _fillOtpDigits(String digits) {
    for (var i = 0; i < 6; i++) {
      _otpControllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.length >= 6) {
      _otpFocusNodes[5].requestFocus();
    }
  }

  void _onOtpChanged(int index, String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 6) {
      _fillOtpDigits(digitsOnly.substring(0, 6));
      return;
    }
    if (value.length > 1) {
      final digit = value.substring(value.length - 1);
      _otpControllers[index].text = digit;
      _otpControllers[index].selection =
          const TextSelection.collapsed(offset: 1);
    }
    if (value.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        enabled: !_loading,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        maxLength: index == 0 ? 6 : 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppTheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
        onChanged: (value) => _onOtpChanged(index, value),
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (_loading) return;
    if (_identity.isEmpty) {
      setState(() => _error = 'Missing email. Please start sign up again.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });

    Map<String, dynamic> result;
    if (_flow == 'signup') {
      if (_name.isEmpty || _phone.isEmpty) {
        result = _failureResult('Missing signup details. Please start again.');
      } else {
        result = await AuthService.register(
          name: _name,
          email: _identity,
          phone: _phone,
        );
      }
    } else if (_flow == 'forgot-password') {
      result = await AuthService.sendForgotPasswordOtp(email: _identity);
    } else if (_flow == 'login') {
      result = _failureResult(
        'OTP login is not available. Sign in with password or complete sign up.',
      );
    } else {
      result = _failureResult('Unsupported flow');
    }

    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      final otpFromApi =
          data is Map ? data['otp']?.toString().trim() : null;
      if (otpFromApi != null && RegExp(r'^\d{6}$').hasMatch(otpFromApi)) {
        _displayedOtp = otpFromApi;
        _fillOtpDigits(otpFromApi);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            otpFromApi != null && otpFromApi.isNotEmpty
                ? 'OTP ready — enter the code shown (email may follow)'
                : 'OTP sent to your email',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      final message = (result['message'] ?? 'Failed to send OTP').toString();
      setState(() => _error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _failureResult(String message) => {
        'success': false,
        'message': message,
      };

  Future<void> _onVerify() async {
    if (_loading) return;
    if (_identity.isEmpty) {
      setState(() => _error = 'Missing email. Go back and sign up again.');
      return;
    }
    final otp = _otpValue.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    if (_flow == 'signup') {
      final result = await AuthService.verifyOtp(email: _identity, otp: otp);
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pushReplacementNamed(
          context,
          '/set-password',
          arguments: {'flow': 'signup', 'email': _identity},
        );
      } else {
        final message = (result['message'] ?? 'Verification failed').toString();
        setState(() => _error = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
        );
      }
    } else if (_flow == 'forgot-password') {
      final result =
          await AuthService.verifyForgotPasswordOtp(email: _identity, otp: otp);
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pushReplacementNamed(
          context,
          '/set-password',
          arguments: {'flow': 'reset', 'email': _identity, 'otp': otp},
        );
      } else {
        final message = (result['message'] ?? 'Verification failed').toString();
        setState(() => _error = message);
      }
    } else if (_flow == 'login') {
      setState(() => _error =
          'OTP login is not available. Use password sign in or finish sign up.');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final devHint = EnvConfig.devOtp;
    final missingSignupContext =
        _flow == 'signup' && (_identity.isEmpty || _name.isEmpty || _phone.isEmpty);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            title: 'Verify OTP',
            subtitle: _subtitle,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_displayedOtp != null && _displayedOtp!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your verification code',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _displayedOtp!,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 6,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Also check your email. You can use 123456 if needed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else if (devHint.isNotEmpty) ...[
                    Text(
                      'Development: use OTP $devHint if email is delayed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (missingSignupContext) ...[
                    Text(
                      'Sign-up details were lost. Go back and tap Continue again to receive a new code.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.danger,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TaxiButton(
                      text: 'BACK TO SIGN UP',
                      onPressed: () =>
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/signup',
                            (route) => route.isFirst || route.settings.name == '/welcome',
                          ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(6, _buildOtpBox),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    TaxiButton(
                      text: _loading ? 'Please wait...' : 'VERIFY',
                      onPressed: _loading ? () {} : _onVerify,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : _sendOtp,
                        child: const Text(
                          'Resend code',
                          style: TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
