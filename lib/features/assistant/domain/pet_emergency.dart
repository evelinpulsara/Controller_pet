import '../pet_safety_ai_service.dart';

class PetEmergency {
  PetEmergency({required this.id, required this.petId, required this.report, this.manual = false})
      : startedAt = DateTime.now();

  final String id, petId;
  final LostPetReport report;
  final bool manual;
  final DateTime startedAt;

  PosterText? poster;
  bool posterLoading = false;

  LostPetMessages? messages;

  DateTime? resolvedAt;

  final Set<String> notifiedContactIds = {};

  final Set<String> thankedContactIds = {};

  bool get isActive => resolvedAt == null;
  bool get isWriting => messages == null;
}
