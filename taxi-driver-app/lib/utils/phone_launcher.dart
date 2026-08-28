import 'package:url_launcher/url_launcher.dart';

String _cleanPhone(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

Future<bool> dialPhoneNumber(String phone) async {
  final cleaned = _cleanPhone(phone);
  if (cleaned.isEmpty) return false;
  final uri = Uri(scheme: 'tel', path: cleaned);
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri);
}

Future<bool> smsPhoneNumber(String phone) async {
  final cleaned = _cleanPhone(phone);
  if (cleaned.isEmpty) return false;
  final uri = Uri(scheme: 'sms', path: cleaned);
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri);
}
