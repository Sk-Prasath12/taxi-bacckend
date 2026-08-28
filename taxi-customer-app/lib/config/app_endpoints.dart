import '../utils/api_host_normalizer.dart';

/// Parses production [API_BASE_URL], [SOCKET_BASE_URL], [OSRM_BASE_URL], [IMAGE_BASE_URL].
class AppEndpoints {
  AppEndpoints._({
    required this.apiOrigin,
    required this.apiBaseUrl,
    required this.socketBaseUrl,
    required this.osrmBaseUrl,
    required this.imageBaseUrl,
  });

  final String apiOrigin;
  final String apiBaseUrl;
  final String socketBaseUrl;
  final String osrmBaseUrl;
  final String imageBaseUrl;

  static AppEndpoints resolve({
    required String apiBaseUrlRaw,
    required String socketBaseUrlRaw,
    required String osrmBaseUrlRaw,
    required String imageBaseUrlRaw,
    required String devApiOriginFallback,
  }) {
    final apiRaw = apiBaseUrlRaw.trim();
    final normalizedApi = apiRaw.isEmpty
        ? ''
        : ApiHostNormalizer.normalize(
            apiRaw.contains('://') ? apiRaw : 'https://$apiRaw',
          );

    String origin;
    String apiBase;
    if (normalizedApi.isEmpty) {
      origin = devApiOriginFallback;
      apiBase = origin.isEmpty ? '' : '$origin/api';
    } else {
      final uri = Uri.parse(normalizedApi);
      final port = uri.hasPort ? ':${uri.port}' : '';
      origin = '${uri.scheme}://${uri.host}$port';
      final path = uri.path.replaceAll(RegExp(r'/+$'), '');
      if (path == '/api' || path.endsWith('/api')) {
        apiBase = normalizedApi.replaceAll(RegExp(r'/+$'), '');
      } else if (path.isNotEmpty && path != '/') {
        apiBase = normalizedApi.replaceAll(RegExp(r'/+$'), '');
      } else {
        apiBase = '$origin/api';
      }
    }

    final socketRaw = socketBaseUrlRaw.trim();
    final socketBase = socketRaw.isEmpty
        ? origin
        : ApiHostNormalizer.normalize(
            socketRaw.contains('://') ? socketRaw : 'https://$socketRaw',
          );

    final osrmRaw = osrmBaseUrlRaw.trim();
    final osrmBase = osrmRaw.isEmpty
        ? ''
        : ApiHostNormalizer.normalize(
            osrmRaw.contains('://') ? osrmRaw : 'https://$osrmRaw',
          );

    final imageRaw = imageBaseUrlRaw.trim();
    final imageBase = imageRaw.isEmpty
        ? origin
        : ApiHostNormalizer.normalize(
            imageRaw.contains('://') ? imageRaw : 'https://$imageRaw',
          );

    return AppEndpoints._(
      apiOrigin: origin,
      apiBaseUrl: apiBase,
      socketBaseUrl: socketBase,
      osrmBaseUrl: osrmBase,
      imageBaseUrl: imageBase,
    );
  }

  static bool isLocalHost(String url) {
    if (url.isEmpty) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final h = uri.host.toLowerCase();
    if (h == 'localhost' || h == '127.0.0.1') return true;
    if (RegExp(r'^192\.168\.').hasMatch(h)) return true;
    if (RegExp(r'^10\.').hasMatch(h)) return true;
    if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(h)) return true;
    return false;
  }

  static bool isPlaceholder(String url) {
    final lower = url.toLowerCase();
    return lower.contains('replace_with_your_api') ||
        lower.contains('yourdomain.com') ||
        lower.contains('your-production-domain.com') ||
        lower.contains('your-api-gateway') ||
        lower.contains('your-api.example.com') ||
        lower.contains('api.example.com');
  }
}
