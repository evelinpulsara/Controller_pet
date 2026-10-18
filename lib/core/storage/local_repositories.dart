import '../../features/activity/domain/daily_activity.dart';
import '../../features/alerts/domain/pet_alert.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/geofencing/domain/safe_zone.dart';
import '../../features/health/domain/health_record.dart';
import '../../features/pets/domain/pet.dart';
import '../../features/tracking/domain/location_data.dart';
import '../../features/walks/domain/walk.dart';
import 'local_store.dart';

/// Repositorios que guardan en el dispositivo con [LocalStore].
/// Para conectar el backend, crea versiones que hablen con la API e intercámbialas en main.dart.

class LocalPetRepository implements PetRepository {
  LocalPetRepository(this._s);
  final LocalStore _s;
  static const _k = 'pets';
  List<Pet> _all() => _s.readList(_k, Pet.fromJson);
  Future<void> _save(List<Pet> l) => _s.writeList(_k, l, (p) => p.toJson());

  @override
  Future<List<Pet>> getPets() async => _all();
  @override
  Future<void> addPet(Pet pet) => _save([..._all(), pet]);
  @override
  Future<void> updatePet(Pet pet) => _save([for (final p in _all()) p.id == pet.id ? pet : p]);
  @override
  Future<void> deletePet(String id) => _save(_all().where((p) => p.id != id).toList());
}

class LocalTrackerRepository implements TrackerRepository {
  LocalTrackerRepository(this._s);
  final LocalStore _s;
  static const _k = 'trackers';
  List<TrackerDevice> _all() => _s.readList(_k, TrackerDevice.fromJson);

  @override
  Future<TrackerDevice> getTracker(String id) async {
    final found = _all().where((t) => t.id == id);
    if (found.isNotEmpty) return found.first;
    // Collar nuevo: todavía no ha enviado nada (sin batería ni conexión conocidas).
    final t = TrackerDevice(id: id, batteryLevel: 0, isConnected: false, lastUpdate: DateTime.fromMillisecondsSinceEpoch(0));
    await saveTracker(t);
    return t;
  }

  @override
  Future<void> saveTracker(TrackerDevice t) =>
      _s.writeList(_k, [..._all().where((x) => x.id != t.id), t], (x) => x.toJson());
}

class LocalSafeZoneRepository implements SafeZoneRepository {
  LocalSafeZoneRepository(this._s);
  final LocalStore _s;
  static const _k = 'zones';
  List<SafeZone> _all() => _s.readList(_k, SafeZone.fromJson);

  @override
  Future<List<SafeZone>> getZones(String petId) async => _all().where((z) => z.petId == petId).toList();
  @override
  Future<void> saveZone(SafeZone z) {
    final all = _all();
    final i = all.indexWhere((x) => x.id == z.id);
    if (i >= 0) {
      all[i] = z;
    } else {
      all.add(z);
    }
    return _s.writeList(_k, all, (x) => x.toJson());
  }

  @override
  Future<void> deleteZone(String id) => _s.writeList(_k, _all().where((z) => z.id != id).toList(), (x) => x.toJson());
}

class LocalAlertRepository implements AlertRepository {
  LocalAlertRepository(this._s);
  final LocalStore _s;
  String _k(String petId) => 'alerts.$petId';

  @override
  Future<List<PetAlert>> getAlerts(String petId) async => _s.readList(_k(petId), PetAlert.fromJson);
  @override
  Future<void> addAlert(PetAlert a) {
    final l = [a, ..._s.readList(_k(a.petId), PetAlert.fromJson)];
    return _s.writeList(_k(a.petId), l.take(100).toList(), (x) => x.toJson());
  }

  @override
  Future<void> clear(String petId) => _s.remove(_k(petId));
