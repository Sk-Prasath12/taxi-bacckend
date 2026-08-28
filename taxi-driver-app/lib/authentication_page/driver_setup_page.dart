import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/services/driver_approval_watch_service.dart';
import 'package:taxiapp/services/driver_location_service.dart';
import 'package:taxiapp/services/driver_ride_listener_service.dart';
import 'package:taxiapp/services/driver_socket_service.dart';
import 'package:taxiapp/services/vehicle_type_service.dart';
import 'package:taxiapp/widgets/taxi_ui.dart';

/// Mandatory post-login flow:
/// 1) Vehicle model + number → Confirm
/// 2) Wait for admin approval (if needed)
/// 3) Go Online → then ride booking dashboard
class DriverSetupPage extends StatefulWidget {
  const DriverSetupPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<DriverSetupPage> createState() => _DriverSetupPageState();
}

class _DriverSetupPageState extends State<DriverSetupPage> {
  final _modelCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  String? _selectedVehicleTypeId;
  List<VehicleTypeOption> _vehicleTypes = const [];
  bool _loadingTypes = true;
  bool _saving = false;
  bool _goingOnline = false;
  String? _error;
  StreamSubscription? _approvalSub;
  StreamSubscription? _verificationSub;

  AuthService get _auth => widget.authService;

  int get _step {
    // Setup page is only shown when vehicle is missing.
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
    _modelCtrl.text = _auth.vehicleModel ?? '';
    _numberCtrl.text = _auth.vehicleNumber ?? '';
    _loadVehicleTypes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateExistingProfile());
    });
  }

  Future<void> _hydrateExistingProfile() async {
    await _auth.refreshProfileFromApi();
    if (!mounted) return;
    // If profile already has vehicle, AuthWrapper will route to Home.
    if (_auth.hasVehicleSetup) {
      setState(() {});
      return;
    }
    _modelCtrl.text = _auth.vehicleModel ?? _modelCtrl.text;
    _numberCtrl.text = _auth.vehicleNumber ?? _numberCtrl.text;
    _watchApproval();
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final types = await VehicleTypeService.fetchActive();
      if (!mounted) return;
      setState(() {
        _vehicleTypes = types;
        _selectedVehicleTypeId ??= types.isNotEmpty ? types.first.id : null;
        _loadingTypes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTypes = false);
    }
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  void _watchApproval() {
    if (_auth.canAcceptRides) return;
    DriverApprovalWatchService.instance.resetForNewSession();
    DriverApprovalWatchService.instance.start();
    _approvalSub ??= DriverApprovalWatchService.instance.onApproved.listen((_) {
      unawaited(_auth.refreshProfileFromApi());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin approved! Go online to receive bookings.'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    });
    unawaited(_connectSocketForApproval());
  }

  Future<void> _connectSocketForApproval() async {
    final token = _auth.token;
    final id = _auth.driverId;
    if (token == null || id == null || id.isEmpty) return;
    final fix = await DriverLocationService.instance.getFastFix();
    await DriverSocketService().connect(
      token: token,
      driverId: id,
      lat: fix?.latitude ?? 12.97,
      lng: fix?.longitude ?? 80.25,
    );
    _verificationSub ??= DriverSocketService().verificationStream.listen((_) {
      unawaited(_auth.refreshProfileFromApi());
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _approvalSub?.cancel();
    _verificationSub?.cancel();
    _modelCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmVehicle() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await _auth.saveVehicleDetails(
      model: _modelCtrl.text,
      number: _numberCtrl.text,
      vehicleTypeId: _selectedVehicleTypeId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Vehicle saved'), backgroundColor: AppColors.green),
    );
    _watchApproval();
  }

  Future<void> _goOnline() async {
    if (!_auth.canAcceptRides) {
      setState(() => _error = 'Wait for admin approval before going online.');
      return;
    }
    setState(() {
      _goingOnline = true;
      _error = null;
    });
    final ok = await DriverRideListenerService.instance.start();
    if (!mounted) return;
    setState(() => _goingOnline = false);
    if (!ok) {
      setState(() {
        _error = DriverRideListenerService.instance.lastError ??
            'Could not go online. Check location permission and try again.';
      });
      return;
    }
    await _auth.setWasOnDuty(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.hasVehicleSetup) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'New driver setup',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your vehicle type, model, and number once. Existing drivers with saved vehicle details skip this screen.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _vehicleStep(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _progress(int step) {
    Widget chip(int n, String label) {
      final done = step > n;
      final active = step == n;
      return Expanded(
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: done || active ? AppColors.green : AppColors.cardDarkElevated,
              child: Text(
                done ? '✓' : '$n',
                style: TextStyle(
                  color: done || active ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: active ? AppColors.green : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        chip(1, 'Vehicle'),
        chip(2, 'Admin'),
        chip(3, 'Online'),
      ],
    );
  }

  Widget _vehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select your vehicle model and enter the vehicle number. This is required before going online.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_loadingTypes)
          const Center(child: CircularProgressIndicator(color: AppColors.green))
        else if (_vehicleTypes.isEmpty)
          const Text(
            'Could not load vehicle types. Check internet and try again.',
            style: TextStyle(color: AppColors.danger),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedVehicleTypeId,
            dropdownColor: AppColors.cardDarkElevated,
            decoration: const InputDecoration(
              labelText: 'Vehicle type',
              border: OutlineInputBorder(),
            ),
            items: _vehicleTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      '${t.displayLabel} · ${t.maxPassengers} seats · ₹${t.perKmRate.toStringAsFixed(0)}/km',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedVehicleTypeId = v),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _modelCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Vehicle model *',
            hintText: 'e.g. Toyota Innova, Swift Dzire',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _numberCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Vehicle number / plate *',
            hintText: 'e.g. TN 09 AB 1234',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        TaxiPrimaryButton(
          label: _saving ? 'Saving…' : 'Save vehicle & continue',
          onPressed: _saving ? null : _confirmVehicle,
        ),
      ],
    );
  }

  Widget _adminStep() {
    final id = _auth.driverId ?? '—';
    final login = _auth.currentUser ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Waiting for admin approval',
                style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Login: $login', style: const TextStyle(color: AppColors.textPrimary)),
              Text('Driver ID: $id', style: const TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Ask admin to approve this Driver ID. After approval, this screen moves to Go Online automatically.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await _auth.refreshProfileFromApi();
            await DriverApprovalWatchService.instance.checkNow();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh approval status'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/documents'),
          child: const Text('Optional: upload documents'),
        ),
      ],
    );
  }

  Widget _onlineStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account approved',
                style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Vehicle: ${_auth.vehicleModel ?? "—"} · ${_auth.vehicleNumber ?? "—"}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap Go Online to receive nearby ride bookings and start the ride flow.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TaxiPrimaryButton(
          label: _goingOnline ? 'Going online…' : 'GO ONLINE',
          onPressed: _goingOnline ? null : _goOnline,
        ),
      ],
    );
  }
}
