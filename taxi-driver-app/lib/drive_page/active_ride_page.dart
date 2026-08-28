import 'package:flutter/material.dart';

import 'ride_flow/ride_flow_navigator.dart';

/// Legacy entry — redirects into the multi-page ride workflow.
class ActiveRidePage extends StatefulWidget {
  final Map<String, dynamic>? rideData;

  const ActiveRidePage({super.key, this.rideData});

  @override
  State<ActiveRidePage> createState() => _ActiveRidePageState();
}

class _ActiveRidePageState extends State<ActiveRidePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RideFlowNavigator.open(context, widget.rideData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
