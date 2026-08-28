import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_endpoints.dart';

class EnvConfig {
  static bool _loaded = false;
  static AppEndpoints? _endpoints;

  static Future<void> load() async {
    _endpoints = null;
    if (_loaded && kReleaseMode) return;

    // Always try asset env first so dotenv is initialized even when
    // --dart-define is also set (avoids NotInitializedError on missing keys).
    for (final file in ['assets/env/app.env', '.env.production', '.env']) {
      try {
        await dotenv.load(fileName: file);
        break;
      } catch (_) {}
    }

    const apiFromDefine = String.fromEnvironment('API_BASE_URL');
    if (apiFromDefine.isNotEmpty) {
      _loaded = true;
      _rebuildEndpoints();
      return;
    }

    if (dotenv.isInitialized) {
      _loaded = true;
      _rebuildEndpoints();
      if (!kReleaseMode) {
        // ignore: avoid_print
        final note = kIsWeb && AppEndpoints.isPlaceholder(_readApiBaseUrlRaw())
            ? ' (web dev → localhost backend)'
            : '';
        print('EnvConfig: loaded dotenv → $apiBaseUrl$note');
      }
      return;
    }

    _loaded = true;
    _rebuildEndpoints();
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

  static String _localWebOrigin() =>
      (kIsWeb && !kReleaseMode) ? 'http://localhost:3000' : '';

  static String _effectiveApiRaw(String raw) {
    if (kIsWeb && !kReleaseMode && (raw.isEmpty || AppEndpoints.isPlaceholder(raw))) {
      return _localWebOrigin();
    }
    return raw;
  }

  static String _effectiveSocketRaw(String raw) {
    if (kIsWeb && !kReleaseMode && (raw.isEmpty || AppEndpoints.isPlaceholder(raw))) {
      return _localWebOrigin();
    }
    return raw;
  }

  static String _dotenvGet(String key) {
    // Accessing dotenv.env before load() throws NotInitializedError and
    // crashes release APKs built only with --dart-define.
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key]?.trim() ?? '';
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
    return _dotenvGet(key);
  }

  static String _readOsrmRaw() {
    final base = _readEnv('OSRM_BASE_URL');
    if (base.isNotEmpty) return base;
    return _readEnv('OSRM_URL');
  }

  static String _readApiBaseUrlRaw() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return _dotenvGet('API_BASE_URL');
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
}
