import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'pet_safety_ai_service.dart';

/// IA a través del BACKEND (Render). La app no conoce la clave de Gemini:
/// le pide al backend, y el backend habla con Gemini.
///
///   POST {backend}/api/ai/lost-alert         -> aviso para dueño y contactos
///   POST {backend}/api/ai/poster             -> cartel "Se busca"
///   POST {backend}/api/ai/day-summary/stream -> resumen del día por SSE
///
/// Si el backend no responde (por ejemplo, Render "dormido"), usa [fallback].
class BackendPetAiService implements PetSafetyAiService {
  BackendPetAiService({required this.baseUrl, required this.fallback, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final PetSafetyAiService fallback;
  final http.Client _client;

  Uri _u(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, dynamic> _report(LostPetReport r) => {
        'petName': r.petName,
        'species': r.species,
        'breed': r.breed,
        'age': r.age.clamp(0, 60),
        'ownerName': r.ownerName,
        'zoneName': r.zoneName,
        'distanceOutsideMeters': r.distanceOutsideMeters.clamp(0, 100000),
        'batteryLevel': r.batteryLevel.clamp(0, 100),
        'time': r.hhmm,
        'locale': r.locale == 'en' ? 'en' : 'es',
      };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    // Render (plan gratis) puede tardar en "despertar": se espera un poco más.
    final res = await _client
        .post(_u(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) throw Exception('backend respondió ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    if (j is! Map<String, dynamic>) throw Exception('respuesta inválida');
    return j;
  }

  @override
  Future<LostPetMessages> composeLostPetAlert(LostPetReport r) async {
    try {
      final j = await _post('/api/ai/lost-alert', _report(r));
      final owner = j['ownerAlert'], contact = j['contactMessage'];
      if (owner is! String || contact is! String || owner.isEmpty || contact.isEmpty) throw Exception('faltan textos');
      return LostPetMessages(ownerAlert: owner, contactMessage: withLocation(contact, r), fromAi: j['fromAi'] == true);
    } catch (e) {
      debugPrint('[Backend IA] aviso: $e');
      return fallback.composeLostPetAlert(r);
    }
  }

  @override
  Future<PosterText> composePoster(LostPetReport r) async {
    try {
      final j = await _post('/api/ai/poster', _report(r));
      final h = j['headline'], d = j['description'];
      if (h is! String || d is! String || h.isEmpty || d.isEmpty) throw Exception('faltan textos');
      return PosterText(headline: h, description: d, fromAi: j['fromAi'] == true);
    } catch (e) {
      debugPrint('[Backend IA] cartel: $e');
      return fallback.composePoster(r);
    }
  }

  Map<String, dynamic> _day(DaySummaryInput d) => {
        'petName': d.petName,
        'species': d.species,
        'distanceMeters': d.distanceMeters,
        'goalMeters': d.goalMeters,
        'activeMinutes': d.activeMinutes,
        'walks': d.walks,
        'walkMinutes': d.walkMinutes,
        'alertsToday': d.alertsToday,
        'minutesOutside': d.minutesOutside,
        'placesVisited': d.placesVisited.take(20).toList(),
        'unusual': d.unusual.take(20).toList(),
        'locale': d.locale == 'en' ? 'en' : 'es',
      };

  @override
  Future<String> summarizeDay(DaySummaryInput d) async {
    var last = '';
    await for (final t in summarizeDayStream(d)) {
      last = t;
    }
    return last;
  }

  /// Resumen por SSE desde el backend: cada evento trae {"text": texto acumulado}.
  @override
  Stream<String> summarizeDayStream(DaySummaryInput d) async* {
    var got = false;
    try {
      final req = http.Request('POST', _u('/api/ai/day-summary/stream'))
        ..headers.addAll({'Content-Type': 'application/json', 'Accept': 'text/event-stream'})
        ..body = jsonEncode(_day(d));
      final res = await _client.send(req).timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) throw Exception('backend respondió ${res.statusCode}');
      await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final j = jsonDecode(line.substring(5).trim());
        if (j is Map && j['text'] is String && (j['text'] as String).isNotEmpty) {
          got = true;
          yield j['text'] as String;
        }
      }
    } catch (e) {
      debugPrint('[Backend IA] resumen: $e');
    }
    if (!got) yield await fallback.summarizeDay(d);
  }
}
