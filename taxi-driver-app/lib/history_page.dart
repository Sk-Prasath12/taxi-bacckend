import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/utils/phone_actions.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final token = AuthService().token;
    if (token == null) {
      setState(() {
        _rides = [];
        _loading = false;
      });
      return;
    }
    final list = await DriverApi.withToken(token).getRideHistory();
    if (!mounted) return;
    setState(() {
      _rides = list;
      _loading = false;
    });
  }

  String _pickupLabel(Map<String, dynamic> r) {
    final addr = r['pickupAddress']?.toString();
    if (addr != null && addr.isNotEmpty) return addr;
    final p = r['pickup'];
    if (p is Map && p['address'] != null) return p['address'].toString();
    if (p is String) return p;
    return 'Pickup';
  }

  String _dropLabel(Map<String, dynamic> r) {
    final addr = r['dropAddress']?.toString();
    if (addr != null && addr.isNotEmpty) return addr;
    final d = r['dropoff'] ?? r['drop'];
    if (d is Map && d['address'] != null) return d['address'].toString();
    if (d is String) return d;
    return 'Drop';
  }

  String _paymentLabel(Map<String, dynamic> r) {
    final m = (r['paymentMethod'] ?? r['payment_mode'] ?? 'CASH').toString();
    switch (m.toUpperCase()) {
      case 'RAZORPAY':
      case 'ONLINE':
        return 'Online / UPI';
      case 'UPI':
        return 'UPI';
      case 'GPAY':
        return 'Google Pay';
      case 'PHONEPE':
        return 'PhonePe';
      case 'CARD':
        return 'Card';
      default:
        return m;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = _rides.map((r) {
      final ts = DateTime.tryParse(
            r['completedAt']?.toString() ??
                r['time']?.toString() ??
                '',
          ) ??
          DateTime.now();
      final formattedDate = DateFormat('MMM d, y, h:mm a').format(ts.toLocal());
      final fare = (r['driverEarnings'] as num?)?.toDouble() ??
          (r['fare'] as num?)?.toDouble() ??
          0.0;
      return {
        'id': r['id'],
        'date': formattedDate,
        'customer': r['customerName'] ?? r['passengerName'] ?? 'Passenger',
        'customerPhone': r['customer_phone']?.toString() ?? '',
        'pickup': _pickupLabel(r),
        'dropoff': _dropLabel(r),
        'distance': r['distance']?.toString() ?? '—',
        'duration': r['duration_min'] != null ? '${r['duration_min']} min' : r['duration']?.toString() ?? '—',
        'fare': fare,
        'status': r['status'] ?? 'completed',
        'paymentMethod': _paymentLabel(r),
      };
    }).toList();

    final earnings = rides
        .where((r) => r['status'] == 'completed')
        .fold(0.0, (sum, r) => sum + (r['fare'] as double));

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        actions: [
          // Filter button
          PopupMenuButton<String>(
            onSelected: (value) {
              _showFilterOptions(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Rides')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  context,
                  label: 'Total Rides',
                  value: rides.length.toString(),
                  icon: Icons.directions_car,
                ),
                _buildSummaryItem(
                  context,
                  label: 'Earnings',
                  value: '₹${earnings.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
                _buildSummaryItem(
                  context,
                  label: 'Hours',
                  value: '3.9h',
                  icon: Icons.access_time,
                  color: AppColors.green,
                ),
              ],
            ),
          ),
          // List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Recent Rides',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Text(
                  '${rides.length} rides',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Rides List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rides.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ride = rides[index];
                return _buildRideCard(context, ride);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? Theme.of(context).primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? Theme.of(context).primaryColor,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    final String status = ride['status'] as String;
    final bool isCancelled = status == 'rejected' || status == 'cancelled';
    final bool isAccepted = status == 'accepted';
    final bool isPending = status == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showRideDetails(context, ride);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date and status
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride['date'] as String,
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? Colors.red.withValues(alpha: 0.1)
                            : isPending
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCancelled ? Colors.red : isPending ? AppColors.warning : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Route
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline line
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 40,
                          color: Colors.grey[300],
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Locations
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride['pickup'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ride['dropoff'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 12),
                // Footer with details
                Row(
                  children: [
                    // Distance and Duration
                    Row(
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ride['distance'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.timer, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          ride['duration'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Action Buttons for Pending or Fare
                    if (isPending) ...[
                      ElevatedButton(
                        onPressed: () {
                          AuthService().updateOrderStatus(ride['id'], 'accepted');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Accept', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          AuthService().updateOrderStatus(ride['id'], 'rejected');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.green,
                          side: const BorderSide(color: AppColors.green),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Reject', style: TextStyle(fontSize: 12)),
                      ),
                    ] else if (!isCancelled) ...[
                      Text(
                        '₹${ride['fare'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                    // Payment method icon
                    if (!isCancelled && ride['paymentMethod'] != null)
                      SizedBox(
                        width: 24,
                        child: Icon(
                          _getPaymentIcon(ride['paymentMethod'] as String),
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    // Rating
                    if (!isCancelled && ride['rating'] != null)
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Icon(Icons.star, size: 18, color: AppColors.green),
                          const SizedBox(width: 4),
                          Text(
                            ride['rating'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'digital':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  void _showRideDetails(BuildContext context, Map<String, dynamic> ride) {
    final bool isCancelled = ride['status'] == 'cancelled';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Status badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCancelled ? 'Cancelled Ride' : 'Completed Ride',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCancelled ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    ride['date'] as String,
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRouteDetailItem(
                icon: Icons.person,
                color: AppColors.green,
                label: 'Customer',
                value: ride['customer']?.toString() ?? 'Passenger',
              ),
              if ((ride['customerPhone']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showPhoneActions(
                      context,
                      ride['customerPhone'].toString(),
                      roleLabel: 'Customer',
                    ),
                    icon: const Icon(Icons.phone),
                    label: Text('Call ${ride['customerPhone']}'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Route section
              const Text(
                'Route Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildRouteDetailItem(
                icon: Icons.location_on,
                color: Colors.green,
                label: 'Pickup Location',
                value: ride['pickup'] as String,
              ),
              const SizedBox(height: 16),
              _buildRouteDetailItem(
                icon: Icons.flag,
                color: Colors.red,
                label: 'Drop-off Location',
                value: ride['dropoff'] as String,
              ),
              const SizedBox(height: 24),
              // Trip Info
              const Text(
                'Trip Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: ride['distance'] as String,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.timer,
                      label: 'Duration',
                      value: ride['duration'] as String,
                    ),
                  ),
                ],
              ),
              if (!isCancelled) ...[
                const SizedBox(height: 24),
                // Payment & Rating
                const Text(
                  'Payment & Rating',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: _getPaymentIcon(ride['paymentMethod'] as String),
                        label: 'Payment Method',
                        value: _getPaymentMethodName(
                          ride['paymentMethod'] as String?,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.attach_money,
                        label: 'Fare Amount',
                        value: '₹${ride['fare'].toStringAsFixed(2)}',
                        valueColor: AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (ride['rating'] != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: AppColors.green, size: 32),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Passenger Rating',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${ride['rating']}.0 out of 5.0',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 32),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteDetailItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String? method) {
    if (method == null) return 'N/A';
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Credit Card';
      case 'digital':
        return 'Digital Wallet';
      default:
        return method;
    }
  }

  void _showFilterOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Rides'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('All Rides'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Completed Only'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Cancelled Only'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Rides'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Enter location or date',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement search functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Searching for: ${searchController.text}'),
                ),
              );
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}
