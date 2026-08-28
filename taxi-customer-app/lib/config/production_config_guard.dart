import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

import 'app_endpoints.dart';
import 'env_config.dart';

/// Shown on login when API config is invalid (APK built without production URL).
String? startupConfigWarning;

/// Validates API config. Returns a login-screen message, or null if OK.
String? validateProductionApi() {
  final api = EnvConfig.apiBaseUrl;
  if (api.isEmpty) {
    return 'Server URL is not configured. Rebuild the APK with your HTTPS API URL.';
  }
  if (AppEndpoints.isPlaceholder(api)) {
    if (!kReleaseMode) return null;
    return 'This APK was not built with a production API. Install the correct release APK.';
  }
  if (!kIsWeb && AppEndpoints.isLocalHost(api) && kReleaseMode) {
    return 'This APK requires a public HTTPS server. Reinstall the production release APK.';
  }
  return null;
}

/// Logs config issues in debug; stores warning for login screen on release builds.
void assertProductionApiConfigured() {
  startupConfigWarning = validateProductionApi();
  if (startupConfigWarning != null && kIsWeb) {
    startupConfigWarning = null;
  }
}
