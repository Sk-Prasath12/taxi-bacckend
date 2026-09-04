import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/ride_models.dart';
import '../../../config/api_config.dart';
import '../../../services/booking_draft_store.dart';
import '../../../services/ride_service.dart';
import '../../../services/route_service.dart';
import '../../../services/vehicle_types_cache.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/chennai_area.dart';
import '../../../utils/fare_calculator.dart';

class TaxiSelectionScreen extends StatefulWidget {
  const TaxiSelectionScreen({super.key});

  @override
  State<TaxiSelectionScreen> createState() => _TaxiSelectionScreenState();
}

class _TaxiSelectionScreenState extends State<TaxiSelectionScreen> {
  String? selectedTypeId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  bool _usingCachedVehicles = false;
  List<VehicleTypeModel> _vehicles = const [];
  double _distanceKm = 0;
  double _durationMin = 0;
  String _pickupLabel = '';
  String _dropLabel = '';

  static const Map<String, IconData> _iconByName = {
    'Bike': Icons.two_wheeler_rounded,
    'Auto': Icons.electric_rickshaw_rounded,
    '5 Seater': Icons.directions_car_filled_rounded,
    '7 Seater': Icons.airport_shuttle_rounded,
    'Mini': Icons.directions_car_filled_rounded,
    'Sedan': Icons.directions_car_filled_rounded,
    'SUV': Icons.airport_shuttle_rounded,
  };

  static const Map<String, IconData> _iconByCode = {
    'BIKE': Icons.two_wheeler_rounded,
    'AUTO': Icons.electric_rickshaw_rounded,
    'FIVE_SEATER': Icons.directions_car_filled_rounded,
    'SEVEN_SEATER': Icons.airport_shuttle_rounded,
    'MINI': Icons.directions_car_filled_rounded,
    'SEDAN': Icons.directions_car_filled_rounded,
    'SUV': Icons.airport_shuttle_rounded,
  };

