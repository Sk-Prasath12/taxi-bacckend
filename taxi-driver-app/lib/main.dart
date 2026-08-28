import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/authentication_page/auth_wrapper/auth_wrapper.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/customer/customer_auth_service.dart';
import 'package:taxiapp/config/env_config.dart';
import 'package:taxiapp/config/production_config_guard.dart';
import 'package:taxiapp/theme.dart';
import 'package:taxiapp/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release APKs must not fetch fonts from Google at startup — that crashes offline.
  GoogleFonts.config.allowRuntimeFetching = false;

  String? bootError;
  try {
    await EnvConfig.load();
    final configError = productionApiConfigError();
    if (configError != null) {
      bootError = configError;
      debugPrint(configError);
    }

    await Hive.initFlutter();
    await AuthService().init();
    await CustomerAuthService().init();
  } catch (e, st) {
    bootError = e.toString();
    debugPrint('App bootstrap failed: $e\n$st');
  }

  runApp(MyApp(bootError: bootError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.bootError});

  final String? bootError;

  @override
  Widget build(BuildContext context) {
    if (bootError != null) {
      return MaterialApp(
        title: 'Taxi Driver App',
        debugShowCheckedModeBanner: false,
        home: _BootErrorPage(message: bootError!),
      );
    }

    return MaterialApp(
      title: 'Taxi Driver App',
      debugShowCheckedModeBanner: false,
      theme: () {
        try {
          return AppTheme.darkTheme;
        } catch (e) {
          debugPrint('Theme failed, using fallback: $e');
          return ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.scaffoldDark,
            colorScheme: const ColorScheme.dark(primary: AppColors.green),
          );
        }
      }(),
      builder: (context, child) {
        return DefaultTextStyle(
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.35,
          ),
          child: IconTheme(
            data: const IconThemeData(color: AppColors.textPrimary),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: AuthWrapper(authService: AuthService()),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

class _BootErrorPage extends StatelessWidget {
  const _BootErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1F14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'App could not start',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Color(0xFFFFB4A8), fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              const Text(
                'Fix: rebuild the APK with your live API URL, then reinstall.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
