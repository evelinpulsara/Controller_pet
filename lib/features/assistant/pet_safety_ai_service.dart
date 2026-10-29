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
