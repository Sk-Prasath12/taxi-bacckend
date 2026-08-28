import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_user/config/env_config.dart';
import 'package:taxi_user/services/auth_service.dart';

void main() {
  test('register uses customer endpoint and succeeds on 200', () async {
    await EnvConfig.load();

    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/customers/register/email'));
      return http.Response(jsonEncode({'success': true}), 200);
    });

    final result = await AuthService.register(
      name: 'Jane Doe',
      email: 'jane@example.com',
      phone: '9999999999',
      client: client,
    );

    expect(result['success'], isTrue);
  });
}
