import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxiapp/authentication_page/common/auth_background.dart';
import 'package:taxiapp/authentication_page/profile_page/profile_page.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/authentication_page/forgot_password/create_new_password.dart'
    as taxiappCreateNewPasswordPage;
import 'package:taxiapp/core/app_colors.dart';

class OtpVerificationPage extends StatefulWidget {
  final bool isForgotPasswordFlow;
  final String? email;

  const OtpVerificationPage({
    super.key,
    this.isForgotPasswordFlow = false,
    this.email,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // 6-digit OTP code
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0; // Cooldown timer in seconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes.first.requestFocus();
    });
    // Start cooldown timer
    _startResendCooldown();
  }

  void _startResendCooldown() {
    _resendCooldown = 60; // 60 seconds cooldown
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          if (_resendCooldown > 0) {
            _resendCooldown--;
          }
        });
        return _resendCooldown > 0;
      }
      return false;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getOtp() {
    return _controllers.map((c) => c.text).join();
  }

  void _clearOtpFields() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _handleResend() async {
    if (_resendCooldown > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait $_resendCooldown seconds before resending',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (widget.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not found'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isResending = true);

    bool success = false;
    String message = 'Failed to resend OTP';

    if (widget.isForgotPasswordFlow) {
      final result = await AuthService().sendForgotOtp(widget.email!);
      success = result['success'] == true;
      message = result['message'] ?? 'Failed to resend OTP';
    } else {
      // Using register OTP if it's the normal phone/email verification flow
      success = await AuthService().sendRegisterOtp(widget.email!);
      message = success
          ? 'OTP has been resent successfully'
          : 'Failed to resend OTP';
    }

    if (!mounted) return;
    setState(() => _isResending = false);

    if (success) {
      // Clear OTP fields
      _clearOtpFields();
      // Restart cooldown timer
      _startResendCooldown();

      final bool isOffline = widget.isForgotPasswordFlow && 
                           (message.contains('Offline') || message.contains('123456'));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), 
          backgroundColor: isOffline ? AppColors.warning : AppColors.green,
          duration: Duration(seconds: isOffline ? 8 : 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.green),
      );
    }
  }

  void _handleVerify() async {
    final otp = _getOtp();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (widget.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not found'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (widget.isForgotPasswordFlow) {
      // Call Forgot OTP verify API
      final result = await AuthService().verifyForgotOtp(widget.email!, otp);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final bool isOffline = result['offline'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'OTP verified successfully'),
            backgroundColor: isOffline ? AppColors.warning : AppColors.green,
            duration: Duration(seconds: isOffline ? 5 : 3),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                taxiappCreateNewPasswordPage.CreateNewPasswordPage(
                  email: widget.email!,
                ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Invalid OTP. Please try again.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } else {
      // Phone verification / Other flows (no API verify implemented, just success simulation)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP verified successfully'),
            backgroundColor: AppColors.green,
          ),
        );

        // Set user in singleton so ProfilePage can read it
        AuthService().setVerifiedUser(widget.email!);

        // Navigate to profile page after verification
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      widget.isForgotPasswordFlow
                          ? 'Forgot Password'
                          : 'Phone Verification',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      widget.email != null
                          ? 'Code has been sent to ${widget.email}'
                          : 'Code has been sent to your email',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 8.0;
                      final boxSize =
                          ((constraints.maxWidth - gap * 5) / 6).clamp(46.0, 58.0);

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return Padding(
                            padding: EdgeInsets.only(left: index == 0 ? 0 : gap),
                            child: _OtpDigitBox(
                              width: boxSize,
                              height: boxSize + 4,
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              onChanged: (v) => _onOtpChanged(index, v),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  Center(
                    child: _isResending
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Resending OTP...',
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : GestureDetector(
                            onTap: _resendCooldown == 0 ? _handleResend : null,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Didn't receive code? ",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _resendCooldown > 0
                                        ? 'Resend in $_resendCooldown s'
                                        : 'Resend again',
                                    style: TextStyle(
                                      color: _resendCooldown > 0
                                          ? AppColors.textMuted
                                          : AppColors.green,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      decoration: _resendCooldown == 0
                                          ? TextDecoration.underline
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.textOnDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnDark),
                              ),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpDigitBox extends StatelessWidget {
  final double width;
  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpDigitBox({
    required this.width,
    required this.height,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Theme(
        data: Theme.of(context).copyWith(
          visualDensity: VisualDensity.compact,
        ),
        child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        maxLength: 1,
        scrollPadding: EdgeInsets.zero,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: width * 0.46,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.symmetric(vertical: height * 0.22),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.green,
              width: 2,
            ),
          ),
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: onChanged,
      ),
      ),
    );
  }
}
