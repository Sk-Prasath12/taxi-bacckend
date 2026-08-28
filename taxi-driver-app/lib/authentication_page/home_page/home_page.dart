import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/authentication_page/common/auth_background.dart';
import 'package:taxiapp/authentication_page/log_in_page/login_page.dart';
import 'package:taxiapp/authentication_page/rigester_page/register_page.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  final AuthService authService;

  const HomePage({super.key, required this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  AnimationController? _wheelController;

  // Constants for positioning wheels (same as loading page)
  static const double _taxiWidth = 130.0;
  static const double _taxiHeight = 48.0;
  static const double _wheelSize = 19.0;
  static const double _rearWheelLeft = 21.0;
  static const double _frontWheelLeft = 97.0;
  static const double _wheelTop = 29.0;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _wheelController?.dispose();
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 800,
      ), // Faster spinning for better visibility
    )..repeat();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Only restart animation if controller exists, don't recreate during hot reload
    if (_wheelController != null && !_wheelController!.isAnimating) {
      _wheelController!.repeat();
    }
  }

  @override
  void dispose() {
    _wheelController?.dispose();
    _wheelController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scale the taxi to desired display size
    const double displayWidth = 200.0;
    const double scaleFactor = displayWidth / _taxiWidth;
    const double displayHeight = _taxiHeight * scaleFactor;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Images
          const AuthBackground(),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 120),
                        // Taxi with spinning wheels (same as loading page, no shake)
                        SizedBox(
                          width: displayWidth,
                          height: displayHeight,
                          child: _wheelController == null
                              ? Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Taxi Body
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      width: displayWidth,
                                      height: displayHeight,
                                      child: SvgPicture.asset(
                                        'assets/loading_page/taxi_loading.svg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    // Rear Wheel (Static when controller not ready)
                                    Positioned(
                                      left: _rearWheelLeft * scaleFactor,
                                      top: _wheelTop * scaleFactor,
                                      width: _wheelSize * scaleFactor,
                                      height: _wheelSize * scaleFactor,
                                      child: SvgPicture.asset(
                                        'assets/loading_page/wheel_animation.svg',
                                      ),
                                    ),
                                    // Front Wheel (Static when controller not ready)
                                    Positioned(
                                      left: _frontWheelLeft * scaleFactor,
                                      top: _wheelTop * scaleFactor,
                                      width: _wheelSize * scaleFactor,
                                      height: _wheelSize * scaleFactor,
                                      child: SvgPicture.asset(
                                        'assets/loading_page/wheel_animation.svg',
                                      ),
                                    ),
                                  ],
                                )
                              : AnimatedBuilder(
                                  animation: _wheelController!,
                                  builder: (context, child) {
                                    // Animation Loop using Sine waves for movement
                                    final double t =
                                        _wheelController!.value * 2 * math.pi;

                                    // Moving/Bouncing Effect:
                                    // Road Vibration (Vertical Bounce)
                                    final double roadVibration =
                                        math.sin(t * 1) * 0.5;

                                    // Subtle suspension sway
                                    final double suspension =
                                        math.sin(t * 0.8) * 0.3;

                                    // Combined bounce offset for smooth movement
                                    final double bounceOffset =
                                        roadVibration + suspension;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Taxi Body (Moving with bounce animation)
                                        Positioned(
                                          left: 0,
                                          top: bounceOffset,
                                          width: displayWidth,
                                          height: displayHeight,
                                          child: SvgPicture.asset(
                                            'assets/loading_page/taxi_loading.svg',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        // Rear Wheel (Spins continuously with animation)
                                        Positioned(
                                          left: _rearWheelLeft * scaleFactor,
                                          top:
                                              (_wheelTop * scaleFactor) +
                                              bounceOffset,
                                          width: _wheelSize * scaleFactor,
                                          height: _wheelSize * scaleFactor,
                                          child: Transform.rotate(
                                            angle:
                                                _wheelController!.value *
                                                2 *
                                                math.pi *
                                                2, // Faster spinning (2x speed)
                                            child: SvgPicture.asset(
                                              'assets/loading_page/wheel_animation.svg',
                                            ),
                                          ),
                                        ),
                                        // Front Wheel (Spins continuously with animation)
                                        Positioned(
                                          left: _frontWheelLeft * scaleFactor,
                                          top:
                                              (_wheelTop * scaleFactor) +
                                              bounceOffset,
                                          width: _wheelSize * scaleFactor,
                                          height: _wheelSize * scaleFactor,
                                          child: Transform.rotate(
                                            angle:
                                                _wheelController!.value *
                                                2 *
                                                math.pi *
                                                2, // Faster spinning (2x speed)
                                            child: SvgPicture.asset(
                                              'assets/loading_page/wheel_animation.svg',
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 80),
                        // Welcome Text (Centered)
                        Text(
                          'Welcome',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get started with your journey',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom buttons section
                Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  LoginPage(authService: widget.authService),
                            ),
                          );
                        },
                        icon: const Icon(Icons.local_taxi),
                        label: const Text('Driver App — Sign In'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sign Up Button
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RegisterPage(authService: widget.authService),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
