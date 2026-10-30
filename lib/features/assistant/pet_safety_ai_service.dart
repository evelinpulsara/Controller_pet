/// Datos de la mascota perdida que recibe la IA para escribir los avisos.
class LostPetReport {
  final String petName, species, breed, ownerName, zoneName;
  final int age, batteryLevel;
  final double distanceOutsideMeters;
  final double latitude, longitude;
  final DateTime time;
  final String locale; // 'es' | 'en'
  const LostPetReport({
    required this.petName,
    required this.species,
    required this.breed,
    required this.age,
    required this.ownerName,
    required this.zoneName,
    required this.distanceOutsideMeters,
    required this.batteryLevel,
    required this.latitude,
    required this.longitude,
    required this.time,
    this.locale = 'es',
  });

  String get mapsLink => 'https://maps.google.com/?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  String get hhmm => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

/// Los dos textos que escribe la IA cuando la mascota sale de la zona segura.
class LostPetMessages {
  /// Aviso para el dueño, dentro de la app.
  final String ownerAlert;
  /// Mensaje de WhatsApp para los contactos de emergencia (incluye el enlace de ubicación).
  final String contactMessage;
  final bool fromAi;
  const LostPetMessages({required this.ownerAlert, required this.contactMessage, this.fromAi = false});
}

/// Texto del cartel de "Se busca".
class PosterText {
  final String headline, description;
  final bool fromAi;
  const PosterText({required this.headline, required this.description, this.fromAi = false});
}

/// Datos del día que la IA resume.
class DaySummaryInput {
  final String petName, species, locale;
  final double distanceMeters, goalMeters;
  final int activeMinutes, walks, walkMinutes, alertsToday, minutesOutside;
  final List<String> placesVisited, unusual;
  const DaySummaryInput({
    required this.petName,
    required this.species,
    required this.distanceMeters,
    required this.goalMeters,
    required this.activeMinutes,
    required this.walks,
    required this.walkMinutes,
    required this.alertsToday,
    required this.minutesOutside,
    this.placesVisited = const [],
    this.unusual = const [],
    this.locale = 'es',
  });
}

/// Asistente de IA de la app.
abstract class PetSafetyAiService {
  /// Avisos cuando la mascota sale de la zona (para el dueño y para los contactos).
  Future<LostPetMessages> composeLostPetAlert(LostPetReport report);
  /// Texto del cartel de "Se busca".
  Future<PosterText> composePoster(LostPetReport report);
  /// Resumen corto de cómo fue el día de la mascota.
  Future<String> summarizeDay(DaySummaryInput day);
  /// Igual que [summarizeDay] pero va entregando el texto a medida que se escribe
  /// (cada evento trae el texto acumulado hasta ese momento).
  Stream<String> summarizeDayStream(DaySummaryInput day);
}

/// Versión sin IA: plantillas fijas. Se usa si no hay clave de Gemini o si Gemini falla.
class MockPetSafetyAiService implements PetSafetyAiService {
  @override
  Future<LostPetMessages> composeLostPetAlert(LostPetReport r) async {
    final es = r.locale == 'es';
    final dist = r.distanceOutsideMeters.round();
    final owner = es
        ? '${r.petName} salió de la zona segura "${r.zoneName}" y está a unos $dist m fuera de ella. '
            'Revisa su ubicación en el mapa y avisa a tus contactos para que te ayuden a buscarlo.'
        : '${r.petName} left the safe zone "${r.zoneName}" and is about $dist m outside it. '
            'Check the map and alert your contacts so they can help you look.';
    final body = es
        ? '🚨 ¡Alerta! ${r.petName} (${r.species}, ${r.breed}) se salió de casa a las ${r.hhmm}. '
            'Si lo ves por la zona, por favor avísame por aquí. ¡Gracias por ayudarme a encontrarlo! 🐾'
        : '🚨 Alert! ${r.petName} (${r.species}, ${r.breed}) got out of the house at ${r.hhmm}. '
            'If you see them around, please let me know here. Thanks for helping me find them! 🐾';
    return LostPetMessages(ownerAlert: owner, contactMessage: withLocation(body, r));
  }

  @override
  Future<PosterText> composePoster(LostPetReport r) async {
    final es = r.locale == 'es';
    return PosterText(
      headline: es ? '¡Ayúdame a encontrar a ${r.petName}!' : 'Help me find ${r.petName}!',
      description: es
          ? '${r.petName} es un ${r.species.toLowerCase()} ${r.breed} de ${r.age} años. '
              'Se perdió hoy a las ${r.hhmm} cerca de "${r.zoneName}". Es muy querido en casa; '
              'si lo ves, por favor llámame.'
          : '${r.petName} is a ${r.age}-year-old ${r.breed} ${r.species.toLowerCase()}. '
              'Went missing today at ${r.hhmm} near "${r.zoneName}". Much loved at home; '
              'if you see them, please call me.',
    );
  }

  @override
  Stream<String> summarizeDayStream(DaySummaryInput d) async* {
    yield await summarizeDay(d);
  }

  @override
  Future<String> summarizeDay(DaySummaryInput d) async {
    final es = d.locale == 'es';
    final km = d.distanceMeters < 1000
        ? '${d.distanceMeters.round()} m'
        : '${(d.distanceMeters / 1000).toStringAsFixed(1)} km';
    final pct = d.goalMeters <= 0 ? 0 : (d.distanceMeters / d.goalMeters * 100).round();
    final walks = d.walks == 0
        ? (es ? 'No salió de paseo.' : 'No walks today.')
        : (es ? 'Salió a ${d.walks} paseo(s) (${d.walkMinutes} min).' : 'Went on ${d.walks} walk(s) (${d.walkMinutes} min).');
    final out = d.minutesOutside > 0
        ? (es ? ' Estuvo ${d.minutesOutside} min fuera de sus zonas seguras.' : ' Spent ${d.minutesOutside} min outside safe zones.')
        : (es ? ' Estuvo siempre en sus zonas seguras.' : ' Stayed in safe zones all day.');
    return es
        ? '${d.petName} recorrió $km hoy ($pct% de su meta) y estuvo activo ${d.activeMinutes} min. $walks$out'
        : '${d.petName} covered $km today ($pct% of the goal) and was active for ${d.activeMinutes} min. $walks$out';
  }
}

/// Agrega al mensaje el enlace de la última ubicación (lo pone la app, no la IA,
/// para que las coordenadas siempre sean las reales).
String withLocation(String message, LostPetReport r) =>
    '$message\n\n📍 ${r.locale == 'es' ? 'Última ubicación' : 'Last location'}: ${r.mapsLink}';
