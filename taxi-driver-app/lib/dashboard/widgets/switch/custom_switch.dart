import 'dart:math' as math;
import 'package:flutter/material.dart';

class CustomAnimatedSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomAnimatedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CustomAnimatedSwitch> createState() => _CustomAnimatedSwitchState();
}

class _CustomAnimatedSwitchState extends State<CustomAnimatedSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CustomAnimatedSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sizes (based on your original em → px conversion)
    const double switchWidth = 56.0;
    const double switchHeight = 32.0;
    const double sliderSize = 22.4;
    const double sliderOffset = 4.8;
    const double translateDistance = 24.0;

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: SizedBox(
        width: switchWidth,
        height: switchHeight,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Stack(
              children: [
                // Background
                Container(
                  width: switchWidth,
                  height: switchHeight,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFFB6B6B6), // OFF
                      const Color(0xFF21CC4C), // ON
                      _animation.value,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Knob (move + rotate)
                Positioned(
                  left:
                      sliderOffset + (_animation.value * translateDistance),
                  top: sliderOffset,
                  child: Transform.rotate(
                    angle: _animation.value * math.pi, // 180° rotation
                    child: Container(
                      width: sliderSize,
                      height: sliderSize,
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
