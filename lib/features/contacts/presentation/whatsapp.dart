import 'package:url_launcher/url_launcher.dart';

Future<bool> openWhatsApp(String number, String message) {
  final uri = Uri.https('wa.me', '/$number', {'text': message});
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
