import 'env_config.dart';

/// REST + Socket API constants (matches Driver App [ApiConstants] pattern).
class ApiConfig {
  /// Socket.IO server origin — same as Driver App `ApiConstants.baseUrl`.
  static String get socketUrl => EnvConfig.socketBaseUrl;

  /// REST base including `/api`, e.g. `https://api.example.com/api`.
  static String get apiRestBase => EnvConfig.apiBaseUrl;

  /// REST base used by services (`/customers/...` paths).
  static String get baseUrl => apiRestBase;

  static String get apiBaseUrl => apiRestBase;

  static String get apiOrigin => EnvConfig.apiOrigin;

  static String get webSocketUrl => socketUrl;

  static String get osrmUrl {
    final configured = EnvConfig.osrmBaseUrl;
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/$'), '');
    }
    return EnvConfig.apiOrigin;
  }

  static String get customerBase => '$apiRestBase/customers';

  static String get authBase => '$apiRestBase/v1/auth';

  static bool get useBackend => EnvConfig.useBackend;

  static String authHeader(String accessToken) => 'Bearer $accessToken';
}
