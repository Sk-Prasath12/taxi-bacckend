import 'package:flutter/material.dart';

import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/dashboard/widgets/header/dashboard_header.dart';
import 'package:taxiapp/dashboard/widgets/map_background.dart';
import 'package:taxiapp/notifications_page.dart';

import 'package:latlong2/latlong.dart';

class DrivePage extends StatefulWidget {
  final String dropLocation;
  final String pickupLocation;
  final String? passengerName;
  final double? distanceKm;
  final double? price;
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;

  const DrivePage({
    super.key,
    required this.dropLocation,
    required this.pickupLocation,
    this.passengerName,
    this.distanceKm,
    this.price,
    this.pickupLatLng,
    this.dropLatLng,
  });

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  bool _isOnDuty = true; // Still on duty during drive
  bool _hasArrived = false;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _distanceKm = widget.distanceKm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Reused Map Background
          MapBackground(
            pickupPoint: widget.pickupLatLng,
            dropPoint: widget.dropLatLng,
            onDistanceCalculated: (dist) {
              if (mounted) {
                setState(() {
                  _distanceKm = dist;
                });
              }
            },
          ),

          // 2. Foreground Content
          SafeArea(
            child: Column(
              children: [
                // ... existing headers ...
                  DashboardHeader(
                    isOnDuty: _isOnDuty,
                    onDutyChanged: (val) {
                      setState(() => _isOnDuty = val);
                      // Handle ending duty logic if needed
                    },
                    onMenuPressed: () {
                      // Maybe disable menu during drive or show limited options
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Menu disabled during ride'),
                        ),
                      );
                    },
                    onHomePressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Home button disabled during active ride')),
                      );
                    },
                    onNotificationsPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsPage(),
                        ),
                      );
                    },
                  ),

                const Spacer(),

                // Bottom Location Indicator & Controls
                _buildBottomPanel(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      // ... existing decoration ...
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Destination Info
          Row(
            children: [
              // ... existing icon ...
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hasArrived ? Colors.red[50] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color: _hasArrived ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasArrived ? "Drop Location" : "Pickup Location",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasArrived ? widget.dropLocation : widget.pickupLocation,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${(_distanceKm ?? 4.2).toStringAsFixed(1)} km",
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Ride Progress",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _hasArrived ? "50%" : "0%",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _hasArrived ? 0.5 : 0.0,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (!_hasArrived) {
                  setState(() => _hasArrived = true);
                } else {
                  // Return true to indicate ride completion
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasArrived
                    ? Theme.of(context).colorScheme.primary
                    : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: Text(
                _hasArrived ? 'Complete Ride' : 'Arrived at Pickup',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
