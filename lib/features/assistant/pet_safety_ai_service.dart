class LostPetReport {
  final String petName, species, breed, ownerName, zoneName;
  final int age, batteryLevel;
  final double distanceOutsideMeters;
  final double latitude, longitude;
  final DateTime time;
  final String locale;
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

class LostPetMessages {
  final String ownerAlert;
  final String contactMessage;
  final bool fromAi;
  const LostPetMessages({required this.ownerAlert, required this.contactMessage, this.fromAi = false});
}

class PosterText {
  final String headline, description;
  final bool fromAi;
  const PosterText({required this.headline, required this.description, this.fromAi = false});
}

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

abstract class PetSafetyAiService {
  Future<LostPetMessages> composeLostPetAlert(LostPetReport report);
  Future<PosterText> composePoster(LostPetReport report);
  Future<String> summarizeDay(DaySummaryInput day);
  Stream<String> summarizeDayStream(DaySummaryInput day);
}

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

String withLocation(String message, LostPetReport r) =>
    '$message\n\n📍 ${r.locale == 'es' ? 'Última ubicación' : 'Last location'}: ${r.mapsLink}';
