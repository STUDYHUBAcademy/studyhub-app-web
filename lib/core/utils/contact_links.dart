import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normalizes a phone number (with or without a leading 0/+) into the
/// digits-only, country-code-prefixed form wa.me needs. Mirrors the
/// toWhatsappNumber() logic from the original tutor registration form.
String toWhatsappNumber(String raw) {
  var n = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (n.startsWith('+')) return n.substring(1);
  if (n.startsWith('00')) return n.substring(2);
  if (n.startsWith('0')) return '20${n.substring(1)}';
  return n;
}

Future<void> launchTel(String phone) => launchUrl(Uri.parse('tel:$phone'));

Future<void> launchWhatsapp(String phone, {String? text}) {
  final number = toWhatsappNumber(phone);
  final uri = text == null || text.isEmpty
      ? Uri.parse('https://wa.me/$number')
      : Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}');
  return launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_self',
  );
}

/// Standard opener for a first/general WhatsApp message to a tutor — a
/// polite greeting by first name, framed around their file with the
/// academy rather than any specific topic.
String greetingMessageFor(String fullName) {
  final firstName = fullName.trim().split(RegExp(r'\s+')).first;
  return 'أهلا بك أستاذ $firstName\n'
      'بخصوص ملفك المسجل لدينا في منصة StudyHUB';
}

Future<void> launchEmail(String email) => launchUrl(Uri.parse('mailto:$email'));

Future<void> launchWebLink(String url) => launchUrl(
  Uri.parse(url),
  mode: LaunchMode.externalApplication,
  webOnlyWindowName: '_self',
);

Future<void> shareLink(String url) =>
    SharePlus.instance.share(ShareParams(uri: Uri.parse(url)));
