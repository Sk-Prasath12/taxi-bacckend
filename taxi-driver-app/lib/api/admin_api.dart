import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:taxiapp/api/api_constants.dart';

class AdminApi {
  final String adminKey;

  AdminApi({required this.adminKey});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-admin-key': adminKey,
      };

  Future<({List<Map<String, dynamic>> drivers, String? error})> fetchPending({String? q}) async {
    return _fetchList('/drivers/pending', q: q);
  }

  Future<({List<Map<String, dynamic>> drivers, String? error})> fetchApproved({String? q}) async {
    return _fetchList('/drivers/approved', q: q);
  }

  Future<({bool success, String? message})> approve(String driverId) async {
    try {
      final uri = Uri.parse('${ApiConstants.apiRestBase}/admin/drivers/$driverId/approve');
      final res = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'note': 'Approved from driver app admin screen'}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (success: true, message: body['message']?.toString());
      }
      return (success: false, message: body['message']?.toString() ?? 'Approve failed');
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  Future<({List<Map<String, dynamic>> drivers, String? error})> _fetchList(String path, {String? q}) async {
    try {
      var uri = Uri.parse('${ApiConstants.apiRestBase}/admin$path');
      if (q != null && q.trim().isNotEmpty) {
        uri = uri.replace(queryParameters: {'q': q.trim()});
      }
      final res = await http.get(uri, headers: _headers);
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300 && body is Map) {
        final data = body['data'];
        if (data is List) {
          return (
            drivers: data.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            error: null,
          );
        }
      }
      return (drivers: <Map<String, dynamic>>[], error: body['message']?.toString() ?? 'Request failed');
    } catch (e) {
      return (drivers: <Map<String, dynamic>>[], error: e.toString());
    }
  }

  Future<({bool success, String? message, Map<String, dynamic>? driver})> approveByLogin(
    String loginId,
  ) async {
    try {
      final uri = Uri.parse('${ApiConstants.apiRestBase}/admin/drivers/approve-by-login');
      final res = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'login_id': loginId}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300 && body is Map) {
        final driver = body['driver'];
        return (
          success: true,
          message: body['message']?.toString(),
          driver: driver is Map ? Map<String, dynamic>.from(driver) : null,
        );
      }
      return (success: false, message: body['message']?.toString() ?? 'Approve failed', driver: null);
    } catch (e) {
      return (success: false, message: e.toString(), driver: null);
    }
  }
}
