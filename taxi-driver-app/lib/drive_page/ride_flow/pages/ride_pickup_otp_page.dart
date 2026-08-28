import 'package:flutter/material.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';

/// Legacy route — pickup OTP is on [RideArrivedPage].
class RidePickupOtpPage extends StatefulWidget {
  const RidePickupOtpPage({super.key});

  @override
  State<RidePickupOtpPage> createState() => _RidePickupOtpPageState();
}

class _RidePickupOtpPageState extends State<RidePickupOtpPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RideFlowNavigator.go(context, RideFlowRoutes.arrived);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
