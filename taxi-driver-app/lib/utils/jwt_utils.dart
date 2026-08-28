import 'dart:convert';

class JwtClaims {
  final String? userId;
  final String? role;
  final String? type;
  final DateTime? expiresAt;

  const JwtClaims({this.userId, this.role, this.type, this.expiresAt});

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.subtract(const Duration(seconds: 30)));
  }
}

JwtClaims? parseJwtClaims(String? token) {
  if (token == null || token.isEmpty) return null;
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final jsonMap = jsonDecode(payload);
    if (jsonMap is! Map<String, dynamic>) return null;

    final sub = jsonMap['sub']?.toString();
    final driverId = jsonMap['driverId']?.toString();
    final exp = jsonMap['exp'];
    DateTime? expiresAt;
    if (exp is num) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    }

    return JwtClaims(
      userId: (sub != null && sub.isNotEmpty)
          ? sub
          : (driverId != null && driverId.isNotEmpty ? driverId : null),
      role: jsonMap['role']?.toString(),
      type: jsonMap['type']?.toString(),
      expiresAt: expiresAt,
    );
  } catch (_) {
    return null;
  }
}

/// Reads user id from JWT (`sub` or legacy `driverId`).
String? userIdFromJwt(String? token) => parseJwtClaims(token)?.userId;

bool isJwtExpired(String? token) => parseJwtClaims(token)?.isExpired ?? false;
