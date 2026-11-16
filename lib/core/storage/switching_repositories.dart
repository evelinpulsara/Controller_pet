import '../../features/activity/domain/daily_activity.dart';
import '../../features/alerts/domain/pet_alert.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/geofencing/domain/safe_zone.dart';
import '../../features/health/domain/health_record.dart';
import '../../features/pets/domain/pet.dart';
import '../../features/tracking/domain/location_data.dart';
import '../../features/walks/domain/walk.dart';

class StorageMode {
  bool remote = false;
}

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
  @override
  Future<List<LocationHistory>> getHistory(String petId) => _r.getHistory(petId);
  @override
  Future<void> addLocation(LocationHistory entry) => _r.addLocation(entry);
  void clearCache() {
    try {
      (local as dynamic).clearCache();
    } catch (_) {}
  }
}

class SwitchingContactRepository implements ContactRepository {
  SwitchingContactRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final ContactRepository local;
  final ContactRepository? remote;
  ContactRepository get _r => mode.remote && remote != null ? remote! : local;
  @override
  Future<List<EmergencyContact>> getContacts(String petId) => _r.getContacts(petId);
  @override
  Future<void> addContact(EmergencyContact contact) => _r.addContact(contact);
  @override
  Future<void> deleteContact(String id) => _r.deleteContact(id);
}

class SwitchingWalkRepository implements WalkRepository {
  SwitchingWalkRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final WalkRepository local;
  final WalkRepository? remote;
  WalkRepository get _r => mode.remote && remote != null ? remote! : local;
  @override
  Future<List<Walk>> getWalks(String petId) => _r.getWalks(petId);
  @override
  Future<void> saveWalk(Walk walk) => _r.saveWalk(walk);
  @override
  Future<void> deleteWalk(String id) => _r.deleteWalk(id);
}

class SwitchingActivityRepository implements ActivityRepository {
  SwitchingActivityRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final ActivityRepository local;
  final ActivityRepository? remote;
  ActivityRepository get _r => mode.remote && remote != null ? remote! : local;
  @override
  Future<List<DailyActivity>> getActivity(String petId) => _r.getActivity(petId);
  @override
  Future<void> saveDay(DailyActivity day) => _r.saveDay(day);
}

class SwitchingHealthRepository implements HealthRepository {
  SwitchingHealthRepository(this.mode, this.local, this.remote);
  final StorageMode mode;
  final HealthRepository local;
  final HealthRepository? remote;
  HealthRepository get _r => mode.remote && remote != null ? remote! : local;
  @override
  Future<List<HealthRecord>> getRecords(String petId) => _r.getRecords(petId);
  @override
  Future<void> saveRecord(HealthRecord record) => _r.saveRecord(record);
  @override
  Future<void> deleteRecord(String id) => _r.deleteRecord(id);
}
