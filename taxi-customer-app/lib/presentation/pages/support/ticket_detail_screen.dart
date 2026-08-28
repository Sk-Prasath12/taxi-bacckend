import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/support_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  SupportTicketDetail? _detail;
  bool _isLoading = true;
  bool _isSending = false;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final detail = await SupportService.getTicketById(widget.ticketId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await SupportService.replyToTicket(ticketId: widget.ticketId, message: message);
      _messageController.clear();
      _didChange = true;
      await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  bool _isCustomerMessage(SupportMessage message) {
    return message.senderRole == 'USER';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final ticket = detail?.ticket;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _didChange);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ticket Detail', style: TextStyle(color: Colors.black)),
          backgroundColor: const Color(0xFFFDB813),
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _didChange),
          ),
        ),
        backgroundColor: Colors.grey[100],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : detail == null || ticket == null
                ? const Center(child: Text('Unable to load ticket'))
                : Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.subject,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _categoryColor(ticket.category).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    ticket.category,
                                    style: TextStyle(
                                      color: _categoryColor(ticket.category),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  ticket.status,
                                  style: TextStyle(
                                    color: ticket.status == 'CLOSED'
                                        ? Colors.redAccent
                                        : Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(ticket.createdAt),
                                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          itemCount: detail.messages.length,
                          itemBuilder: (context, index) {
                            final message = detail.messages[index];
                            final isMine = _isCustomerMessage(message);
                            return Align(
                              alignment:
                                  isMine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine ? Colors.black : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isMine
                                      ? null
                                      : Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.message,
                                      style: TextStyle(
                                        color: isMine ? Colors.white : Colors.black87,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatDate(message.createdAt),
                                      style: TextStyle(
                                        color: isMine ? Colors.white70 : Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 4,
                                  enabled: !_isSending,
                                  decoration: InputDecoration(
                                    hintText: 'Type your message...',
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _isSending ? null : _sendMessage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: const Color(0xFFFDB813),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Send'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
