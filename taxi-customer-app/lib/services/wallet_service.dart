import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../domain/services/auth_storage.dart';
import 'customer_auth_manager.dart';
import 'customer_session_store.dart';
import '../utils/ride_history_format.dart';
import 'session_service.dart';

class WalletTransaction {
  final String id;
  final String type; // 'credit', 'debit', 'refund', 'ride_payment'
  final double amount;
  final String description;
  final String? rideId;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.rideId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? json['transaction_type'] ?? 'debit').toString(),
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      description: (json['description'] ?? json['note'] ?? '').toString(),
      rideId: json['ride_id']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class WalletService {
  static void _logUrl(Uri url) {
    print('Calling API: $url');
  }

  static Future<String> _token() async {
    final token = await CustomerSessionStore.getAccessToken() ??
        await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return token;
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Get wallet balance from backend.
  static Future<double> getBalance() async {
    try {
      final token = await _token();
      final url = Uri.parse('${ApiConfig.baseUrl}/customers/wallet/balance');
      _logUrl(url);
      final response = await http.get(url, headers: _headers(token));
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Session expired');
      }
      if (response.statusCode != 200) return 0.0;
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return ((data['balance'] ?? data['wallet_balance'] ?? 0) as num)
            .toDouble();
      }
      return 0.0;
    } catch (e) {
      print('WalletService.getBalance: $e');
      return 0.0;
    }
  }

  /// Get wallet transactions from backend.
  static Future<List<WalletTransaction>> getTransactions() async {
    try {
      final token = await _token();
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/customers/wallet/transactions?limit=50');
      _logUrl(url);
      final response = await http.get(url, headers: _headers(token));
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Session expired');
      }
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final list = data is Map<String, dynamic>
          ? (data['transactions'] ?? data['data'] ?? [])
          : data;
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(WalletTransaction.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      print('WalletService.getTransactions: $e');
      return [];
    }
  }

  /// Build wallet transactions from ride history (fallback).
  static Future<List<WalletTransaction>> buildFromRideHistory(
      List<dynamic> rides) async {
    final transactions = <WalletTransaction>[];
    for (final ride in rides) {
      if (ride is! Map) continue;
      final m = Map<String, dynamic>.from(ride);
      final rideId = (m['ride_id'] ?? m['rideId'] ?? m['id'] ?? '').toString();
      final status = (m['status']?.toString() ?? '').toUpperCase();
      final fare = (m['fare'] ?? 0);
      final amount = fare is num ? fare.toDouble() : 0.0;
      final createdAt = m['createdAt'] != null
          ? DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now();

      if (status == 'COMPLETED' && amount > 0) {
        final pickup = RideHistoryFormat.addressFrom(m, nestedKey: 'pickup');
        final drop = RideHistoryFormat.addressFrom(m, nestedKey: 'drop');
        final driver = RideHistoryFormat.driverName(m);
        final when = RideHistoryFormat.formatDateTime(m);
        transactions.add(WalletTransaction(
          id: 'ride_$rideId',
          type: 'ride_payment',
          amount: amount,
          description: driver != null
              ? 'Ride · $pickup → $drop · $driver'
              : 'Ride · $pickup → $drop',
          rideId: rideId,
          createdAt: createdAt,
        ));
      }
    }
    // Sort newest first
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  static Future<void> _handleUnauthorized() async {
    final refreshed = await CustomerAuthManager.refreshAccessToken();
    if (refreshed) return;
    await CustomerAuthManager.logout();
    SessionService.redirectToLogin();
  }
}
