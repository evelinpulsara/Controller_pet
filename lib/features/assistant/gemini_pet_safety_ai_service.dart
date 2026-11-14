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
  @override
  Stream<String> summarizeDayStream(DaySummaryInput d) async* {
    final language = d.locale == 'es' ? 'español (Latinoamérica)' : 'English';
    final prompt = '''
Eres el asistente de PetTracker. Escribe en $language un resumen cálido y breve (2 o 3 frases,
texto plano, sin markdown ni comillas) de cómo fue el día de la mascota, como si se lo contaras a su dueño.
Usa solo estos datos, no inventes lugares ni actividades. Si hubo algo inusual, menciónalo con calma.
- Mascota: ${d.petName} (${d.species}).
- Distancia: ${(d.distanceMeters / 1000).toStringAsFixed(2)} km de una meta de ${(d.goalMeters / 1000).toStringAsFixed(1)} km.
- Minutos activo: ${d.activeMinutes}.
- Paseos: ${d.walks} (total ${d.walkMinutes} min).
- Minutos fuera de sus zonas seguras: ${d.minutesOutside}.
- Lugares (zonas) donde estuvo: ${d.placesVisited.isEmpty ? 'ninguno registrado' : d.placesVisited.join(', ')}.
- Alertas hoy: ${d.alertsToday}.
- Cosas inusuales: ${d.unusual.isEmpty ? 'ninguna' : d.unusual.join('; ')}.
''';
    for (final model in models) {
      var text = '';
      try {
        final req = http.Request(
          'POST',
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse'),
        )
          ..headers.addAll({'Content-Type': 'application/json', 'x-goog-api-key': apiKey, 'Accept': 'text/event-stream'})
          ..body = jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'temperature': 0.6, 'maxOutputTokens': 2048},
          });
        final res = await _client.send(req).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) throw Exception('respondió ${res.statusCode}');
        // Cada evento SSE llega como una línea "data: {json}".
        await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (!line.startsWith('data:')) continue;
          final json = jsonDecode(line.substring(5).trim());
          if (json is! Map<String, dynamic>) continue; // validación en tiempo de ejecución
          final parts = (json['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?;
          for (final p in parts ?? const []) {
            if (p is Map && p['thought'] != true && p['text'] is String) {
              text += p['text'] as String;
              yield text.trimLeft();
            }
          }
        }
        if (text.trim().isNotEmpty) return;
        throw Exception('respuesta vacía');
      } catch (e) {
        debugPrint('[Asistente IA] resumen (SSE) con $model falló: $e');
        if (text.trim().isNotEmpty) return; // ya se mostró algo útil
      }
    }
    yield await fallback.summarizeDay(d);
  }

  @override
  Future<String> summarizeDay(DaySummaryInput d) async {
    final language = d.locale == 'es' ? 'español (Latinoamérica)' : 'English';
    final prompt = '''
Eres el asistente de PetTracker. Escribe en $language un resumen cálido y breve (2 o 3 frases,
sin markdown) de cómo fue el día de la mascota, como si se lo contaras a su dueño.
Usa solo estos datos, no inventes lugares ni actividades. Si hubo algo inusual, menciónalo con calma.
Responde SOLO con JSON: {"summary": "..."}
Datos de hoy:
- Mascota: ${d.petName} (${d.species}).
- Distancia: ${(d.distanceMeters / 1000).toStringAsFixed(2)} km de una meta de ${(d.goalMeters / 1000).toStringAsFixed(1)} km.
- Minutos activo: ${d.activeMinutes}.
- Paseos: ${d.walks} (total ${d.walkMinutes} min).
- Minutos fuera de sus zonas seguras: ${d.minutesOutside}.
- Lugares (zonas) donde estuvo: ${d.placesVisited.isEmpty ? 'ninguno registrado' : d.placesVisited.join(', ')}.
- Alertas hoy: ${d.alertsToday}.
- Cosas inusuales: ${d.unusual.isEmpty ? 'ninguna' : d.unusual.join('; ')}.
''';
    for (final model in models) {
      try {
        final j = await _ask(model, prompt);
        final s = (j['summary'] as String?)?.trim() ?? '';
        if (s.isEmpty) throw Exception('resumen vacío');
        return s;
      } catch (e) {
        debugPrint('[Asistente IA] resumen con $model falló: $e');
      }
    }
    return fallback.summarizeDay(d);
  }

  Future<Map<String, dynamic>> _ask(String model, String prompt) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            // Límite alto: estos modelos "piensan" antes de responder y eso
            // también cuenta; con poco espacio la respuesta sale vacía o cortada.
            'generationConfig': {
              'temperature': 0.6,
              'maxOutputTokens': 2048,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('respondió ${res.statusCode}: ${utf8.decode(res.bodyBytes)}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final parts = (data['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?;
    final text = parts
            ?.where((p) => p['thought'] != true)
            .map((p) => p['text'] ?? '')
            .join()
            .trim() ??
        '';
    if (text.isEmpty) throw Exception('respuesta vacía');
    return jsonDecode(text) as Map<String, dynamic>;
  }

  String _buildPrompt(LostPetReport r) {
    final language = r.locale == 'es' ? 'español (como se habla en Latinoamérica)' : 'English';
    return '''
Eres el asistente de emergencias de PetTracker, una app que rastrea mascotas con un collar GPS.
La mascota acaba de salir de su zona segura. Escribe dos textos en $language:

1. "owner_alert": aviso corto para el dueño dentro de la app (máximo 2 frases). Dile qué pasó
   con datos concretos y que ya preparaste un mensaje para sus contactos de emergencia.
   Si la batería del collar está baja (menos de 20%), adviértelo porque podría perder el rastro.
2. "contact_message": mensaje de WhatsApp que el dueño enviará a sus vecinos, familiares y amigos,
   escrito en primera persona como si lo escribiera el dueño. Debe empezar con "🚨", decir que la
   mascota se salió, describirla (nombre, especie, raza, edad) para que la reconozcan, la hora,
   y pedir que avisen si la ven y que ayuden a buscarla. Tono cálido y urgente, máximo 4 frases,
   puede tener 1 o 2 emojis. NO incluyas enlaces ni coordenadas (la app agrega la ubicación después).

No inventes datos que no estén aquí (ni color, ni teléfono, ni dirección).
Responde SOLO con un JSON así: {"owner_alert": "...", "contact_message": "..."}

Datos:
- Mascota: ${r.petName}, ${r.species}, raza ${r.breed}, ${r.age} años.
- Dueño: ${r.ownerName}.
- Zona segura: "${r.zoneName}". Está a unos ${r.distanceOutsideMeters.round()} m fuera de ella.
- Hora en que salió: ${r.hhmm}.
- Batería del collar GPS: ${r.batteryLevel}%.
''';
  }
}
