import 'package:url_launcher/url_launcher.dart';

/// Abre WhatsApp con el mensaje ya escrito para [number] (solo dígitos, con código de país).
/// El usuario solo tiene que presionar "Enviar".
Future<bool> openWhatsApp(String number, String message) {
  final uri = Uri.https('wa.me', '/$number', {'text': message});
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
