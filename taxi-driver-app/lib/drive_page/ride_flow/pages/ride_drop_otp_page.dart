import 'package:flutter/material.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';

/// Legacy route — drop OTP is on [RideDropReachedPage].
class RideDropOtpPage extends StatefulWidget {
  const RideDropOtpPage({super.key});

  @override
  State<RideDropOtpPage> createState() => _RideDropOtpPageState();
}

class _RideDropOtpPageState extends State<RideDropOtpPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RideFlowNavigator.go(context, RideFlowRoutes.dropReached);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
