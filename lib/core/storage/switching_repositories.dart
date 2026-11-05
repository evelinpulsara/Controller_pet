import '../../features/activity/domain/daily_activity.dart';
import '../../features/alerts/domain/pet_alert.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/geofencing/domain/safe_zone.dart';
import '../../features/health/domain/health_record.dart';
import '../../features/pets/domain/pet.dart';
import '../../features/tracking/domain/location_data.dart';
import '../../features/walks/domain/walk.dart';

/// Decide dónde se guardan los datos del usuario que inició sesión:
/// cuenta demo -> en el dispositivo; cuentas reales -> en Supabase.
class StorageMode {
  bool remote = false;
}

/// Cada repositorio usa el local o el de Supabase según [StorageMode].
class SwitchingPetRepository implements PetRepository {
  SwitchingPetRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final PetRepository local;
  final PetRepository? remote;
  PetRepository get _r => mode.remote && remote != null ? remote! : local;
  @override
  Future<List<Pet>> getPets() => _r.getPets();
  @override
  Future<void> addPet(Pet pet) => _r.addPet(pet);
  @override
  Future<void> updatePet(Pet pet) => _r.updatePet(pet);
  @override
  Future<void> deletePet(String id) => _r.deletePet(id);
}

class SwitchingTrackerRepository implements TrackerRepository {
  SwitchingTrackerRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final TrackerRepository local;
  final TrackerRepository? remote;
  TrackerRepository get _r => mode.remote && remote != null ? remote! : local;
  /// El repositorio que se está usando ahora (para funciones extra como la clave del collar).
  TrackerRepository get active => _r;
  @override
  Future<TrackerDevice> getTracker(String trackerId) => _r.getTracker(trackerId);
  @override
  Future<void> saveTracker(TrackerDevice tracker) => _r.saveTracker(tracker);
}

class SwitchingSafeZoneRepository implements SafeZoneRepository {
  SwitchingSafeZoneRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final SafeZoneRepository local;
  final SafeZoneRepository? remote;
  SafeZoneRepository get _r => mode.remote && remote != null ? remote! : local;
  @override
  Future<List<SafeZone>> getZones(String petId) => _r.getZones(petId);
  @override
  Future<void> saveZone(SafeZone zone) => _r.saveZone(zone);
  @override
  Future<void> deleteZone(String id) => _r.deleteZone(id);
}

class SwitchingAlertRepository implements AlertRepository {
  SwitchingAlertRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final AlertRepository local;
  final AlertRepository? remote;
  AlertRepository get _r => mode.remote && remote != null ? remote! : local;
  @override
  Future<List<PetAlert>> getAlerts(String petId) => _r.getAlerts(petId);
  @override
  Future<void> addAlert(PetAlert alert) => _r.addAlert(alert);
  @override
  Future<void> clear(String petId) => _r.clear(petId);
}

class SwitchingLocationRepository implements LocationRepository {
  SwitchingLocationRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final LocationRepository local;
  final LocationRepository? remote;
  LocationRepository get _r => mode.remote && remote != null ? remote! : local;
