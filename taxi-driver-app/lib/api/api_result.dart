class ApiResult {
  final int statusCode;
  final bool success;
  final String? message;
  final dynamic data;
  final Map<String, dynamic>? error;

  const ApiResult({
    required this.statusCode,
    required this.success,
    this.message,
    this.data,
    this.error,
  });

  factory ApiResult.fromResponse(int statusCode, dynamic body) {
    final map = body is Map<String, dynamic>
        ? body
        : (body is Map ? Map<String, dynamic>.from(body.map((k, v) => MapEntry(k.toString(), v))) : null);
    if (map != null) {
      final explicitSuccess = map['success'];
      final ok = explicitSuccess is bool
          ? explicitSuccess
          : statusCode >= 200 && statusCode < 300;
      Map<String, dynamic>? err;
      if (map['error'] is Map) {
        err = Map<String, dynamic>.from(
          (map['error'] as Map).map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return ApiResult(
        statusCode: statusCode,
        success: ok,
        message: map['message']?.toString(),
        data: map,
        error: err,
      );
    }

    return ApiResult(
      statusCode: statusCode,
      success: statusCode >= 200 && statusCode < 300,
      data: body,
    );
  }
}
