import 'package:flutter/material.dart';

import '../../../services/notification_feed_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<RideNotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await NotificationFeedService.loadFromRideHistory();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  IconData _iconFor(String status) {
    switch (status) {
      case 'COMPLETED':
        return Icons.check_circle_outline;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'DRIVER_ASSIGNED':
      case 'ACCEPTED':
        return Icons.directions_car;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFDB813),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('No notifications yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final n = _items[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/ride-history-detail',
                                arguments: {'rideId': n.rideId},
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDB813).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_iconFor(n.status), color: const Color(0xFFFDB813)),
                              ),
                              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(n.body),
                              trailing: Text(
                                NotificationFeedService.formatRelative(n.at),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