  IconData _iconFor(VehicleTypeModel v) {
    final byCode = v.code != null ? _iconByCode[v.code!.toUpperCase()] : null;
    return byCode ?? _iconByName[v.name] ?? Icons.local_taxi_rounded;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadTripPreview(), _loadVehicles()]);
  }

  Future<void> _loadTripPreview() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    LatLng? pickup = args?['pickupLatLng'] is LatLng
        ? args!['pickupLatLng'] as LatLng
        : null;
    LatLng? drop = args?['dropoffLatLng'] is LatLng
        ? args!['dropoffLatLng'] as LatLng
        : null;
    _pickupLabel = args?['pickupAddress']?.toString() ??
        args?['pickup']?.toString() ??
        'Pickup';
    _dropLabel = args?['dropoffAddress']?.toString() ??
        args?['dropoff']?.toString() ??
        'Drop';

    if (pickup == null || drop == null) {
      final draft = await BookingDraftStore.load();
      if (draft != null) {
        final pLat = (draft['pickupLat'] as num?)?.toDouble();
        final pLng = (draft['pickupLng'] as num?)?.toDouble();
        final dLat = (draft['dropLat'] as num?)?.toDouble();
        final dLng = (draft['dropLng'] as num?)?.toDouble();
        if (pLat != null && pLng != null) pickup = LatLng(pLat, pLng);
        if (dLat != null && dLng != null) drop = LatLng(dLat, dLng);
        _pickupLabel = draft['pickupAddress']?.toString() ?? _pickupLabel;
        _dropLabel = draft['dropAddress']?.toString() ?? _dropLabel;
      }
    }

    if (pickup != null && drop != null) {
      try {
        final route = await RouteService().getRouteWithMetrics(
          startLat: pickup.latitude,
          startLng: pickup.longitude,
          endLat: drop.latitude,
          endLng: drop.longitude,
        );
        if (route != null && mounted) {
          setState(() {
            _distanceKm = route.distanceKm;
            _durationMin = route.durationMin;
          });
        } else if (mounted) {
          const dist = Distance();
          final km = dist.as(
            LengthUnit.Kilometer,
            LatLng(pickup.latitude, pickup.longitude),
            LatLng(drop.latitude, drop.longitude),
          );
          setState(() {
            _distanceKm = km;
            _durationMin = FareCalculator.estimateEtaMinutes(km);
          });
        }
      } catch (_) {
        const dist = Distance();
        final km = dist.as(
          LengthUnit.Kilometer,
          LatLng(pickup.latitude, pickup.longitude),
          LatLng(drop.latitude, drop.longitude),
        );
        if (mounted) {
          setState(() {
            _distanceKm = km;
            _durationMin = FareCalculator.estimateEtaMinutes(km);
          });
        }
      }
    }
  }

  Future<void> _loadVehicles() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _usingCachedVehicles = false;
      });
    }
    try {
      // Always prefer live catalog so Bike / Auto / 5 Seater / 7 Seater stay in sync.
      await VehicleTypesCache.clear();
      final list = await RideService.getVehicleTypes(allowCacheFallback: true);
      if (!mounted) return;
      setState(() {
        _vehicles = list;
        // Prefer 5 Seater as default when available; otherwise first catalog item.
        final preferred = list.where((v) {
          final code = v.code?.toUpperCase();
          return code == 'FIVE_SEATER' ||
              code == 'SEDAN' ||
              v.name == '5 Seater' ||
              v.name == 'Sedan';
        });
        selectedTypeId = preferred.isNotEmpty
            ? preferred.first.id
            : (list.isNotEmpty ? list.first.id : null);
        _usingCachedVehicles = RideService.lastVehicleLoadUsedCache;
        _loadError = RideService.lastVehicleLoadUsedCache
            ? RideService.lastVehicleLoadError
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vehicles = const [];
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  VehicleTypeModel? get _selected =>
      _vehicles.where((v) => v.id == selectedTypeId).cast<VehicleTypeModel?>().firstOrNull;

  double _estimateFare(VehicleTypeModel v) =>
      FareCalculator.calculateFare(_distanceKm, ratePerKmOverride: v.perKmRate);

  Future<void> _continueBooking() async {
    if (_isSubmitting || selectedTypeId == null) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    var pickup = args?['pickupAddress']?.toString() ?? '';
    var drop = args?['dropoffAddress']?.toString() ?? '';
    LatLng? pickupLatLng =
        args?['pickupLatLng'] is LatLng ? args!['pickupLatLng'] as LatLng : null;
    LatLng? dropoffLatLng =
        args?['dropoffLatLng'] is LatLng ? args!['dropoffLatLng'] as LatLng : null;

    if (pickupLatLng == null || dropoffLatLng == null) {
      final draft = await BookingDraftStore.load();
      if (draft != null) {
        final pLat = (draft['pickupLat'] as num?)?.toDouble();
        final pLng = (draft['pickupLng'] as num?)?.toDouble();
        final dLat = (draft['dropLat'] as num?)?.toDouble();
        final dLng = (draft['dropLng'] as num?)?.toDouble();
        if (pLat != null && pLng != null) {
          pickupLatLng = LatLng(pLat, pLng);
          pickup = draft['pickupAddress']?.toString() ?? pickup;
        }
        if (dLat != null && dLng != null) {
          dropoffLatLng = LatLng(dLat, dLng);
          drop = draft['dropAddress']?.toString() ?? drop;
        }
      }
    }

    // Use the pickup the customer selected on the map/search screen.
    // Do NOT replace it with live device GPS — nearby drivers must match
    // the chosen pickup pin, not the phone's current location.
    if (pickupLatLng == null || dropoffLatLng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup and drop are required')),
      );
      return;
    }
    if (!ChennaiArea.containsLatLng(pickupLatLng) ||
        !ChennaiArea.containsLatLng(dropoffLatLng)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChennaiArea.outOfAreaMessage)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ride = await RideService.createRide(
        pickupLat: pickupLatLng.latitude,
        pickupLng: pickupLatLng.longitude,
        dropLat: dropoffLatLng.latitude,
        dropLng: dropoffLatLng.longitude,
        pickupAddress: pickup,
        dropAddress: drop,
        vehicleTypeId: selectedTypeId!,
        paymentMode: 'CASH',
      );
      if (!mounted) return;
      final selectedVehicle = _vehicles.firstWhere((e) => e.id == selectedTypeId);
      final estimatedFare = FareCalculator.calculateFare(
        ride.distanceKm,
        ratePerKmOverride: selectedVehicle.perKmRate,
      );
      Navigator.pushNamed(
        context,
        '/booking-summary',
        arguments: {
          ...(args ?? {}),
          'pickupLatLng': pickupLatLng,
          'dropoffLatLng': dropoffLatLng,
          'pickupAddress': pickup,
          'dropoffAddress': drop,
          'pickup': pickup,
          'dropoff': drop,
          'taxiType': selectedVehicle.name,
          'vehicleTypeId': selectedVehicle.id,
          'vehicleCode': selectedVehicle.code,
          'maxPassengers': selectedVehicle.maxPassengers,
          'perKmRate': selectedVehicle.perKmRate,
          'rideId': ride.rideId,
          'distanceKm': ride.distanceKm,
          'durationMin': ride.durationMin,
          'fare': ride.fare > 0 ? ride.fare : estimatedFare,
          'otp': ride.otp,
          'paymentStatus': ride.paymentStatus,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride request failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final selectedFare = selected != null ? _estimateFare(selected) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _buildRouteCard(),
                        const SizedBox(height: 24),
                        const Text(
                          'Choose your ride',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _vehicles.isEmpty
                              ? 'Loading vehicle options…'
                              : '${_vehicles.length} vehicle types • Bike, Auto, 5 Seater, 7 Seater',
                          style: const TextStyle(
                            color: AppTheme.inkMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _vehicles.isEmpty
                              ? ''
                              : 'Fare = distance × rate (min 1 km for short trips)',
                          style: const TextStyle(
                            color: AppTheme.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_usingCachedVehicles)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                            ),
                            child: const Text(
                              'Using saved vehicle list — server was slow. Tap Retry if fares look wrong.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ),
                        if (_loadError != null && _vehicles.isEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cannot reach taxi server',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.danger,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _loadError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Server: ${ApiConfig.baseUrl}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Phone and PC must be on the same Wi‑Fi. Run .\\scripts\\sync-lan-ip.ps1 then restart the app.',
                                  style: TextStyle(fontSize: 11, color: AppTheme.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        if (_vehicles.isEmpty) ...[
                          Center(
                            child: TextButton.icon(
                              onPressed: _isLoading ? null : _loadVehicles,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(_isLoading ? 'Connecting…' : 'Retry'),
                            ),
                          ),
                        ],
                        ..._vehicles.map(_buildVehicleCard),
                      ],
                    ),
            ),
            _buildBottomBar(selectedFare),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Select Vehicle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          _routeRow(Icons.trip_origin_rounded, AppTheme.success, _pickupLabel, 'Pickup'),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Row(
              children: [
                Container(width: 2, height: 28, color: AppTheme.primary.withValues(alpha: 0.4)),
              ],
            ),
          ),
          _routeRow(Icons.location_on_rounded, AppTheme.danger, _dropLabel, 'Drop'),
          if (_distanceKm > 0) ...[
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricChip(Icons.route_rounded, FareCalculator.formatDistance(_distanceKm)),
                _metricChip(Icons.schedule_rounded, FareCalculator.formatDuration(_durationMin)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _routeRow(IconData icon, Color color, String label, String tag) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryDark),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildVehicleCard(VehicleTypeModel v) {
    final isSelected = selectedTypeId == v.id;
    final fare = _estimateFare(v);
    final icon = _iconFor(v);

    return GestureDetector(
      onTap: () => setState(() => selectedTypeId = v.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(selected: isSelected),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 36,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${v.maxPassengers} seats • ₹${v.perKmRate.toStringAsFixed(0)}/km',
                    style: const TextStyle(color: AppTheme.inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FareCalculator.formatFare(fare),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
                if (_distanceKm < 1)
                  const Text(
                    'min fare',
                    style: TextStyle(fontSize: 10, color: AppTheme.inkMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(double fare) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedTypeId != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selected?.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                Text(
                  FareCalculator.formatFare(fare),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: selectedTypeId == null ? null : AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(16),
                color: selectedTypeId == null ? Colors.grey.shade300 : null,
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting || selectedTypeId == null ? null : _continueBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isSubmitting ? 'CREATING RIDE...' : 'CONTINUE TO SUMMARY',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
