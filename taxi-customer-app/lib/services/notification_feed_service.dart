import 'package:intl/intl.dart';

import 'ride_service.dart';

/// Ride-derived notification feed (backend has no customer notification inbox API yet).
class NotificationFeedService {
  static Future<List<RideNotificationItem>> loadFromRideHistory() async {
    final rides = await RideService.getRideHistory();
    final items = <RideNotificationItem>[];

    for (final raw in rides) {
      if (raw is! Map) continue;
      final ride = Map<String, dynamic>.from(raw);
      final rideId = (ride['ride_id'] ?? ride['id'])?.toString() ?? '';
      if (rideId.isEmpty) continue;

      final status = (ride['status']?.toString() ?? '').toUpperCase();
      final createdAt = ride['createdAt']?.toString() ?? ride['created_at']?.toString();
      final driver = ride['driver'] is Map ? ride['driver'] as Map : null;
      final driverName = driver?['name']?.toString();
      final pickup = ride['pickup'] is Map ? (ride['pickup'] as Map)['address']?.toString() : null;

      final copy = _messageForStatus(status, driverName: driverName, pickup: pickup);
      if (copy == null) continue;

      items.add(RideNotificationItem(
        rideId: rideId,
        title: copy.$1,
        body: copy.$2,
        status: status,
        at: _parseDate(createdAt),
      ));
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  static DateTime _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static String formatRelative(DateTime at) {
    if (at.millisecondsSinceEpoch == 0) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(at);
  }

  static (String, String)? _messageForStatus(
    String status, {
    String? driverName,
    String? pickup,
  }) {
    final where = (pickup != null && pickup.isNotEmpty) ? ' from $pickup' : '';
    switch (status) {
      case 'SEARCHING_DRIVER':
        return ('Finding a driver', 'We are matching you with nearby drivers$where.');
      case 'DRIVER_ASSIGNED':
      case 'ACCEPTED':
        return (
          'Driver assigned',
          '${driverName ?? 'A driver'} accepted your ride$where.',
        );
      case 'ARRIVED_AT_PICKUP':
      case 'ARRIVED':
        return ('Driver arrived', '${driverName ?? 'Your driver'} is at the pickup point.');
      case 'STARTED':
      case 'PICKED_UP':
      case 'IN_TRANSIT':
      case 'IN_PROGRESS':
        return ('Ride in progress', 'Your trip is underway. Track live on the map.');
      case 'COMPLETED':
        return ('Ride completed', 'Trip finished. Complete payment and view your invoice.');
      case 'CANCELLED':
        return ('Ride cancelled', 'This booking was cancelled.');
      case 'PENDING_CONFIRMATION':
        return ('Booking created', 'Confirm your ride to search for drivers.');
      default:
        return null;
    }
  }
}

class RideNotificationItem {
  const RideNotificationItem({
    required this.rideId,
    required this.title,
    required this.body,
    required this.status,
    required this.at,
  });

  final String rideId;
  final String title;
  final String body;
  final String status;
  final DateTime at;
}
