import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taxiapp/api/customer_api.dart';

class CustomerAuthService extends ChangeNotifier {
  static final CustomerAuthService _instance = CustomerAuthService._internal();
  factory CustomerAuthService() => _instance;
  CustomerAuthService._internal();

  Box<dynamic>? _box;
  String? token;
  String? userId;
  String? email;
  String? name;
  String? lastError;

  bool get isLoggedIn => token != null && userId != null;

  Future<void> init() async {
    _box = await Hive.openBox('customer_authbox');
    token = _box?.get('token') as String?;
    userId = _box?.get('userId') as String?;
    email = _box?.get('email') as String?;
    name = _box?.get('name') as String?;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    lastError = null;
    try {
      final result = await CustomerApi.withToken(null).login(email: email, password: password);
      if (result == null || result['token'] == null) {
        lastError = result?['message']?.toString() ?? 'Login failed';
        return false;
      }
      final user = result['user'] is Map ? result['user'] as Map : {};
      token = result['token'].toString();
      userId = (user['id'] ?? user['_id']).toString();
      this.email = user['email']?.toString() ?? email;
      name = user['name']?.toString();
      await _box?.putAll({'token': token, 'userId': userId, 'email': this.email, 'name': name});
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Cannot reach server. Is Docker backend running on port 3000?';
      if (kDebugMode) debugPrint('CustomerAuthService.login: $e');
      return false;
    }
  }

  Future<void> logout() async {
    token = null;
    userId = null;
    email = null;
    name = null;
    await _box?.clear();
    notifyListeners();
  }
}
