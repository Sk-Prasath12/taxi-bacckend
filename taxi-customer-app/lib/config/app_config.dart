/// Single entry point for all backend URLs (customer app).
library;

export 'env_config.dart' show EnvConfig;

import 'env_config.dart';

abstract final class AppConfig {
  static String get apiBaseUrl => EnvConfig.apiBaseUrl;
  static String get apiOrigin => EnvConfig.apiOrigin;
  static String get socketUrl => EnvConfig.socketBaseUrl;
  static String get osrmUrl => EnvConfig.osrmBaseUrl;
  static String get imageUrl => EnvConfig.imageBaseUrl;
}
