import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/app_endpoints.dart';

/// Checks whether the configured API server is reachable.
class BackendHealthService {
  static const Duration _timeout = Duration(seconds: 15);

  static Uri? get _healthUri {
    final base = ApiConfig.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;
    return Uri.tryParse('$base/v1/health');
  }

  static Future<({bool ok, String message})> check() async {
    final uri = _healthUri;
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return (
        ok: false,
        message: 'App is missing server URL. Reinstall the correct release APK.',
      );
    }

    if (AppEndpoints.isPlaceholder(ApiConfig.baseUrl)) {
      return (
        ok: false,
        message: 'App was not built with a valid server URL. Reinstall the release APK.',
      );
    }

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        return (ok: true, message: 'Server is online');
      }
      return (
        ok: false,
        message: 'Server error (${response.statusCode}). Try again in a minute.',
      );
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('failed host lookup') ||
          msg.contains('no address associated')) {
        return (
          ok: false,
          message:
              'Server address not found. The API may have changed — ask admin to rebuild the APK.',
        );
      }
      if (msg.contains('connection refused') ||
          msg.contains('connection timed out') ||
          msg.contains('network is unreachable')) {
        return (
          ok: false,
          message:
              'Cannot reach server. Check your internet, or ask admin to start Docker and tunnel on the PC.',
        );
      }
      return (ok: false, message: 'Network error. Check internet and try again.');
    } catch (_) {
      return (
        ok: false,
        message:
            'Cannot reach server. Check internet or ask admin if the backend is running.',
      );
    }
  }
}
