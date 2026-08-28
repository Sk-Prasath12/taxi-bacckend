/// Normalizes API base URLs (fixes typos like `192.168.0.100.3000`).
class ApiHostNormalizer {
  static String normalize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    s = s.replaceFirst(RegExp(r'^http//', caseSensitive: false), 'http://');
    s = s.replaceFirst(RegExp(r'^https//', caseSensitive: false), 'https://');

    if (!s.contains('://')) {
      final dotPort = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){3})\.(\d{2,5})$');
      final m = dotPort.firstMatch(s);
      if (m != null) {
        s = 'http://${m.group(1)}:${m.group(2)}';
      } else if (s.contains(':')) {
        s = 'http://$s';
      } else {
        s = 'http://$s:3000';
      }
    }

    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return s;

    if (uri.hasPort) {
      return '${uri.scheme}://${uri.host}:${uri.port}';
    }
    if (uri.scheme == 'https') {
      return 'https://${uri.host}';
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') {
      return 'http://${uri.host}:3000';
    }
    return 'http://${uri.host}';
  }
}
