import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/widgets/taxi_ui.dart';

class IncomingRequestPage extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String passengerName;
  final String pickupLocation;
  final String dropLocation;
  final double distanceKm;
  final double price;

  final String paymentMethod;
  final double tripDistanceKm;
  final int estMinutes;

  const IncomingRequestPage({
    super.key,
    required this.onAccept,
    required this.onDecline,
    this.passengerName = 'Passenger',
    this.pickupLocation = "79, Industrial Estate, Perungudi",
    this.dropLocation = "Airport Terminal 1, Chennai",
    this.distanceKm = 12.5,
    this.price = 250.0,
    this.paymentMethod = 'CASH',
    this.tripDistanceKm = 0,
    this.estMinutes = 0,
  });

  String get _paymentLabel {
    switch (paymentMethod.toUpperCase()) {
      case 'ONLINE':
        return 'Razorpay Online';
      case 'UPI':
        return 'UPI / Online';
      default:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double tripKm = tripDistanceKm > 0 ? tripDistanceKm : distanceKm;
    final double distanceMiles = tripKm * 0.621371;
    final minutes = estMinutes > 0 ? estMinutes : (tripKm * 2).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardDarkElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: User Profile
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.gold,
                    child: Text(
                      passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: AppColors.scaffoldDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(TaxiIcons.star, color: AppColors.green, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "4.8",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _paymentLabel,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.greenDark),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "₹${price.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 18),

              // Route Diagram
              _buildLocationRow(
                icon: Icons.my_location,
                color: Colors.green,
                label: "Pickup",
                text: pickupLocation,
              ),
              _buildConnector(),
              _buildLocationRow(
                icon: Icons.location_on,
                color: Colors.red,
                label: "Drop-off",
                text: dropLocation,
              ),

              const SizedBox(height: 5),

              // Stats Row: Distance & Time
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.directions_car,
                      label: "Trip distance",
                      value:
                          "${tripKm.toStringAsFixed(1)} km\n(${distanceMiles.toStringAsFixed(1)} mi)",
                      color: AppColors.green,
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    _buildStatItem(
                      icon: Icons.access_time,
                      label: "Est. Time",
                      value: "$minutes min",
                      color: AppColors.green,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              TaxiFareBreakdown(
                distanceKm: tripKm,
                durationMin: minutes.toDouble(),
                compact: true,
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.red[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Decline",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.online,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Accept Ride',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [Icon(icon, color: color, size: 20)]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      margin: const EdgeInsets.only(left: 9.5, top: 2, bottom: 2),
      width: 1,
      height: 24,
      color: Colors.grey[300],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}
