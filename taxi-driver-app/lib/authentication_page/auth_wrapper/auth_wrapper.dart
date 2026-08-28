import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/authentication_page/driver_setup_page.dart';
import 'package:taxiapp/authentication_page/log_in_page/login_page.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/customer/customer_auth_service.dart';
import 'package:taxiapp/customer/customer_home_page.dart';
import 'package:taxiapp/services/driver_approval_watch_service.dart';
import 'package:taxiapp/dashboard/dashboard_page.dart';

class AuthWrapper extends StatefulWidget {
  final AuthService authService;

  const AuthWrapper({
    super.key,
    required this.authService,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _customerAuth = CustomerAuthService();
  bool _bootstrapping = false;
  bool _bootstrapDone = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_onAuthChange);
    _customerAuth.addListener(_onAuthChange);
    _wasAuthenticated = widget.authService.isAuthenticated;
    if (widget.authService.isAuthenticated) {
      unawaited(_refreshSessionInBackground());
    } else {
      _bootstrapDone = true;
    }
  }

  Future<void> _refreshSessionInBackground() async {
    if (_bootstrapping) return;
    setState(() {
      _bootstrapping = true;
      _bootstrapDone = false;
    });
    try {
      await widget.authService.bootstrapSession();
      if (!widget.authService.canAcceptRides &&
          widget.authService.isAuthenticated &&
          widget.authService.hasVehicleSetup) {
        DriverApprovalWatchService.instance.resetForNewSession();
        DriverApprovalWatchService.instance.start();
      }
    } catch (e) {
      debugPrint('AuthWrapper bootstrapSession error: $e');
    }
    if (!mounted) return;
    setState(() {
      _bootstrapping = false;
      _bootstrapDone = true;
    });
  }

  @override
  void dispose() {
    widget.authService.removeListener(_onAuthChange);
    _customerAuth.removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    final auth = widget.authService;
    final nowAuth = auth.isAuthenticated;

    if (!nowAuth) {
      _bootstrapDone = true;
      _bootstrapping = false;
      _wasAuthenticated = false;
      if (mounted) setState(() {});
      return;
    }

    // Fresh login / register: restore profile before routing.
    if (!_wasAuthenticated && nowAuth) {
      _wasAuthenticated = true;
      unawaited(_refreshSessionInBackground());
      if (mounted) setState(() {});
      return;
    }

    _wasAuthenticated = true;
    if (mounted) setState(() {});
  }

  bool get _shouldShowLoading {
    final auth = widget.authService;
    if (!auth.isAuthenticated) return false;
    if (auth.sessionHydrating) return true;
    if (!_bootstrapDone || _bootstrapping) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    if (!auth.isAuthenticated) {
      if (_customerAuth.isLoggedIn) {
        return const CustomerHomePage();
      }
      return LoginPage(authService: auth);
    }

    if (_shouldShowLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.green),
        ),
      );
    }

    // Existing drivers with saved vehicle → Dashboard (Go Online lives there).
    // New drivers / missing vehicle → onboarding vehicle form only.
    if (auth.needsSetupWizard) {
      return DriverSetupPage(authService: auth);
    }
    return DashboardPage(authService: auth);
  }
}
