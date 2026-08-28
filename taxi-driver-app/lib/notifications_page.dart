import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Sample notifications data
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'New Ride Request',
      'message': 'Pickup from 123 Main Street to Downtown Mall',
      'time': '2 min ago',
      'type': 'ride_request',
      'isRead': false,
      'icon': Icons.add_location,
      'color': AppColors.green,
    },
    {
      'id': 2,
      'title': 'Ride Completed',
      'message': 'You earned \$25.50 from your last ride',
      'time': '1 hour ago',
      'type': 'completed',
      'isRead': false,
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
    {
      'id': 3,
      'title': 'Payment Received',
      'message': 'Payment of \$18.75 has been processed',
      'time': '3 hours ago',
      'type': 'payment',
      'isRead': true,
      'icon': Icons.payment,
      'color': AppColors.green,
    },
    {
      'id': 4,
      'title': 'Peak Hours Alert',
      'message': 'High demand in your area! Earn up to 2x more',
      'time': '5 hours ago',
      'type': 'alert',
      'isRead': true,
      'icon': Icons.trending_up,
      'color': Colors.red,
    },
    {
      'id': 5,
      'title': 'New Message',
      'message': 'Support team: Your question has been answered',
      'time': 'Yesterday',
      'type': 'message',
      'isRead': true,
      'icon': Icons.message,
      'color': Colors.purple,
    },
    {
      'id': 6,
      'title': 'Weekly Summary',
      'message': 'You completed 42 rides this week. Great job!',
      'time': '2 days ago',
      'type': 'summary',
      'isRead': true,
      'icon': Icons.analytics,
      'color': Colors.teal,
    },
    {
      'id': 7,
      'title': 'Rating Update',
      'message': 'Your rating is now 4.9 stars',
      'time': '3 days ago',
      'type': 'rating',
      'isRead': true,
      'icon': Icons.star,
      'color': AppColors.warning,
    },
    {
      'id': 8,
      'title': 'System Update',
      'message': 'New features available. Update your app.',
      'time': '1 week ago',
      'type': 'system',
      'isRead': true,
      'icon': Icons.system_update,
      'color': Colors.grey,
    },
  ];

  bool _showOnlyUnread = false;

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_showOnlyUnread) {
      return _notifications.where((n) => !n['isRead']).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n['isRead']).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Mark all as read button
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () {
                setState(() {
                  for (var notification in _notifications) {
                    notification['isRead'] = true;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                  ),
                );
              },
              tooltip: 'Mark all as read',
            ),
          // Filter button
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _showOnlyUnread = value == 'unread';
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Notifications'),
              ),
              const PopupMenuItem(
                value: 'unread',
                child: Row(children: [Text('Unread')]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.notifications_active,
                  label: 'Total',
                  value: _notifications.length.toString(),
                  color: Theme.of(context).primaryColor,
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildStatItem(
                  icon: Icons.mark_email_read,
                  label: 'Unread',
                  value: unreadCount.toString(),
                  color: Colors.red,
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildStatItem(
                  icon: Icons.read_more,
                  label: 'Read',
                  value: (unreadCount - _notifications.length).abs().toString(),
                  color: Colors.green,
                ),
              ],
            ),
          ),
          // Notifications List
          Expanded(
            child: _filteredNotifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = _filteredNotifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isUnread = !notification['isRead'];

    return Dismissible(
      key: Key(notification['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text(
              'Are you sure you want to delete this notification?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        setState(() {
          _notifications.removeWhere((n) => n['id'] == notification['id']);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notification deleted')));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isUnread
              ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? Theme.of(context).primaryColor.withValues(alpha: 0.35)
                : AppColors.textMuted.withValues(alpha: 0.35),
            width: isUnread ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                notification['isRead'] = true;
              });
              _showNotificationDetails(notification);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon with background
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (notification['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      notification['icon'] as IconData,
                      color: notification['color'] as Color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification['title'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification['message'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notification['time'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Arrow indicator
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showOnlyUnread
                ? Icons.notifications_none
                : Icons.notifications_none,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            _showOnlyUnread
                ? 'No unread notifications'
                : 'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showOnlyUnread
                ? 'All caught up!'
                : 'When you get notifications, they\'ll appear here',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
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
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Icon
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: (notification['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification['icon'] as IconData,
                    color: notification['color'] as Color,
                    size: 35,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                notification['title'] as String,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Time
              Text(
                notification['time'] as String,
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              // Message
              Text(
                notification['message'] as String,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const Spacer(),
              // Action buttons
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
}
