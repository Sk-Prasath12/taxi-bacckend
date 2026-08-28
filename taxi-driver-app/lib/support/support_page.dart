import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/app_input_style.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final List<Map<String, dynamic>> _faqCategories = [
    {
      'icon': Icons.payment,
      'title': 'Payments & Earnings',
      'color': Colors.green,
      'questions': [
        'How do I receive payments?',
        'When will I get my earnings?',
        'How is commission calculated?',
        'Can I accept tips?',
      ],
    },
    {
      'icon': Icons.directions_car,
      'title': 'Rides & Trips',
      'color': AppColors.green,
      'questions': [
        'How do I accept ride requests?',
        'What if passenger cancels?',
        'How to contact passenger?',
        'Navigation and route help',
      ],
    },
    {
      'icon': Icons.account_circle,
      'title': 'Account & Profile',
      'color': Colors.purple,
      'questions': [
        'How to update profile info?',
        'Change vehicle details',
        'Upload documents',
        'Account verification',
      ],
    },
    {
      'icon': Icons.security,
      'title': 'Safety & Security',
      'color': Colors.red,
      'questions': [
        'Emergency assistance',
        'Report an incident',
        'Safety guidelines',
        'Insurance coverage',
      ],
    },
  ];

  final List<Map<String, dynamic>> _recentTickets = [
    {
      'id': '#SUP-78945',
      'subject': 'Payment not received',
      'status': 'open',
      'date': 'Mar 9, 2026',
      'response': 'pending',
    },
    {
      'id': '#SUP-78932',
      'subject': 'Unable to update vehicle',
      'status': 'closed',
      'date': 'Mar 5, 2026',
      'response': 'resolved',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              _startLiveChat();
            },
            tooltip: 'Live Chat',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppColors.cardDark,
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: AppColors.gold),
                  title: const Text('Admin: approve new drivers'),
                  subtitle: const Text('Show driver ID, approve account → ride booking works'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/admin-driver-approval'),
                ),
              ),
              const SizedBox(height: 16),
              // Emergency Contact
              _buildEmergencyContact(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Search Bar
              _buildSearchBar(),
              const SizedBox(height: 24),

              // FAQ Categories
              ..._faqCategories.map((category) => 
                _buildCategoryCard(category),
              ),
              const SizedBox(height: 24),

              // Recent Tickets
              _buildRecentTickets(),
              const SizedBox(height: 24),

              // Contact Options
              _buildContactOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContact() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[700]!, Colors.red[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency,
              color: AppColors.cardDark,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Assistance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '24/7 support for urgent issues',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Emergency Call'),
                        content: const Text(
                          'Do you want to call emergency support?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Calling emergency support...'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Call Now'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Emergency'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _buildQuickActionItem(
          icon: Icons.message,
          label: 'New Ticket',
          color: AppColors.green,
          onTap: () {
            _createSupportTicket();
          },
        ),
        _buildQuickActionItem(
          icon: Icons.history,
          label: 'My Tickets',
          color: Colors.purple,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Viewing ticket history')),
            );
          },
        ),
        _buildQuickActionItem(
          icon: Icons.article,
          label: 'Guidelines',
          color: AppColors.warning,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening guidelines')),
            );
          },
        ),
        _buildQuickActionItem(
          icon: Icons.phone_callback,
          label: 'Callback',
          color: Colors.green,
          onTap: () {
            _requestCallback();
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      style: AppInputStyle.field,
      decoration: InputDecoration(
        hintText: 'Search for help...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColors.cardDarkElevated,
        suffixIcon: IconButton(
          icon: const Icon(Icons.mic),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice search coming soon')),
            );
          },
        ),
      ),
      onChanged: (value) {
        // Implement search
      },
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    bool isExpanded = false;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (category['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    color: category['color'] as Color,
                    size: 24,
                  ),
                ),
                title: Text(
                  category['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: (category['questions'] as List).map((question) {
                      return ListTile(
                        leading: const Icon(Icons.help_outline, size: 20),
                        title: Text(question as String),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showAnswerDialog(question);
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTickets() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Tickets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Viewing all tickets')),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._recentTickets.map((ticket) => _buildTicketItem(ticket)),
        ],
      ),
    );
  }

  Widget _buildTicketItem(Map<String, dynamic> ticket) {
    Color statusColor;
    switch (ticket['status']) {
      case 'open':
        statusColor = AppColors.warning;
        break;
      case 'closed':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket['subject'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ticket['id']} • ${ticket['date']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (ticket['status'] as String).toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Us',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildContactOption(
          icon: Icons.email,
          title: 'Email Support',
          subtitle: 'support@taxiapp.com',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening email client...')),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.phone,
          title: 'Phone Support',
          subtitle: '+1 (555) 123-4567',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calling support...')),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.chat_bubble_outline,
          title: 'Live Chat',
          subtitle: 'Available 24/7',
          onTap: () {
            _startLiveChat();
          },
        ),
      ],
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showAnswerDialog(String question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lightbulb_outline, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(question)),
          ],
        ),
        content: const Text(
          'This is a sample answer. In production, this would connect to your FAQ database or knowledge base.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createSupportTicket();
            },
            child: const Text('Still Need Help?'),
          ),
        ],
      ),
    );
  }

  void _createSupportTicket() {
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
              const Text(
                'Create Support Ticket',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ticket submitted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit Ticket'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startLiveChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.support_agent, color: Colors.white),
            ),
            SizedBox(height: 16),
            Text('Connecting you to a support agent...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Starting chat session...')),
              );
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _requestCallback() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Callback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your phone number:'),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+1 (XXX) XXX-XXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Callback requested! We\'ll call you shortly.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}
