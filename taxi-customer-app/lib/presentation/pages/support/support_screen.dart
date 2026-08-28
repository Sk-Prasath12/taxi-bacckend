import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/support_service.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const List<String> _filters = [
    'ALL',
    'PAYMENT',
    'RIDE',
    'TECHNICAL',
    'OTHER',
  ];

  List<SupportTicket> _tickets = <SupportTicket>[];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final tickets = await SupportService.getTickets();
      if (!mounted) return;
      setState(() => _tickets = tickets);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SupportTicket> get _filteredTickets {
    if (_selectedFilter == 'ALL') return _tickets;
    return _tickets.where((ticket) => ticket.category == _selectedFilter).toList();
    }

  Color _categoryColor(String category) {
    switch (category) {
      case 'PAYMENT':
        return Colors.blue;
      case 'RIDE':
        return Colors.green;
      case 'TECHNICAL':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Future<void> _openCreateTicket() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
    );
    if (created == true) {
      await _loadTickets();
    }
  }

  Future<void> _openTicketDetail(SupportTicket ticket) async {
    final shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(ticketId: ticket.id),
      ),
    );
    if (shouldRefresh == true) {
      await _loadTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleTickets = _filteredTickets;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFDB813),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          SizedBox(
            height: 64,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  selectedColor: const Color(0xFFFDB813),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFFDB813) : Colors.grey.shade300,
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: Colors.black87,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTickets,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleTickets.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(
                              child: Text(
                                'No support tickets yet',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: visibleTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = visibleTickets[index];
                            final categoryColor = _categoryColor(ticket.category);
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openTicketDetail(ticket),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ticket.subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          ticket.status,
                                          style: TextStyle(
                                            color: ticket.status == 'CLOSED'
                                                ? Colors.redAccent
                                                : Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: categoryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            ticket.category,
                                            style: TextStyle(
                                              color: categoryColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatDate(ticket.createdAt),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      ticket.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTicket,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Color(0xFFFDB813)),
        label: const Text(
          'Create Ticket',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
