import '../pet_safety_ai_service.dart';

/// Emergencia activa: la mascota salió de la zona segura.
/// (En el backend corresponde a la tabla `lost_pet_reports`.)
class PetEmergency {
  PetEmergency({required this.id, required this.petId, required this.report, this.manual = false})
      : startedAt = DateTime.now();

  final String id, petId;
  final LostPetReport report;
  /// true = el dueño activó "Mi mascota se perdió" (no fue por salir de la zona).
  final bool manual;
  final DateTime startedAt;

  /// Texto del cartel de "Se busca" (null = aún no se ha generado).
  PosterText? poster;
  bool posterLoading = false;

  /// Textos escritos por la IA (null mientras la IA está escribiendo).
  LostPetMessages? messages;

  /// Cuándo volvió a la zona segura (null = sigue fuera).
  DateTime? resolvedAt;

  /// Contactos a los que ya se les abrió WhatsApp con el aviso.
  final Set<String> notifiedContactIds = {};

  /// Contactos a los que ya se les avisó que la mascota apareció.
  final Set<String> thankedContactIds = {};

  bool get isActive => resolvedAt == null;
  bool get isWriting => messages == null;
}
