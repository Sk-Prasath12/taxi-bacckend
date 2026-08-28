import '../config/env_config.dart';

class ApiConstants {
  static String get baseUrl => EnvConfig.socketBaseUrl;
  static String get apiRestBase => EnvConfig.apiBaseUrl;

  static String get osrmUrl {
    final configured = EnvConfig.osrmBaseUrl;
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/$'), '');
    }
    return EnvConfig.apiOrigin;
  }

  static String get customerBase => '$apiRestBase/customers';
  static String get driverBase => '$apiRestBase/drivers';
  static String get driverInvoiceBase => '$apiRestBase/driver';
  static String get v1DriverBase => '$apiRestBase/v1/driver';
  static String get authBase => '$apiRestBase/v1/auth';
}
