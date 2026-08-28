import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../domain/services/auth_storage.dart';

class SupportTicket {
  final String id;
  final String subject;
  final String description;
  final String category;
  final String status;
  final String? rideId;
  final DateTime? createdAt;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    this.rideId,
    this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: (json['id'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'OTHER').toString().toUpperCase(),
      status: (json['status'] ?? 'OPEN').toString().toUpperCase(),
      rideId: json['ride_id']?.toString(),
      createdAt: _parseDate(json['createdAt']?.toString()),
    );
  }
}

class SupportMessage {
  final String senderRole;
  final String senderUserRole;
  final String message;
  final DateTime? createdAt;

  const SupportMessage({
    required this.senderRole,
    required this.senderUserRole,
    required this.message,
    this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      senderRole: (json['sender_role'] ?? 'USER').toString().toUpperCase(),
      senderUserRole: (json['sender_user_role'] ?? 'CUSTOMER').toString().toUpperCase(),
      message: (json['message'] ?? '').toString(),
      createdAt: _parseDate(json['createdAt']?.toString()),
    );
  }
}

class SupportTicketDetail {
  final SupportTicket ticket;
  final List<SupportMessage> messages;

  const SupportTicketDetail({
    required this.ticket,
    required this.messages,
  });
}

class SupportService {
  static Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return token;
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static String _extractMessage(http.Response response, String fallback) {
    try {
      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final message = data['message'] ?? data['error'] ?? data['msg'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      }
    } catch (_) {}
    return fallback;
  }

  static Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
    String? rideId,
  }) async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/support/tickets');
    final body = <String, dynamic>{
      'subject': subject.trim(),
      'description': description.trim(),
      'category': category.toUpperCase(),
    };
    if (rideId != null && rideId.trim().isNotEmpty) {
      body['ride_id'] = rideId.trim();
    }

    final response = await http.post(
      url,
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return SupportTicket.fromJson(data);
      }
      throw Exception('Invalid create ticket response');
    }

    throw Exception(_extractMessage(response, 'Failed to create ticket'));
  }

  static Future<List<SupportTicket>> getTickets() async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/support/tickets');

    final response = await http.get(url, headers: _headers(token));
    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to fetch tickets'));
    }

    final data = jsonDecode(response.body);
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(SupportTicket.fromJson)
          .toList();
    }
    throw Exception('Invalid tickets response');
  }

  static Future<SupportTicketDetail> getTicketById(String ticketId) async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/support/tickets/$ticketId');

    final response = await http.get(url, headers: _headers(token));
    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to fetch ticket'));
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid ticket detail response');
    }

    final ticketMap = data['ticket'];
    final messagesList = data['messages'];
    if (ticketMap is! Map<String, dynamic> || messagesList is! List) {
      throw Exception('Invalid ticket detail response');
    }

    return SupportTicketDetail(
      ticket: SupportTicket.fromJson(ticketMap),
      messages: messagesList
          .whereType<Map<String, dynamic>>()
          .map(SupportMessage.fromJson)
          .toList(),
    );
  }

  static Future<SupportMessage> replyToTicket({
    required String ticketId,
    required String message,
  }) async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/support/tickets/$ticketId/reply');

    final response = await http.post(
      url,
      headers: _headers(token),
      body: jsonEncode({'message': message.trim()}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['message'] is Map<String, dynamic>) {
        return SupportMessage.fromJson(data['message'] as Map<String, dynamic>);
      }
      throw Exception('Invalid reply response');
    }

    throw Exception(_extractMessage(response, 'Failed to send reply'));
  }
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value).toLocal();
  } catch (_) {
    return null;
  }
}
