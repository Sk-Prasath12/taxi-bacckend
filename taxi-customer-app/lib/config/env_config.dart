import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;

import 'app_endpoints.dart';

/// Production API is Vercel ([assets/env/app.env]).
/// Local Docker only when `--dart-define=USE_LAN_BACKEND=true`.
class EnvConfig {
  static bool _loaded = false;
  static AppEndpoints? _endpoints;
  static Map<String, String> _env = {};

  static Future<void> load() async {
    _endpoints = null;
    _env = {};

    if (kReleaseMode && _loaded) return;

    const apiFromDefine = String.fromEnvironment('API_BASE_URL');
    if (apiFromDefine.isNotEmpty) {
      _loaded = true;
      _rebuildEndpoints();
      _logLoaded('dart-define');
      return;
    }

    var loadedFile = 'assets/env/app.env';
    await _mergeAssetEnv('assets/env/app.env');

    // LAN Docker only when explicitly requested. Default is Vercel (app.env).
    if (!kReleaseMode && _useLanBackend) {
      final hadDev = await _mergeAssetEnv('assets/env/dev.env');
      if (hadDev && _hasProductionApi(_env['API_BASE_URL'])) {
        loadedFile = 'assets/env/dev.env';
      }
    }

    _loaded = true;
    _rebuildEndpoints();
    _logLoaded(loadedFile);
  }

  static bool _hasProductionApi(String? raw) {
    final v = raw?.trim() ?? '';
    return v.isNotEmpty && !AppEndpoints.isPlaceholder(v);
  }

  static Future<bool> _mergeAssetEnv(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      _env.addAll(_parseEnv(content));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> _parseEnv(String content) {
    final map = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      if (value.length >= 2) {
        final q = value[0];
        if ((q == '"' || q == "'") && value.endsWith(q)) {
          value = value.substring(1, value.length - 1);
        }
      }
      map[key] = value;
    }
    return map;
  }

  static const bool _useLanBackend =
      bool.fromEnvironment('USE_LAN_BACKEND', defaultValue: false);

  static void _logLoaded(String source) {
    if (kReleaseMode) return;
    // ignore: avoid_print
    final note = _useLanBackend ? ' (LAN Docker)' : ' (Vercel)';
    print('EnvConfig: $source → $apiBaseUrl$note');
  }

  static void _rebuildEndpoints() {
    _endpoints = AppEndpoints.resolve(
      apiBaseUrlRaw: _effectiveApiRaw(_readApiBaseUrlRaw()),
      socketBaseUrlRaw: _effectiveSocketRaw(_readEnv('SOCKET_BASE_URL')),
      osrmBaseUrlRaw: _readOsrmRaw(),
      imageBaseUrlRaw: _readEnv('IMAGE_BASE_URL'),
      devApiOriginFallback: _localWebOrigin(),
    );
  }

  static String _mobileDebugOrigin() {
    if (!_useLanBackend || kReleaseMode) return '';

    const fromDefine = String.fromEnvironment('DEV_API_HOST');
    if (fromDefine.isNotEmpty) return _normalizeOrigin(fromDefine);

    for (final key in ['DEVICE_API_HOST', 'DEV_API_HOST']) {
      final host = _env[key]?.trim();
      if (host != null && host.isNotEmpty) return _normalizeOrigin(host);
    }
    return '';
  }

  static String _normalizeOrigin(String host) {
    final trimmed = host.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.contains('://')) return trimmed;
    return 'http://$trimmed';
  }

  static String _originFromApiUrl(String url) {
    final normalized = url.contains('://') ? url : 'http://${url.trim()}';
    final uri = Uri.parse(normalized);
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static String _localWebOrigin() =>
      (_useLanBackend && kIsWeb && !kReleaseMode) ? 'http://localhost:3000' : '';

  static String _effectiveApiRaw(String raw) {
    final mobile = _mobileDebugOrigin();
    if (mobile.isNotEmpty) {
      return mobile.endsWith('/api') ? mobile : '$mobile/api';
    }
    if (kIsWeb && _useLanBackend && !kReleaseMode) {
      const fromDefine = String.fromEnvironment('API_BASE_URL');
      if (fromDefine.isNotEmpty) return fromDefine;
      return '${_localWebOrigin()}/api';
    }
    return raw;
  }

  static String _effectiveSocketRaw(String raw) {
    final mobile = _mobileDebugOrigin();
    if (mobile.isNotEmpty) return mobile;
    if (kIsWeb && _useLanBackend && !kReleaseMode) {
      const fromDefine = String.fromEnvironment('SOCKET_BASE_URL');
      if (fromDefine.isNotEmpty) return fromDefine;
      return _localWebOrigin();
    }
    return raw;
  }

  static String _readEnv(String key) {
    const keys = {
      'SOCKET_BASE_URL': String.fromEnvironment('SOCKET_BASE_URL'),
      'OSRM_BASE_URL': String.fromEnvironment('OSRM_BASE_URL'),
      'OSRM_URL': String.fromEnvironment('OSRM_URL'),
      'IMAGE_BASE_URL': String.fromEnvironment('IMAGE_BASE_URL'),
    };
    final fromDefine = keys[key];
    if (fromDefine != null && fromDefine.isNotEmpty) return fromDefine;
    return _env[key]?.trim() ?? '';
  }

  static String _readOsrmRaw() {
    final base = _readEnv('OSRM_BASE_URL');
    if (base.isNotEmpty) return base;
    return _readEnv('OSRM_URL');
  }

  static String _readApiBaseUrlRaw() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return _env['API_BASE_URL']?.trim() ?? '';
  }

  static AppEndpoints get _e {
    _endpoints ??= AppEndpoints.resolve(
      apiBaseUrlRaw: _effectiveApiRaw(_readApiBaseUrlRaw()),
      socketBaseUrlRaw: _effectiveSocketRaw(_readEnv('SOCKET_BASE_URL')),
      osrmBaseUrlRaw: _readOsrmRaw(),
      imageBaseUrlRaw: _readEnv('IMAGE_BASE_URL'),
      devApiOriginFallback: _localWebOrigin(),
    );
    return _endpoints!;
  }

  static String get apiOrigin => _e.apiOrigin;
  static String get apiBaseUrl => _e.apiBaseUrl;
  static String get socketBaseUrl => _e.socketBaseUrl;
  static String get osrmBaseUrl => _e.osrmBaseUrl;
  static String get imageBaseUrl => _e.imageBaseUrl;
  static String get baseHost => apiOrigin;
  static String get osrmUrl => osrmBaseUrl;

  static bool get useBackend {
    final raw = _env['USE_BACKEND']?.trim().toLowerCase();
    if (raw == 'false' || raw == '0') return false;
    return true;
  }

  static String get devOtp => _env['DEV_OTP']?.trim() ?? '123456';

  static String get razorpayKeyId {
    final fromEnv = _env['RAZORPAY_KEY_ID']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    const fromDefine = String.fromEnvironment('RAZORPAY_KEY_ID');
    if (fromDefine.isNotEmpty) return fromDefine;
    return '';
  }

  static String get razorpayCurrency {
    final fromEnv = _env['RAZORPAY_CURRENCY']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return 'INR';
  }

  static bool get isRazorpayLive {
    final env = _env['RAZORPAY_ENV']?.trim().toLowerCase();
    return env == 'live' || env == 'production';
  }

  static bool get useDummyRazorpay {
    if (kIsWeb) return true;
    final raw = _env['DUMMY_RAZORPAY']?.trim().toLowerCase();
    if (raw == 'true' || raw == '1') return true;
    if (raw == 'false' || raw == '0') return false;
    return !kReleaseMode;
  }
}
