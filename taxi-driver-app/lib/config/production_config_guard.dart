import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kReleaseMode;

import 'app_endpoints.dart';
import 'env_config.dart';

/// Returns an error message if production API config is unusable; otherwise null.
/// Never throws — throwing here crashes the APK before any UI paints.
String? productionApiConfigError() {
  final api = EnvConfig.apiBaseUrl;
  if (api.isEmpty) {
    return 'API_BASE_URL is empty. Rebuild with your Vercel URL.';
  }
  if (AppEndpoints.isPlaceholder(api)) {
    if (kIsWeb && !kReleaseMode) return null;
    return 'API_BASE_URL is still a placeholder. Rebuild the APK with your real server URL.';
  }
  if (!kIsWeb && AppEndpoints.isLocalHost(api)) {
    return 'Device builds need a public HTTPS API (not localhost / LAN IP).';
  }
  return null;
}

@Deprecated('Use productionApiConfigError() — throwing crashes release APKs')
void assertProductionApiConfigured() {
  final err = productionApiConfigError();
  if (err != null) {
    debugPrint('Production API config: $err');
  }
}
