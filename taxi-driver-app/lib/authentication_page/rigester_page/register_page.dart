import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/authentication_page/common/auth_background.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/widgets/taxi_loading.dart';
import 'package:taxiapp/widgets/taxi_ui.dart';

class RegisterPage extends StatefulWidget {
  final AuthService authService;

  const RegisterPage({super.key, required this.authService});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static final _loginInputTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.cardDarkElevated,
    prefixIconColor: AppColors.gold,
    labelStyle: const TextStyle(color: AppColors.gold),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppColors.radiusMd,
      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppColors.radiusMd,
      borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
    ),
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => taxiLoadingOverlay(message: 'Sending OTP…'),
    );

    bool otpSent = await widget.authService.sendRegisterOtp(email);

    if (!mounted) return;
    Navigator.pop(context);

    if (otpSent) {
      _showOtpDialog(email);
    } else {
      final message = widget.authService.lastError ??
          'Failed to send OTP. Please try again.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showOtpDialog(String email) {
    final otpController = TextEditingController(
      text: widget.authService.lastIssuedOtp ?? '',
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final outerContext = context;

    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardDark,
              title: const Text('Verify OTP', style: TextStyle(color: AppColors.gold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.authService.lastIssuedOtp != null
                        ? 'OTP ready for $email'
                        : 'Enter the OTP sent to $email',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (widget.authService.lastIssuedOtp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.authService.lastIssuedOtp!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'OTP',
                      labelStyle: const TextStyle(color: AppColors.gold),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                      ),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: TaxiLoader(),
                    )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final otp = otpController.text.trim();
                          if (otp.isEmpty) return;

                          setDialogState(() => isLoading = true);

                          bool verified = await widget.authService.verifyRegisterOtp(email, otp);

                          if (verified) {
                            bool passwordSet = await widget.authService.setPassword(
                              email,
                              _passwordController.text.trim(),
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            if (passwordSet) {
                              if (!outerContext.mounted) return;
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Registration successful!'),
                                  backgroundColor: AppColors.green,
                                ),
                              );
                              Navigator.of(outerContext).pop();
                            } else {
                              if (!outerContext.mounted) return;
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    widget.authService.lastError ?? 'Failed to set password.',
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() => isLoading = false);
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid OTP.'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Taxi Driver',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create your driver account',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: AppColors.radiusLg,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(inputDecorationTheme: _loginInputTheme),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fill in your details to get started',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(TaxiIcons.email),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(TaxiIcons.phone),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(TaxiIcons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? TaxiIcons.visibility
                                      : TaxiIcons.visibilityOff,
                                  color: AppColors.gold,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(TaxiIcons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? TaxiIcons.visibility
                                      : TaxiIcons.visibilityOff,
                                  color: AppColors.gold,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          TaxiPrimaryButton(
                            label: 'Sign Up',
                            icon: TaxiIcons.arrowForward,
                            onPressed: _handleRegister,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(color: AppColors.gold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
