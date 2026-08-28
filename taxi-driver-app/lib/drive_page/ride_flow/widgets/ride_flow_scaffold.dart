import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/utils/phone_actions.dart';
import 'package:taxiapp/widgets/taxi_ui.dart';

export 'package:taxiapp/utils/phone_actions.dart' show showPhoneActions, launchPhoneCall, launchSms;

class RideFlowScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? bottomButton;
  final bool canPop;

  const RideFlowScaffold({
    super.key,
    required this.title,
    required this.children,
    this.bottomButton,
    this.canPop = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppColors.black,
          leading: canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...children,
            if (bottomButton != null) ...[
              const SizedBox(height: 16),
              bottomButton!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Green primary CTA for ride-flow steps.
Widget rideFlowButton({required String label, required VoidCallback? onPressed, IconData? icon}) {
  return TaxiPrimaryButton(label: label, icon: icon ?? TaxiIcons.arrowForward, onPressed: onPressed);
}
