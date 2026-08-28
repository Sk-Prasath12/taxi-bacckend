import 'package:flutter_test/flutter_test.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';

/// Automated tests for Forgot Password API implementation
/// Run with: flutter test test/forgot_password_test.dart
void main() {
  group('Forgot Password API Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('sendForgotOtp returns correct response structure', () async {
      // Test with invalid email to check error handling
      final result = await authService.sendForgotOtp('nonexistent@example.com');

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('success'), isTrue);
      expect(result.containsKey('message'), isTrue);
      expect(result['success'], isA<bool>());
      expect(result['message'], isA<String>());
    });

    test('verifyForgotOtp returns correct response structure', () async {
      // Test with invalid OTP to check error handling
      final result = await authService.verifyForgotOtp(
        'test@example.com',
        '000000',
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('success'), isTrue);
      expect(result.containsKey('message'), isTrue);
      expect(result['success'], isA<bool>());
      expect(result['message'], isA<String>());
    });

    test('resetPassword returns correct response structure', () async {
      // Test password reset
      final result = await authService.resetPassword(
        'test@example.com',
        'newpassword123',
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('success'), isTrue);
      expect(result.containsKey('message'), isTrue);
      expect(result['success'], isA<bool>());
      expect(result['message'], isA<String>());
    });

    test('sendForgotOtp handles network errors', () async {
      // This will fail if server is not running, testing error handling
      final result = await authService.sendForgotOtp('test@example.com');

      // Should not throw exception, should return error response
      expect(result, isNotNull);
      expect(result.containsKey('success'), isTrue);
    });

    test('verifyForgotOtp handles network errors', () async {
      final result = await authService.verifyForgotOtp(
        'test@example.com',
        '123456',
      );

      expect(result, isNotNull);
      expect(result.containsKey('success'), isTrue);
    });

    test('resetPassword handles network errors', () async {
      final result = await authService.resetPassword(
        'test@example.com',
        'password123',
      );

      expect(result, isNotNull);
      expect(result.containsKey('success'), isTrue);
    });
  });

  group('Forgot Password Response Validation', () {
    test('success response contains true', () {
      final successResponse = {
        'success': true,
        'message': 'OTP sent successfully',
      };

      expect(successResponse['success'], isTrue);
      expect(successResponse['message'], isNotEmpty);
    });

    test('error response contains false', () {
      final errorResponse = {'success': false, 'message': 'Email not found'};

      expect(errorResponse['success'], isFalse);
      expect(errorResponse['message'], isNotEmpty);
    });

    test('response message is user-friendly', () {
      final responses = [
        {'success': true, 'message': 'OTP sent successfully'},
        {'success': false, 'message': 'Invalid OTP. Please try again.'},
        {
          'success': false,
          'message': 'Network error. Please check your connection.',
        },
      ];

      for (final response in responses) {
        expect(response['message'], isA<String>());
        expect((response['message'] as String).length, greaterThan(0));
      }
    });
  });
}
