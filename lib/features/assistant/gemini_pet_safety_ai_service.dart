import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'pet_safety_ai_service.dart';

/// Asistente de emergencias conectado a la API de Google Gemini.
///
/// La clave NO va escrita en el código: se lee del archivo secrets.json
/// (que no se sube a GitHub) al correr la app con
///   flutter run -d chrome --dart-define-from-file=secrets.json
/// Si Gemini falla (sin internet, clave inválida, modelo saturado...),
/// se usa [fallback] para que la app siga funcionando.
class GeminiPetSafetyAiService implements PetSafetyAiService {
  GeminiPetSafetyAiService({
    required this.apiKey,
    required this.fallback,
    this.models = defaultModels,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Se prueban en orden: si uno está saturado o no existe, se usa el siguiente.
  static const defaultModels = [
    'gemini-3-flash-preview', // mejor calidad (~3 s)
    'gemini-3.1-flash-lite', // más rápido (~1 s)
    'gemini-3.8-flash', // el más nuevo, pero a veces saturado
  ];

  final String apiKey;
  final List<String> models;
  final PetSafetyAiService fallback;
  final http.Client _client;

  @override
  Future<LostPetMessages> composeLostPetAlert(LostPetReport r) async {
    final prompt = _buildPrompt(r);
    for (final model in models) {
      try {
        final json = await _ask(model, prompt);
        final owner = (json['owner_alert'] as String?)?.trim() ?? '';
        final contact = (json['contact_message'] as String?)?.trim() ?? '';
        if (owner.isEmpty || contact.isEmpty) throw Exception('faltan textos en la respuesta');
        return LostPetMessages(
            ownerAlert: owner, contactMessage: withLocation(contact, r), fromAi: true);
      } catch (e) {
        debugPrint('[Asistente IA] $model no respondió: $e');
      }
    }
    debugPrint('[Asistente IA] Se usará el respaldo local.');
    return fallback.composeLostPetAlert(r);
  }

  @override
  Future<PosterText> composePoster(LostPetReport r) async {
    final language = r.locale == 'es' ? 'español (Latinoamérica)' : 'English';
    final prompt = '''
Escribe el texto de un cartel de "Se busca" para una mascota perdida, en $language.
Responde SOLO con JSON: {"headline": "...", "description": "..."}
- "headline": frase corta y emotiva (máximo 7 palabras) que incluya el nombre.
- "description": 2 o 3 frases para que la gente la reconozca y llame. Incluye especie, raza,
  edad, dónde y a qué hora se perdió. No inventes color, tamaño, collar ni recompensa.
Datos: ${r.petName}, ${r.species}, raza ${r.breed}, ${r.age} años. Se perdió a las ${r.hhmm}
cerca de "${r.zoneName}".
''';
    for (final model in models) {
      try {
        final j = await _ask(model, prompt);
        final h = (j['headline'] as String?)?.trim() ?? '', d = (j['description'] as String?)?.trim() ?? '';
        if (h.isEmpty || d.isEmpty) throw Exception('faltan textos');
        return PosterText(headline: h, description: d, fromAi: true);
      } catch (e) {
        debugPrint('[Asistente IA] cartel con $model falló: $e');
      }
    }
    return fallback.composePoster(r);
  }

  /// Resumen del día por SSE (Server-Sent Events): Gemini responde con un flujo
  /// `text/event-stream`; cada línea `data: {...}` trae un pedacito del texto.
  /// La app lo muestra mientras llega, sin esperar la respuesta completa.
