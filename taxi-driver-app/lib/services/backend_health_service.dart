import 'package:http/http.dart' as http;

import '../config/env_config.dart';

class BackendHealthService {
  static const Duration _timeout = Duration(seconds: 12);

  static Future<({bool ok, String message})> check() async {
    final base = EnvConfig.baseHost;
    final url = Uri.parse('$base/api/v1/health');
    try {
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        return (ok: true, message: 'Connected to $base');
      }
      return (
        ok: false,
        message: 'Server returned ${response.statusCode} at $base',
      );
    } catch (_) {
      return (
        ok: false,
        message: 'Cannot reach $base — same Wi‑Fi, backend running, '
            'or tap Server below to set PC IP / public URL.',
      );
    }
  }
}
