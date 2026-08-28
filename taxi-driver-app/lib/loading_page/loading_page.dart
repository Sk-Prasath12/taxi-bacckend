import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/widgets/taxi_loading.dart';

class LoadingPage extends StatefulWidget {
  final VoidCallback? onLoadingComplete;

  const LoadingPage({super.key, this.onLoadingComplete});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with TickerProviderStateMixin {
  AnimationController? _controller;

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
    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    if (widget.onLoadingComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onLoadingComplete != null) {
          widget.onLoadingComplete!();
        }
      });
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_controller != null && !_controller!.isAnimating) {
      _controller!.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double displayWidth = 300.0;
    const double scaleFactor = displayWidth / _taxiWidth;
    const double displayHeight = _taxiHeight * scaleFactor;

    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.scaffoldDark, AppColors.cardDark],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: displayWidth,
                    height: displayHeight,
                    child: _controller == null
                        ? const SizedBox.shrink()
                        : AnimatedBuilder(
                            animation: _controller!,
                            builder: (context, child) {
                              final double t = _controller!.value * 2 * math.pi;
                              final double roadVibration = math.sin(t * 1) * 0.5;
                              final double suspension = math.sin(t * 1) * 0.5;
                              final double bounceOffset = roadVibration + suspension;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0,
                                    top: bounceOffset,
                                    width: displayWidth,
                                    height: displayHeight,
                                    child: SvgPicture.asset(
                                      'assets/loading_page/taxi_loading.svg',
                                      fit: BoxFit.contain,
                                      colorFilter: const ColorFilter.mode(
                                        AppColors.gold,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: _rearWheelLeft * scaleFactor,
                                    top: (_wheelTop * scaleFactor) + bounceOffset,
                                    width: _wheelSize * scaleFactor,
                                    height: _wheelSize * scaleFactor,
                                    child: Transform.rotate(
                                      angle: _controller!.value * 2 * math.pi,
                                      child: SvgPicture.asset(
                                        'assets/loading_page/wheel_animation.svg',
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.textSecondary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: _frontWheelLeft * scaleFactor,
                                    top: (_wheelTop * scaleFactor) + bounceOffset,
                                    width: _wheelSize * scaleFactor,
                                    height: _wheelSize * scaleFactor,
                                    child: Transform.rotate(
                                      angle: _controller!.value * 2 * math.pi,
                                      child: SvgPicture.asset(
                                        'assets/loading_page/wheel_animation.svg',
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.textSecondary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  const TaxiLoader(size: 32),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading…',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
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
