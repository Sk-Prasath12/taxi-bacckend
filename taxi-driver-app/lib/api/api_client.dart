import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_constants.dart';
import 'api_result.dart';

class ApiClient {
  final String? authToken;
  static const Duration defaultTimeout = Duration(seconds: 20);

  ApiClient({this.authToken});

  Uri _buildUri(String path) {
    if (path.startsWith('http')) {
      return Uri.parse(path);
    }
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    if (kDebugMode) {
      debugPrint('API Request URI: $uri');
    }
    return uri;
  }

  Map<String, String> _headers({bool jsonContent = true}) {
    final headers = <String, String>{};
    if (jsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<http.Response> get(String path) async {
    final uri = _buildUri(path);
    final headers = _headers();
    if (kDebugMode) {
      debugPrint('GET $uri with headers: $headers');
    }
    return http.get(uri, headers: headers).timeout(defaultTimeout);
  }

  Future<http.Response> post(String path,
      {Map<String, dynamic>? body, bool jsonContent = true}) async {
    final uri = _buildUri(path);
    final headers = _headers(jsonContent: jsonContent);
    if (kDebugMode) {
      debugPrint('POST $uri with headers: $headers body: $body');
    }
    return http
        .post(
      uri,
      headers: headers,
      body: jsonContent ? jsonEncode(body ?? {}) : null,
    )
        .timeout(defaultTimeout);
  }

  Future<http.Response> patch(String path,
      {Map<String, dynamic>? body, bool jsonContent = true}) async {
    final uri = _buildUri(path);
    final headers = _headers(jsonContent: jsonContent);
    if (kDebugMode) {
      debugPrint('PATCH $uri with headers: $headers body: $body');
    }
    return http.patch(
      uri,
      headers: headers,
      body: jsonContent ? jsonEncode(body ?? {}) : null,
    ).timeout(defaultTimeout);
  }

  Future<http.Response> put(String path,
      {Map<String, dynamic>? body, bool jsonContent = true}) async {
    final uri = _buildUri(path);
    final headers = _headers(jsonContent: jsonContent);
    if (kDebugMode) {
      debugPrint('PUT $uri with headers: $headers body: $body');
    }
    return http.put(
      uri,
      headers: headers,
      body: jsonContent ? jsonEncode(body ?? {}) : null,
    );
  }

  /// Flutter web often decodes JSON objects as Map<dynamic,dynamic>.
  static Map<String, dynamic>? asMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  dynamic decode(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      return asMap(decoded) ?? decoded;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> getJson(String path) async {
    final response = await get(path);
    return decode(response);
  }

  Future<dynamic> postJson(String path, {Map<String, dynamic>? body}) async {
    final response = await post(path, body: body);
    return decode(response);
  }

  Future<ApiResult> postResult(String path, {Map<String, dynamic>? body}) async {
    final response = await post(path, body: body);
    return ApiResult.fromResponse(response.statusCode, decode(response));
  }

  Future<ApiResult> getResult(String path) async {
    final response = await get(path);
    return ApiResult.fromResponse(response.statusCode, decode(response));
  }

  Future<ApiResult> patchResult(String path, {Map<String, dynamic>? body}) async {
    final response = await patch(path, body: body);
    return ApiResult.fromResponse(response.statusCode, decode(response));
  }

  Future<dynamic> patchJson(String path, {Map<String, dynamic>? body}) async {
    final response = await patch(path, body: body);
    return decode(response);
  }

  Future<dynamic> putJson(String path, {Map<String, dynamic>? body}) async {
    final response = await put(path, body: body);
    return decode(response);
  }

  Future<http.Response> postMultipart(
    String path, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
    String? mimeType,
    Map<String, String>? query,
  }) async {
    final baseUri = _buildUri(path);
    final uri = query == null || query.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: query);

    final request = http.MultipartRequest('POST', uri);
    final headers = _headers(jsonContent: false);
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ),
    );

    if (kDebugMode) {
      debugPrint('POST multipart $uri file=$filename');
    }

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }
}
