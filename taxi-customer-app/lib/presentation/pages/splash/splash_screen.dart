import 'package:flutter/material.dart';

import '../../../presentation/pages/auth/app_bootstrap_screen.dart';

/// Legacy splash route — delegates to [AppBootstrapScreen].
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBootstrapScreen();
  }
}
