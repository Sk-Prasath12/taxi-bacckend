import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taxiapp/api/api_client.dart';
import 'package:taxiapp/api/api_constants.dart';
import 'package:taxiapp/services/active_ride_store.dart';
import 'package:taxiapp/services/driver_ride_listener_service.dart';
import 'package:taxiapp/services/driver_session_store.dart';
import 'package:taxiapp/utils/jwt_utils.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  Box<dynamic>? _authBox;
  Box<dynamic>? _ordersBox;
  bool _sessionBootstrapping = false;

  ApiClient get _apiClient => ApiClient(authToken: token);
  ApiClient get _publicApiClient => ApiClient();

  String? token;
  String? refreshToken;
  String? driverId;
  String? currentUser;
  String? currentUserName;
  String? phone;
  String? profileImagePath;
  List<String> imageGallery = [];
  List<Map<dynamic, dynamic>> allOrders = [];
  String? lastError;
  String? lastIssuedOtp;
  String? lastDriverStatusError;
  bool isDriverVerified = false;
  String driverVerificationStatus = 'NOT_SUBMITTED';
  String? vehicleModel;
  String? vehicleNumber;
  String? vehicleType;
  bool vehicleSetupComplete = false;
  /// True after driver completes mandatory Go Online (persisted as was_on_duty).
  bool resumeOnline = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty && currentUser != null;

  bool get isAuthenticated => isLoggedIn;

  bool get hasVehicleSetup {
    if (vehicleSetupComplete) {
      final model = (vehicleModel ?? '').trim();
      final number = (vehicleNumber ?? '').trim().toUpperCase();
      // Ignore placeholder values created by incomplete server stubs.
      if (number == 'PENDING' || model.toLowerCase() == 'to be updated') {
        return false;
      }
      return model.length >= 2 && number.length >= 4;
    }
    final model = (vehicleModel ?? '').trim();
    final number = (vehicleNumber ?? '').trim().toUpperCase();
    if (number == 'PENDING' || model.toLowerCase() == 'to be updated') {
      return false;
    }
    return model.length >= 2 && number.length >= 4;
  }

  /// Ready for live bookings: vehicle saved + admin approved.
  bool get canAcceptRides {
    if (!hasVehicleSetup) return false;
    final status = driverVerificationStatus.toUpperCase();
    if (isDriverVerified && status == 'APPROVED') return true;
    if (isDriverVerified || status == 'APPROVED') return true;
    return false;
  }

  /// Needs vehicle onboarding only (admin wait / go-online happen on Home).
  bool get needsSetupWizard => isAuthenticated && !hasVehicleSetup;

  /// True while validating token + loading profile after login/cold start.
  bool sessionHydrating = false;

  void _applyVerificationFromMap(Map<String, dynamic> driverMap) {
    isDriverVerified = driverMap['is_driver_verified'] == true ||
        (driverMap['driver_verification_status']?.toString().toUpperCase() == 'APPROVED');
    driverVerificationStatus =
        (driverMap['driver_verification_status'] ?? driverVerificationStatus).toString();
  }

  void _applyVehicleFromMap(Map<String, dynamic> driverMap) {
    final details = driverMap['vehicleDetails'];
    if (details is Map) {
      vehicleModel = details['model']?.toString() ?? vehicleModel;
      vehicleNumber = details['plateNumber']?.toString() ??
          details['vehicle_number']?.toString() ??
          vehicleNumber;
      vehicleType = details['type']?.toString() ?? vehicleType;
    }
    vehicleModel = driverMap['vehicle_model']?.toString() ?? vehicleModel;
    vehicleNumber = driverMap['vehicle_number']?.toString() ??
        driverMap['vehicle_reg_number']?.toString() ??
        vehicleNumber;
    vehicleType = driverMap['vehicle_type']?.toString() ??
        driverMap['vehicle_type_name']?.toString() ??
        vehicleType;
    // Never treat Mongo ObjectId as a display vehicle type name.
    if (vehicleType != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vehicleType!)) {
      vehicleType = driverMap['vehicle_type_name']?.toString() ?? vehicleType;
      if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vehicleType!)) {
        vehicleType = null;
      }
    }

    final model = (vehicleModel ?? '').trim();
    final number = (vehicleNumber ?? '').trim().toUpperCase();
    final looksReal =
        model.length >= 2 &&
        number.length >= 4 &&
        number != 'PENDING' &&
        model.toLowerCase() != 'to be updated';

    if (driverMap['vehicle_setup_complete'] == true && looksReal) {
      vehicleSetupComplete = true;
    } else {
      vehicleSetupComplete = looksReal;
    }
  }

  Future<bool> checkAuthStatus() async {
    final authenticated = isAuthenticated;
    notifyListeners();
    return authenticated;
  }

  int get acceptedOrders =>
      allOrders.where((order) => order['status'] == 'accepted').length;

  int get totalOrders => allOrders.length;

  double get acceptanceRate =>
      totalOrders == 0 ? 0.0 : (acceptedOrders / totalOrders) * 100;

  Future<void> init() async {
    // Namespaced Hive box so this APK never shares keys with the customer app.
    _authBox = await Hive.openBox('driver_auth_v1');
    _ordersBox = await Hive.openBox('driver_orders_v1');
    try {
      final legacyAuth = await Hive.openBox('authbox');
      if (_authBox!.isEmpty && legacyAuth.isNotEmpty) {
        for (final key in legacyAuth.keys) {
          await _authBox!.put(key, legacyAuth.get(key));
        }
      }
      final legacyOrders = await Hive.openBox('ordersbox');
      if (_ordersBox!.isEmpty && legacyOrders.isNotEmpty) {
        for (final key in legacyOrders.keys) {
          await _ordersBox!.put(key, legacyOrders.get(key));
        }
      }
    } catch (_) {}

    final session = await DriverSessionStore.loadSession();
    if (session != null) {
      token = session['token'] as String?;
      refreshToken = session['refreshToken'] as String?;
      driverId = session['driverId'] as String? ?? userIdFromJwt(token);
      currentUser = session['email'] as String?;
      currentUserName = session['name'] as String?;
      phone = session['phone'] as String?;
      final cachedProfile = session['profile'];
      if (cachedProfile is Map) {
        final map = Map<String, dynamic>.from(cachedProfile);
        _applyVerificationFromMap(map);
        _applyVehicleFromMap(map);
      }
    } else {
      token = _authBox?.get('token') as String?;
      refreshToken = _authBox?.get('refreshToken') as String?;
      driverId = _authBox?.get('driverId') as String? ?? userIdFromJwt(token);
      currentUser = _authBox?.get('email') as String?;
      currentUserName = _authBox?.get('name') as String?;
      phone = _authBox?.get('phone') as String?;
    }

    profileImagePath = _authBox?.get('profileImagePath') as String?;
    imageGallery =
        List<String>.from(_authBox?.get('imageGallery', defaultValue: []) ?? []);

    final savedOrders = _ordersBox?.get('orders', defaultValue: []) ?? [];
    if (savedOrders is List) {
      allOrders = List<Map<dynamic, dynamic>>.from(savedOrders);
    }

    if (isLoggedIn) {
      await _persistSession();
      resumeOnline = await DriverSessionStore.wasOnDuty();
    }

    notifyListeners();
  }

  /// Validates stored session; refreshes token/profile in background when possible.
  Future<bool> bootstrapSession() async {
    if (_sessionBootstrapping) return isAuthenticated;
    if (!isLoggedIn) return false;

    _sessionBootstrapping = true;
    sessionHydrating = true;
    notifyListeners();
    try {
      unawaited(DriverSessionStore.deviceId());

      if (isJwtExpired(token) &&
          refreshToken != null &&
          refreshToken!.isNotEmpty) {
        try {
          await refreshAccessToken();
        } catch (e) {
          if (kDebugMode) debugPrint('refreshAccessToken threw during bootstrap: $e');
        }
      }

      try {
        final response = await _apiClient.getResult('${ApiConstants.driverBase}/profile');
        if (response.statusCode == 401 || response.statusCode == 403) {
          if (refreshToken != null && refreshToken!.isNotEmpty) {
            final refreshed = await refreshAccessToken();
            if (refreshed) {
              final retryResponse =
                  await _apiClient.getResult('${ApiConstants.driverBase}/profile');
              if (retryResponse.statusCode == 401 || retryResponse.statusCode == 403) {
                if (isJwtExpired(token)) {
                  await logout();
                  return false;
                }
              } else if (retryResponse.data is Map<String, dynamic>) {
                await _applyProfileResponse(retryResponse.data as Map<String, dynamic>);
              }
            } else if (isJwtExpired(token)) {
              await logout();
              return false;
            }
          } else if (isJwtExpired(token)) {
            await logout();
            return false;
          }
        } else if (response.data is Map<String, dynamic>) {
          await _applyProfileResponse(response.data as Map<String, dynamic>);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Profile endpoint threw network error: $e');
        // Keep cached session when offline; user stays logged in locally.
      }

      await DriverSessionStore.touchLastActive();
      resumeOnline = await DriverSessionStore.wasOnDuty();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('bootstrapSession general error: $e');
      return isAuthenticated;
    } finally {
      _sessionBootstrapping = false;
      sessionHydrating = false;
      notifyListeners();
    }
  }

  Future<bool> wasOnDuty() async {
    resumeOnline = await DriverSessionStore.wasOnDuty();
    return resumeOnline;
  }

  Future<void> setWasOnDuty(bool onDuty) async {
    resumeOnline = onDuty;
    await DriverSessionStore.setWasOnDuty(onDuty);
    notifyListeners();
  }

  static String _connectionErrorMessage() {
    return 'Unable to connect. Check your internet connection and try again.';
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    lastError = null;
    sessionHydrating = true;
    notifyListeners();
    try {
      final response = await _publicApiClient.post(
        '${ApiConstants.driverBase}/login',
        body: {'email': email.trim().toLowerCase(), 'password': password},
      );
      final result = ApiClient.asMap(_publicApiClient.decode(response));
      if (result != null) {
        final applied = _applyAuthFromResponse(result, email: email);
        if (applied) {
          await _finishLoginFast();
          return true;
        }
        lastError = result['message']?.toString() ??
            'Login failed (${response.statusCode}). Check email and password.';
        return false;
      }
      lastError = _loginHttpError(response.statusCode, response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService.login error: $e');
      lastError = _connectionErrorMessage();
    } finally {
      sessionHydrating = false;
      notifyListeners();
    }
    return false;
  }

  String _loginHttpError(int statusCode, String body) {
    final preview = body.trim();
    if (statusCode == 404 || preview.contains('NOT_FOUND')) {
      return 'Server API is not deployed. Redeploy taxi-bacckend on Vercel.';
    }
    if (preview.startsWith('<') || preview.toLowerCase().contains('<!doctype')) {
      return 'Server returned a web page instead of login API. Check Vercel URL / protection.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Invalid email or password.';
    }
    if (statusCode >= 500) {
      return 'Server error ($statusCode). Try again in a moment.';
    }
    return 'Could not read login response ($statusCode).';
  }

  /// Saves session and refreshes profile before routing.
  Future<void> _finishLoginFast() async {
    await _persistSession();
    await bootstrapSession();
  }

  Future<bool> refreshAccessToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;

    final paths = [
      '${ApiConstants.driverBase}/auth/refresh',
      '${ApiConstants.authBase}/refresh',
    ];

    for (final path in paths) {
      try {
        final result = await _publicApiClient.postJson(
          path,
          body: {'refreshToken': refreshToken},
        );
        if (result is! Map<String, dynamic>) continue;

        String? access;
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          access = data['accessToken']?.toString() ?? data['token']?.toString();
        }
        access ??= result['accessToken']?.toString() ?? result['token']?.toString();

        if (access == null || access.isEmpty) continue;

        token = access;
        driverId ??= userIdFromJwt(token);
        await _persistSession();
        notifyListeners();
        return true;
      } catch (e) {
        if (kDebugMode) debugPrint('AuthService.refreshAccessToken ($path): $e');
      }
    }
    return false;
  }

  Future<void> logout() async {
    await DriverRideListenerService.instance.stop();
    await setWasOnDuty(false);

    token = null;
    refreshToken = null;
    driverId = null;
    currentUser = null;
    currentUserName = null;
    phone = null;
    profileImagePath = null;
    imageGallery.clear();
    allOrders.clear();
    isDriverVerified = false;
    driverVerificationStatus = 'NOT_SUBMITTED';
    vehicleModel = null;
    vehicleNumber = null;
    vehicleType = null;
    vehicleSetupComplete = false;
    resumeOnline = false;

    await DriverSessionStore.clear();
    await ActiveRideStore.clear();
    await _authBox?.clear();
    await _ordersBox?.clear();
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      final result = await _publicApiClient.postJson(
        '${ApiConstants.driverBase}/register',
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        },
      );
      if (result is Map<String, dynamic>) {
        final applied = _applyAuthFromResponse(result, email: email);
        if (applied) {
          await _finishLoginFast();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<bool> sendRegisterOtp(String email) async {
    lastError = null;
    lastIssuedOtp = null;
    try {
      final response = await _publicApiClient.postResult(
        '${ApiConstants.driverBase}/register/email',
        body: {'email': email.trim().toLowerCase()},
      );
      if (response.success) {
        final data = response.data;
        if (data is Map) {
          final otp = data['otp']?.toString().trim();
          if (otp != null && RegExp(r'^\d{6}$').hasMatch(otp)) {
            lastIssuedOtp = otp;
          }
        }
        return true;
      }
      lastError = response.message ??
          (response.statusCode == 409
              ? 'An account with this email already exists. Please sign in.'
              : 'Failed to send OTP.');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService.sendRegisterOtp error: $e');
      lastError = _connectionErrorMessage();
      return false;
    }
  }

  Future<bool> verifyRegisterOtp(String email, String otp) async {
    try {
      final result = await _publicApiClient.postJson(
        '${ApiConstants.driverBase}/register/verify-otp',
        body: {'email': email, 'otp': otp},
      );
      if (result is Map<String, dynamic>) {
        return result['success'] == true || result['status'] == 200;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setPassword(String email, String password) async {
    lastError = null;
    try {
      final result = await _publicApiClient.postJson(
        '${ApiConstants.driverBase}/register/set-password',
        body: {'email': email.trim().toLowerCase(), 'password': password},
      );
      final map = ApiClient.asMap(result);
      if (map != null) {
        final applied = _applyAuthFromResponse(map, email: email);
        if (applied) {
          await _finishLoginFast();
          return true;
        }
        lastError = map['message']?.toString() ?? 'Failed to save password.';
        return map['success'] == true;
      }
      lastError = 'Could not read server response. Try login after the API is deployed.';
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService.setPassword error: $e');
      lastError = _connectionErrorMessage();
      return false;
    }
  }

  Future<Map<String, dynamic>> sendForgotOtp(String email) async {
    lastIssuedOtp = null;
    try {
      final result = await _publicApiClient.postJson(
        '${ApiConstants.driverBase}/forgot-password/email',
        body: {'email': email},
      );
      if (result is Map<String, dynamic>) {
        final otp = result['otp']?.toString().trim();
        if (otp != null && RegExp(r'^\d{6}$').hasMatch(otp)) {
          lastIssuedOtp = otp;
        }
        return {
          'success': result['success'] == true || result['status'] == 200,
          'message': result['message'] ?? 'OTP sent successfully',
          if (otp != null && RegExp(r'^\d{6}$').hasMatch(otp)) 'otp': otp,
        };
      }
      return {'success': false, 'message': 'Unexpected server response'};
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService.sendForgotOtp error: $e');
      return {
        'success': false,
        'message': 'Unable to reach the server. Please check backend and network.',
        'offline': true,
      };
    }
  }

  Future<Map<String, dynamic>> verifyForgotOtp(String email, String otp) async {
    try {
      final result = await _publicApiClient.postJson(
        '${ApiConstants.driverBase}/forgot-password/verify-otp',
        body: {'email': email, 'otp': otp},
      );
      if (result is Map<String, dynamic>) {
        return {
          'success': result['success'] == true || result['status'] == 200,
          'message': result['message'] ?? 'OTP verified successfully',
        };
      }
      return {'success': false, 'message': 'Unexpected server response'};
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService.verifyForgotOtp error: $e');
      return {
        'success': false,
        'message': 'Unable to reach the server. Please check backend and network.',
        'offline': true,
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String password) async {
    try {
      final result = await _publicApiClient.postJson(
        '${ApiConstants.driverBase}/forgot-password/set-password',
        body: {'email': email, 'password': password},
      );
      if (result is Map<String, dynamic>) {
        return {
          'success': result['success'] == true || result['status'] == 200,
          'message': result['message'] ?? 'Password reset successfully',
        };
      }
      return {'success': false, 'message': 'Unexpected server response'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to reach the server. Please check backend and network.',
        'offline': true,
      };
    }
  }

  Future<Map<String, dynamic>?> getDriverProfile() async {
    if (token == null) return null;
    try {
      final result = await _apiClient.getJson('${ApiConstants.driverBase}/profile');
      if (result is Map<String, dynamic>) {
        final driver = result['driver'];
        if (driver is Map) {
          return Map<String, dynamic>.from(driver);
        }
        return result;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> setDriverStatus(String status) async {
    if (token == null) return false;
    lastDriverStatusError = null;
    try {
      final normalized = status.toUpperCase();
      final result = await _apiClient.patchResult(
        '${ApiConstants.driverBase}/status',
        body: {'status': normalized},
      );
      if (result.success) {
        final body = result.data;
        if (body is Map<String, dynamic>) {
          final updated = body['status']?.toString().toUpperCase();
          if (updated == normalized ||
              (body['message']?.toString().toLowerCase().contains('updated') ?? false)) {
            return true;
          }
        }
        return true;
      }
      lastDriverStatusError = result.message ?? 'Unable to update driver status.';
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService.setDriverStatus error: $e');
      lastDriverStatusError = 'Unable to reach the server.';
      return false;
    }
  }

  Future<bool> updateOrderStatus(String id, String status) async {
    final index = allOrders.indexWhere((order) => order['id'] == id);
    if (index < 0) return false;
    allOrders[index]['status'] = status;
    _ordersBox?.put('orders', allOrders);
    notifyListeners();
    return true;
  }

  void setProfileImage(String path) {
    profileImagePath = path;
    _authBox?.put('profileImagePath', path);
    notifyListeners();
  }

  void selectFromGallery(String path) {
    imageGallery.add(path);
    _authBox?.put('imageGallery', imageGallery);
    notifyListeners();
  }

  void setVerifiedUser(String email) {
    currentUser = email;
    _persistSession();
    notifyListeners();
  }

  bool _applyAuthFromResponse(Map<String, dynamic> result, {required String email}) {
    final data = ApiClient.asMap(result['data']);
    token = result['token']?.toString() ??
        result['accessToken']?.toString() ??
        data?['token']?.toString() ??
        data?['accessToken']?.toString();

    if (token == null || token == 'null' || token!.isEmpty) {
      token = null;
    }

    refreshToken = result['refreshToken']?.toString() ?? data?['refreshToken']?.toString();

    final user = ApiClient.asMap(result['user']) ??
        ApiClient.asMap(result['driver']) ??
        ApiClient.asMap(data?['user']) ??
        ApiClient.asMap(data?['driver']);
    if (user != null) {
      _applyVehicleFromMap(user);
    }

    driverId = user?['id']?.toString() ?? user?['_id']?.toString() ?? userIdFromJwt(token);
    currentUser = user?['email']?.toString() ?? email;
    currentUserName = user?['name']?.toString() ??
        result['name']?.toString() ??
        email.split('@').first;
    phone = user?['phone']?.toString();
    _applyVerificationFromMap(user ?? result);
    if (user == null || user.isEmpty) {
      isDriverVerified = result['is_driver_verified'] == true ||
          (result['driver_verification_status']?.toString().toUpperCase() == 'APPROVED');
      driverVerificationStatus =
          (result['driver_verification_status'] ?? driverVerificationStatus).toString();
    }

    if (token == null || token!.isEmpty) return false;
    return true;
  }

  Future<void> _applyProfileResponse(Map<String, dynamic> profile) async {
    Map<String, dynamic>? driverMap;
    final nested = profile['driver'] ?? profile['data'] ?? profile['user'];
    if (nested is Map && nested.isNotEmpty) {
      driverMap = Map<String, dynamic>.from(nested);
    } else {
      driverMap = profile;
    }

    driverId = driverMap['id']?.toString() ??
        driverMap['_id']?.toString() ??
        userIdFromJwt(token) ??
        driverId;
    currentUserName = driverMap['name']?.toString() ?? currentUserName;
    currentUser = driverMap['email']?.toString() ?? currentUser;
    phone = driverMap['phone']?.toString() ?? phone;
    _applyVerificationFromMap(driverMap);
    _applyVehicleFromMap(driverMap);
    await _persistSession(profile: {
      ...driverMap,
      'vehicle_model': vehicleModel,
      'vehicle_number': vehicleNumber,
      'vehicle_setup_complete': vehicleSetupComplete,
    });
  }

  Future<({bool success, String? message})> saveVehicleDetails({
    required String model,
    required String number,
    String? vehicleTypeId,
    String type = 'sedan',
    String color = '',
  }) async {
    final trimmedModel = model.trim();
    final trimmedNumber = number.trim().toUpperCase();
    if (trimmedModel.length < 2) {
      return (success: false, message: 'Enter vehicle model');
    }
    if (trimmedNumber.length < 4) {
      return (success: false, message: 'Enter vehicle number / plate');
    }
    if (token == null) {
      return (success: false, message: 'Not logged in');
    }

    final body = {
      'model': trimmedModel,
      'vehicle_model': trimmedModel,
      'plateNumber': trimmedNumber,
      'vehicle_number': trimmedNumber,
      'vehicle_reg_number': trimmedNumber,
      if (vehicleTypeId != null && vehicleTypeId.isNotEmpty) 'vehicle_type_id': vehicleTypeId,
      'type': type,
      'vehicle_type': type,
      if (color.isNotEmpty) 'color': color,
    };

    try {
      var result = await _apiClient.patchResult(
        '${ApiConstants.driverBase}/vehicle',
        body: body,
      );
      if (!result.success) {
        result = await _apiClient.postResult(
          '${ApiConstants.driverBase}/vehicle',
          body: body,
        );
      }
      if (!result.success) {
        result = await _apiClient.patchResult(
          '${ApiConstants.driverBase}/profile/vehicle',
          body: body,
        );
      }
      // Docker / v1 profile fallback
      if (!result.success) {
        result = await _apiClient.postResult(
          '${ApiConstants.v1DriverBase}/profile',
          body: {
            'vehicle_model': trimmedModel,
            'vehicle_reg_number': trimmedNumber,
            if (vehicleTypeId != null && vehicleTypeId.isNotEmpty)
              'vehicle_type_id': vehicleTypeId,
            'profile_completed': true,
          },
        );
      }

      // Persist locally even if remote is temporarily unavailable (setup must continue).
      vehicleModel = trimmedModel;
      vehicleNumber = trimmedNumber;
      vehicleType = type;
      vehicleSetupComplete = true;
      await _persistSession(profile: {
        'vehicle_model': trimmedModel,
        'vehicle_number': trimmedNumber,
        'vehicle_setup_complete': true,
        'vehicleDetails': {
          'model': trimmedModel,
          'plateNumber': trimmedNumber,
          'type': type,
          'color': color,
        },
        'is_driver_verified': isDriverVerified,
        'driver_verification_status': driverVerificationStatus,
      });
      notifyListeners();

      if (result.success) {
        if (result.data is Map<String, dynamic>) {
          await _applyProfileResponse(result.data as Map<String, dynamic>);
          notifyListeners();
        }
        return (success: true, message: result.message ?? 'Vehicle saved');
      }
      return (
        success: true,
        message: 'Vehicle saved on this device. Sync when server is available.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('saveVehicleDetails: $e');
      vehicleModel = trimmedModel;
      vehicleNumber = trimmedNumber;
      vehicleType = type;
      vehicleSetupComplete = true;
      await _persistSession(profile: {
        'vehicle_model': trimmedModel,
        'vehicle_number': trimmedNumber,
        'vehicle_setup_complete': true,
      });
      notifyListeners();
      return (success: true, message: 'Vehicle saved locally');
    }
  }

  Future<({bool success, String? message})> updateProfile({
    required String name,
    required String phone,
    String address = '',
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    if (trimmedName.length < 2) {
      return (success: false, message: 'Enter your name');
    }
    if (trimmedPhone.length < 8) {
      return (success: false, message: 'Enter a valid phone number');
    }
    if (token == null) {
      return (success: false, message: 'Not logged in');
    }

    currentUserName = trimmedName;
    this.phone = trimmedPhone;
    await _persistSession(profile: {
      'name': trimmedName,
      'phone': trimmedPhone,
      if (address.isNotEmpty) 'address': address,
    });
    notifyListeners();

    try {
      await _apiClient.postResult(
        '${ApiConstants.v1DriverBase}/profile',
        body: {
          'phone': trimmedPhone,
          if (address.isNotEmpty) 'address': address,
        },
      );
      await _apiClient.putJson(
        '${ApiConstants.apiRestBase}/driver-app/driver/profile',
        body: {
          'name': trimmedName,
          'phone': trimmedPhone,
          if (address.isNotEmpty) 'bio': address,
        },
      );
      await refreshProfileFromApi();
      return (success: true, message: 'Profile updated');
    } catch (e) {
      if (kDebugMode) debugPrint('updateProfile: $e');
      return (success: true, message: 'Profile saved on this device');
    }
  }

  Future<bool> refreshProfileFromApi() async {
    if (token == null) return false;
    try {
      final response = await _apiClient.getResult('${ApiConstants.driverBase}/profile');
      if (response.data is Map<String, dynamic>) {
        await _applyProfileResponse(response.data as Map<String, dynamic>);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _persistSession({Map<String, dynamic>? profile}) async {
    _authBox?.put('token', token);
    _authBox?.put('refreshToken', refreshToken);
    _authBox?.put('driverId', driverId);
    _authBox?.put('email', currentUser);
    _authBox?.put('name', currentUserName);
    _authBox?.put('phone', phone);
    _authBox?.put('profileImagePath', profileImagePath);
    _authBox?.put('imageGallery', imageGallery);

    if (token != null) {
      await DriverSessionStore.saveSession(
        accessToken: token!,
        refreshToken: refreshToken,
        driverId: driverId,
        email: currentUser,
        name: currentUserName,
        phone: phone,
        profile: profile,
      );
    }
  }

}
