import 'package:url_launcher/url_launcher.dart';

/// Dial a phone number using the platform tel: handler.
Future<bool> dialPhoneNumber(String rawPhone) async {
  final digits = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return false;
  final uri = Uri(scheme: 'tel', path: digits);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  return false;
}

/// Open SMS composer for a phone number.
Future<bool> smsPhoneNumber(String rawPhone, {String body = ''}) async {
  final digits = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return false;
  final uri = Uri(
    scheme: 'sms',
    path: digits,
    queryParameters: body.isNotEmpty ? {'body': body} : null,
  );
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  return false;
}
