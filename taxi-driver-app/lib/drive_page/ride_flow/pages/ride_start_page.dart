import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';

/// Legacy route — trip starts automatically after pickup OTP.
class RideStartPage extends StatefulWidget {
  const RideStartPage({super.key});

  @override
  State<RideStartPage> createState() => _RideStartPageState();
}

class _RideStartPageState extends State<RideStartPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RideFlowNavigator.go(context, RideFlowRoutes.ongoing);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.green)),
    );
  }
}
